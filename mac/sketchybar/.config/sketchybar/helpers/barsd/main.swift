// barsd: SketchyBar event daemon. Replaces the per-event shell scripts on the
// hot paths with one long-running process:
//   - receives every item's events over Mach (items get mach_helper=git.felix.barsd
//     instead of `script`), so hovering/clicking never forks a shell
//   - hover highlight, popup auto-close timer (2s, reset on re-entry)
//   - Rift workspace labels + rift_state (Rift subscriptions call `bar_notify rift`)
//   - clock/date (minute-aligned timer), front app name + per-app "last seen"
//   - Dock badge bubbles (Accessibility, in-process, power-aware interval)
//   - everything else (clicks, rare events) is dispatched to the item's plugin
//     script from ~/.cache/sketchybar/routes.tsv, with the same env vars
//     SketchyBar would pass.
// Commands go back to SketchyBar over its Mach port (no sketchybar CLI fork).
import AppKit
import ApplicationServices
import Foundation

let home = FileManager.default.homeDirectoryForCurrentUser.path
let configDir = "\(home)/.config/sketchybar"
let stateDir = "\(home)/.cache/sketchybar"
let riftCli = "/opt/homebrew/bin/rift-cli"
let popupClose = 2.0

// MARK: - SketchyBar I/O

// Never send from the main thread: SketchyBar's main thread blocks (no timeout)
// while delivering item events to us, so if our receive loop is itself stuck
// sending to SketchyBar both sides only progress on send timeouts, the event
// queues fill up and the bar lags by seconds (worst with several monitors,
// where every mouse move between bars fires a burst of hover/exit events).
// A serial queue keeps the receive loop draining and preserves command order.
let sbQueue = DispatchQueue(label: "barsd.sb", qos: .userInteractive)
func sb(_ args: [String]) {
    guard !args.isEmpty else { return }
    sbQueue.async {
        let cstrs = args.map { strdup($0) }
        defer { cstrs.forEach { free($0) } }
        var ptrs: [UnsafePointer<CChar>?] = cstrs.map { UnsafePointer($0) }
        _ = ptrs.withUnsafeMutableBufferPointer { sb_send($0.baseAddress, Int32(args.count)) }
    }
}

func run(_ path: String, _ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

func readFile(_ path: String) -> String? { try? String(contentsOfFile: path, encoding: .utf8) }
func writeFile(_ path: String, _ s: String) { try? s.write(toFile: path, atomically: true, encoding: .utf8) }

// MARK: - Palette (colors.sh) and icon map (icon_map.sh)

var colors: [String: String] = [:]
func loadColors() {
    for line in (readFile("\(configDir)/colors.sh") ?? "").split(separator: "\n") {
        let l = line.trimmingCharacters(in: .whitespaces)
        guard l.hasPrefix("export ") else { continue }
        let kv = l.dropFirst(7).split(separator: "=", maxSplits: 1).map(String.init)
        guard kv.count == 2 else { continue }
        var v = kv[1].split(separator: " ").first.map(String.init) ?? ""
        if v.hasPrefix("$") { v = colors[String(v.dropFirst())] ?? v }
        colors[kv[0]] = v
    }
}
func c(_ name: String) -> String { colors[name] ?? "0xffffffff" }

var iconExact: [String: String] = [:]
var iconPrefix: [(String, String)] = []
func loadIcons() {
    let quoted = try! NSRegularExpression(pattern: #""([^"]*)"(\*)?"#)
    let result = try! NSRegularExpression(pattern: #"icon_result="([^"]*)""#)
    var pending: [(String, Bool)] = []
    for line in (readFile("\(configDir)/plugins/icon_map.sh") ?? "").split(separator: "\n") {
        let s = String(line)
        let ns = s as NSString
        if s.trimmingCharacters(in: .whitespaces).hasSuffix(")"), s.contains("\"") {
            pending = quoted.matches(in: s, range: NSRange(location: 0, length: ns.length)).map {
                (ns.substring(with: $0.range(at: 1)), $0.range(at: 2).location != NSNotFound)
            }
        } else if let m = result.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)), !pending.isEmpty {
            let icon = ns.substring(with: m.range(at: 1))
            for (name, glob) in pending {
                if glob { iconPrefix.append((name, icon)) } else if iconExact[name] == nil { iconExact[name] = icon }
            }
            pending = []
        }
    }
}
func icon(for app: String) -> String {
    if let i = iconExact[app] { return i }
    for (p, i) in iconPrefix where app.hasPrefix(p) { return i }
    return ":default:"
}

// MARK: - Routes and power profile

var routes: [String: String] = [:]           // item -> plugin script ("" = native only)
var scriptHover: Set<String> = []            // items whose hover also goes to their script
func loadRoutes() {
    routes = [:]; scriptHover = []
    for line in (readFile("\(stateDir)/routes.tsv") ?? "").split(separator: "\n") {
        let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard let item = f.first, !item.isEmpty else { continue }
        routes[item] = f.count > 1 ? f[1] : ""
        if f.count > 2, f[2] == "hover" { scriptHover.insert(item) }
    }
}
var cachedProfile: String?   // reset on "power" / "reload" (providers.sh writes the file first)
func profile() -> String {
    if let p = cachedProfile { return p }
    let p = (readFile("\(stateDir)/power") ?? "ac").trimmingCharacters(in: .whitespacesAndNewlines)
    cachedProfile = p
    return p
}
func anim() -> [String] {
    switch profile() {
    case "ac": return ["--animate", "tanh", "15"]
    case "battery": return ["--animate", "tanh", "8"]
    default: return []
    }
}

// MARK: - Scripts

signal(SIGCHLD, SIG_IGN)   // auto-reap spawned scripts
func spawnScript(_ item: String, _ env: [String: String]) {
    guard let script = routes[item], !script.isEmpty else { return }
    var e = ProcessInfo.processInfo.environment
    e["CONFIG_DIR"] = configDir
    e["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    for (k, v) in env { e[k] = v }
    let envp = e.map { strdup("\($0.key)=\($0.value)") } + [nil]
    let argv = [strdup(script), nil]
    var pid: pid_t = 0
    posix_spawn(&pid, script, nil, nil, argv, envp)
    envp.forEach { free($0) }; argv.forEach { free($0) }
}

// MARK: - Popup auto-close

var popupTimer: DispatchWorkItem?
func popupOpen() -> String {
    (readFile("\(stateDir)/popup_open") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
}
func cancelPopupTimer() { popupTimer?.cancel(); popupTimer = nil }
func armPopup(_ item: String, after delay: Double) {
    cancelPopupTimer()
    let work = DispatchWorkItem {
        let open = popupOpen() == item
        guard open || item == "toast" else { return }
        var cmd = open ? ["--set", item, "popup.drawing=off"] : []
        if item == "toast" { cmd += anim() + ["--set", "toast", "drawing=off"] }   // pill goes too
        sb(cmd)
        if open { try? FileManager.default.removeItem(atPath: "\(stateDir)/popup_open") }
    }
    popupTimer = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
}

// MARK: - Hover

func hover(_ item: String, _ on: Bool) {
    if item.hasPrefix("badge.") && !item.contains(".row.") {
        sb(anim() + ["--set", item, "background.color=\(c(on ? "RED" : "BADGE_RED"))"])
    } else {
        let v = on ? "on" : "off"
        sb(anim() + ["--set", item, "icon.highlight=\(v)", "label.highlight=\(v)"])
    }
}

// MARK: - Clock

let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "h:mm a"; return f }()
let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE MMM d"; return f }()
func updateClock() {
    let now = Date()
    sb(["--set", "clock", "label=\(timeFmt.string(from: now))", "--set", "date", "label=\(dateFmt.string(from: now))"])
}
func scheduleClock() {
    let now = Date().timeIntervalSince1970
    let next = (floor(now / 60) + 1) * 60 + 0.05
    DispatchQueue.main.asyncAfter(deadline: .now() + (next - now)) { updateClock(); scheduleClock() }
}

// MARK: - Front app + last seen

var seen: [String: Int] = [:]
func frontApp(_ name: String) {
    guard !name.isEmpty else { return }
    sb(["--set", "front_app", "label=\(name)"])
    seen[name] = Int(Date().timeIntervalSince1970)
    writeFile("\(stateDir)/seen.tsv", seen.map { "\($0.key)\t\($0.value)" }.joined(separator: "\n") + "\n")
}

// MARK: - Dock badges

func axValue(_ e: AXUIElement, _ attr: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, attr as CFString, &v) == .success ? v : nil
}
var lastBadges = "-"
func updateBadges(force: Bool = false) {
    guard AXIsProcessTrusted(),
          let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
    else { return }
    var found: [(String, String, String)] = []
    let root = AXUIElementCreateApplication(dock.processIdentifier)
    for list in axValue(root, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        for item in axValue(list, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
            guard let label = axValue(item, "AXStatusLabel") as? String, !label.isEmpty,
                  let title = axValue(item, kAXTitleAttribute) as? String else { continue }
            let bundle = (axValue(item, kAXURLAttribute) as? URL).flatMap { Bundle(url: $0)?.bundleIdentifier } ?? ""
            var l = label
            if let n = Int(label), n > 9999 { l = "\(n / 1000)k" }
            found.append((title, l, bundle))
        }
    }
    let sig = found.map { "\($0.0)|\($0.1)" }.joined(separator: ",")
    guard force || sig != lastBadges else { return }
    lastBadges = sig
    var cmd = anim()
    for i in 1...6 {
        if i <= found.count {
            let (app, label, bundle) = found[i - 1]
            writeFile("\(stateDir)/badge.\(i)", "\(app)\t\(label)\t\(bundle)\n")
            cmd += ["--set", "badge.\(i)", "drawing=on", "icon=\(icon(for: app))", "label=\(label)"]
        } else {
            cmd += ["--set", "badge.\(i)", "drawing=off"]
        }
    }
    sb(cmd)
}
var badgeTimer: Timer?
var badgeInterval = 0.0
func scheduleBadges() {
    let interval: Double = ["ac": 3, "battery": 10][profile()] ?? 30
    guard interval != badgeInterval else { return }
    badgeInterval = interval
    badgeTimer?.invalidate()
    badgeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
        updateBadges(); scheduleBadges()
    }
}

// MARK: - Rift workspaces + rift_state

var displayIds: [String: Int] = [:]          // display UUID -> SketchyBar arrangement id
// SketchyBar numbers displays by their position in SLSCopyManagedDisplays
// (display.c: display_arrangement), so ask SkyLight directly: no query, no race.
@_silgen_name("SLSMainConnectionID") func SLSMainConnectionID() -> Int32
@_silgen_name("SLSCopyManagedDisplays") func SLSCopyManagedDisplays(_ cid: Int32) -> CFArray?
func refreshDisplays() {
    guard let arr = SLSCopyManagedDisplays(SLSMainConnectionID()) as? [String] else { return }
    var m: [String: Int] = [:]
    for (i, uuid) in arr.enumerated() { m[uuid.uppercased()] = i + 1 }
    if !m.isEmpty { displayIds = m }
}

let riftQueue = DispatchQueue(label: "rift")
var riftPending = false, riftRunning = false
func scheduleRift() {
    riftPending = true
    guard !riftRunning else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { renderRift() }
}
func renderRift() {
    guard riftPending, !riftRunning else { return }
    riftPending = false; riftRunning = true
    riftQueue.async {
        // both queries in parallel (~20ms instead of ~40ms)
        var wsOut = "", modeOut = ""
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) { wsOut = run(riftCli, ["query", "workspaces"]) }
        DispatchQueue.global().async(group: group) { modeOut = run(riftCli, ["query", "binding-mode"]) }
        group.wait()
        let mode = modeOut.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n "))
        DispatchQueue.main.async {
            if let ws = try? JSONSerialization.jsonObject(with: Data(wsOut.utf8)) as? [[String: Any]] {
                if displayIds.isEmpty { refreshDisplays() }
                applyRift(ws, mode)
            }
            riftRunning = false
            if riftPending { renderRift() }
        }
    }
}
func applyRift(_ ws: [[String: Any]], _ mode: String) {
    var cmd = anim()
    var seenWs = Set<Int>()
    let used = max(displayIds.count, 1) * 3
    for w in ws {
        guard let index = w["index"] as? Int else { continue }
        let n = index + 1
        seenWs.insert(n)
        let focused = w["is_focused"] as? Bool ?? false
        let active = w["is_active"] as? Bool ?? false
        let count = w["window_count"] as? Int ?? 0
        let disp = displayIds[(w["display_uuid"] as? String ?? "").uppercased()] ?? 1
        var apps: [String] = []
        for win in w["windows"] as? [[String: Any]] ?? [] {
            if let a = win["app_name"] as? String, !apps.contains(a) { apps.append(a) }
        }
        var col = count > 0 ? c("WHITE") : c("GREY")
        var bg = "0x00ffffff"
        if focused {
            bg = count > 0 ? c("WS_FOCUSED_BG") : c("WS_FOCUSED_EMPTY_BG")
            if count > 0 { col = c("DARK") }
        } else if active {
            bg = count > 0 ? c("WS_VISIBLE_BG") : c("WS_VISIBLE_EMPTY_BG")
        }
        let draw = (index < used || count > 0) ? "on" : "off"
        let icons = apps.map(icon(for:)).joined(separator: " ")
        cmd += ["--set", "rift.ws.\(n)", "drawing=\(draw)", "display=\(disp)", "background.drawing=on",
                "background.color=\(bg)", "icon.color=\(col)"]
        cmd += icons.isEmpty ? ["label=", "label.drawing=off"]
                             : ["label=\(icons)", "label.drawing=on", "label.color=\(col)"]
    }
    for n in 1...9 where !seenWs.contains(n) { cmd += ["--set", "rift.ws.\(n)", "drawing=off"] }

    // rift_state: layout of the focused (or first visible) workspace, floating, mode
    let f = ws.first { $0["is_focused"] as? Bool == true } ?? ws.first { $0["is_active"] as? Bool == true }
    let layout = f?["layout_mode"] as? String ?? "bsp"
    let floating = (f?["windows"] as? [[String: Any]] ?? []).first { $0["is_focused"] as? Bool == true }?["is_floating"] as? Bool ?? false
    var sicon = ["bsp": "󰕰", "traditional": "󰕴", "scrolling": "󰯌"][layout] ?? (layout.contains("stack") ? "󰯋" : "󰕮")
    var slabel = layout, scol = c("WHITE")
    if floating { sicon = "󰖲"; slabel = "float" }
    if !mode.isEmpty && mode != "default" { slabel = mode; scol = c("ORANGE") }
    cmd += ["--set", "rift_state", "icon=\(sicon)", "icon.color=\(scol)", "label=\(slabel)", "label.color=\(scol)"]
    sb(cmd)
}

// MARK: - Event dispatch

func isPart(_ item: String, of owner: String) -> Bool {
    !owner.isEmpty && (item == owner || item.hasPrefix(owner + "."))
}

let debug = ProcessInfo.processInfo.environment["BARSD_DEBUG"] != nil
func dispatch(_ env: [String: String]) {
    let name = env["NAME"] ?? "", sender = env["SENDER"] ?? ""
    if debug { FileHandle.standardError.write("\(Date().timeIntervalSince1970) \(name) \(sender) open=\(popupOpen())\n".data(using: .utf8)!) }
    if name == "barsd" {   // internal commands from bar_notify
        switch sender {
        case "rift": scheduleRift()
        case "arm": armPopup(env["ITEM"] ?? "", after: Double(env["DELAY"] ?? "") ?? popupClose)
        case "cancel": cancelPopupTimer()
        case "badges": updateBadges(force: true)
        case "power": cachedProfile = nil; scheduleBadges(); scheduleRift()
        case "reload": cachedProfile = nil; loadRoutes(); loadColors(); attachItems(); scheduleRift(); updateBadges(force: true)
        default: break
        }
        return
    }
    switch sender {
    // The open popup's owner and its rows count as "inside": entering one
    // pauses the auto-close timer, leaving one restarts it (the bar's
    // exited.global has already fired once the mouse is in the popup).
    case "mouse.entered":
        let open = popupOpen()
        if isPart(name, of: open) || isPart(name, of: "toast") { cancelPopupTimer() }
        hover(name, true)
        if scriptHover.contains(name) { spawnScript(name, env) }
    case "mouse.exited":
        hover(name, false)
        if scriptHover.contains(name) { spawnScript(name, env) }
        let open = popupOpen()
        if isPart(name, of: "toast") { armPopup("toast", after: popupClose) }
        else if isPart(name, of: open) { armPopup(open, after: popupClose) }
    case "mouse.exited.global":
        if popupOpen() == name { armPopup(name, after: popupClose) }
    case "mouse.clicked":
        cancelPopupTimer(); spawnScript(name, env)
    case "front_app_switched" where name == "front_app":
        frontApp(env["INFO"] ?? "")
    case "display_change" where name == "barsd.events":
        refreshDisplays(); scheduleRift()
    case "system_woke" where name == "barsd.events":
        updateClock(); updateBadges(force: true); scheduleRift()
    case "forced" where name == "barsd.events":
        updateClock(); updateBadges(force: true); scheduleRift()
    default:
        if name != "barsd.events" { spawnScript(name, env) }
    }
}

let handler: bm_handler = { data, len in
    guard let data = data else { return }
    let bytes = UnsafeRawBufferPointer(start: UnsafeRawPointer(data), count: Int(len))
    var parts: [String] = [], cur: [UInt8] = []
    for b in bytes {
        if b == 0 { parts.append(String(decoding: cur, as: UTF8.self)); cur.removeAll(keepingCapacity: true) }
        else { cur.append(b) }
    }
    var env: [String: String] = [:]
    var i = 0
    while i + 1 < parts.count { if !parts[i].isEmpty { env[parts[i]] = parts[i + 1] }; i += 2 }
    dispatch(env)
}

// Point every routed item's events at us (also re-attaches after a restart).
func attachItems() {
    var cmd: [String] = []
    for item in routes.keys.sorted() { cmd += ["--set", item, "mach_helper=\(BARSD_SERVICE)"] }
    sb(cmd)
}

// MARK: - main

guard barsd_server_begin(handler) else {
    FileHandle.standardError.write("barsd: could not register \(BARSD_SERVICE) (already running?)\n".data(using: .utf8)!)
    exit(1)
}
try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)
loadColors(); loadIcons(); loadRoutes()
attachItems()
refreshDisplays()
for line in (readFile("\(stateDir)/seen.tsv") ?? "").split(separator: "\n") {
    let f = line.split(separator: "\t"); if f.count == 2, let t = Int(f[1]) { seen[String(f[0])] = t }
}
if let app = NSWorkspace.shared.frontmostApplication?.localizedName { frontApp(app) }
updateClock(); scheduleClock()
updateBadges(force: true); scheduleBadges()
riftPending = true; renderRift()
writeFile("\(stateDir)/barsd.ready", "\(getpid())\n")
RunLoop.main.run()
