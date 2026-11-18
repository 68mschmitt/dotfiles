// sketchybar-events: LaunchAgent that feeds SketchyBar with
//   - av_update       MIC=on|off CAM=on|off    (microphone / camera in use)
//   - calendar_update                           (agenda file rewritten)
// Everything is listener driven (CoreAudio, CoreMediaIO, EventKit change
// notifications) plus a slow safety refresh, so it costs ~nothing on battery.
//
// The agenda is written to ~/.cache/sketchybar/agenda.tsv, one event per line:
//   start_epoch<TAB>end_epoch<TAB>title<TAB>join_url
// covering now-2h .. end of tomorrow, without all-day or declined events.
//
// Runs as its own LaunchAgent (see install.sh) so macOS asks for Calendar
// access for this binary rather than for sketchybar.
import AppKit
import CoreAudio
import CoreMediaIO
import EventKit

let sketchybar = "/opt/homebrew/bin/sketchybar"
let cacheDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".cache/sketchybar")
let agendaFile = cacheDir.appendingPathComponent("agenda.tsv")
let statusFile = cacheDir.appendingPathComponent("calendar_status")

func bar(_ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: sketchybar)
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try? p.run()
}

// MARK: - Microphone (CoreAudio)

func audioAddress(_ selector: AudioObjectPropertySelector,
                  _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
    -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                               mElement: kAudioObjectPropertyElementMain)
}

func audioDevices() -> [AudioObjectID] {
    var addr = audioAddress(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    let sys = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(sys, &addr, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(sys, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
}

func hasInput(_ dev: AudioObjectID) -> Bool {
    var addr = audioAddress(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput)
    var size: UInt32 = 0
    return AudioObjectGetPropertyDataSize(dev, &addr, 0, nil, &size) == noErr && size > 0
}

func audioRunning(_ dev: AudioObjectID) -> Bool {
    var addr = audioAddress(kAudioDevicePropertyDeviceIsRunningSomewhere)
    var running: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running) == noErr && running != 0
}

// MARK: - Camera (CoreMediaIO)

func cmioAddress(_ selector: Int) -> CMIOObjectPropertyAddress {
    CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(selector),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
}

func cameraDevices() -> [CMIOObjectID] {
    var addr = cmioAddress(kCMIOHardwarePropertyDevices)
    var size: UInt32 = 0
    let sys = CMIOObjectID(kCMIOObjectSystemObject)
    guard CMIOObjectGetPropertyDataSize(sys, &addr, 0, nil, &size) == 0 else { return [] }
    var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
    var used: UInt32 = 0
    guard CMIOObjectGetPropertyData(sys, &addr, 0, nil, size, &used, &ids) == 0 else { return [] }
    return ids
}

func cameraRunning(_ dev: CMIOObjectID) -> Bool {
    var addr = cmioAddress(kCMIODevicePropertyDeviceIsRunningSomewhere)
    var running: UInt32 = 0
    var used: UInt32 = 0
    return CMIOObjectGetPropertyData(dev, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size),
                                     &used, &running) == 0 && running != 0
}

// MARK: - AV state + listeners

var lastAV = ""
var watchedAudio = Set<AudioObjectID>()
var watchedCameras = Set<CMIOObjectID>()

func updateAV(force: Bool = false) {
    let mic = audioDevices().filter(hasInput).contains(where: audioRunning)
    let cam = cameraDevices().contains(where: cameraRunning)
    let state = "MIC=\(mic ? "on" : "off") CAM=\(cam ? "on" : "off")"
    guard force || state != lastAV else { return }
    lastAV = state
    bar(["--trigger", "av_update"] + state.split(separator: " ").map(String.init))
}

func watchDevices() {
    for dev in audioDevices().filter(hasInput) where !watchedAudio.contains(dev) {
        var addr = audioAddress(kAudioDevicePropertyDeviceIsRunningSomewhere)
        if AudioObjectAddPropertyListenerBlock(dev, &addr, .main, { _, _ in updateAV() }) == noErr {
            watchedAudio.insert(dev)
        }
    }
    for dev in cameraDevices() where !watchedCameras.contains(dev) {
        var addr = cmioAddress(kCMIODevicePropertyDeviceIsRunningSomewhere)
        if CMIOObjectAddPropertyListenerBlock(dev, &addr, .main, { _, _ in updateAV() }) == 0 {
            watchedCameras.insert(dev)
        }
    }
}

func startAV() {
    // Re-scan when devices are plugged in / removed (AirPods, external cams).
    var aAddr = audioAddress(kAudioHardwarePropertyDevices)
    AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &aAddr, .main) { _, _ in
        watchDevices(); updateAV()
    }
    var cAddr = cmioAddress(kCMIOHardwarePropertyDevices)
    CMIOObjectAddPropertyListenerBlock(CMIOObjectID(kCMIOObjectSystemObject), &cAddr, .main) { _, _ in
        watchDevices(); updateAV()
    }
    watchDevices()
    updateAV(force: true)
}

// MARK: - Calendar (EventKit)

let store = EKEventStore()
let joinPattern = try! NSRegularExpression(
    pattern: #"https://([a-z0-9-]+\.)*(teams\.microsoft\.com|teams\.live\.com|zoom\.us|meet\.google\.com|webex\.com)/[^\s<>"')]+"#,
    options: [.caseInsensitive])

func joinURL(_ e: EKEvent) -> String {
    for text in [e.url?.absoluteString, e.location, e.notes].compactMap({ $0 }) {
        let range = NSRange(text.startIndex..., in: text)
        if let m = joinPattern.firstMatch(in: text, range: range), let r = Range(m.range, in: text) {
            return String(text[r])
        }
    }
    return ""
}

func declined(_ e: EKEvent) -> Bool {
    e.attendees?.first(where: { $0.isCurrentUser })?.participantStatus == .declined
}

func clean(_ s: String) -> String {
    s.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
}

func writeStatus(_ s: String) {
    try? s.write(to: statusFile, atomically: true, encoding: .utf8)
}

var lastAgenda: String?

func refreshAgenda() {
    let status = EKEventStore.authorizationStatus(for: .event)
    guard status == .fullAccess else {
        writeStatus(status == .notDetermined ? "pending" : "denied")
        if lastAgenda != "" { lastAgenda = ""; try? "".write(to: agendaFile, atomically: true, encoding: .utf8)
            bar(["--trigger", "calendar_update"]) }
        return
    }
    let now = Date()
    let cal = Calendar.current
    let end = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now))!
    let pred = store.predicateForEvents(withStart: now.addingTimeInterval(-7200), end: end, calendars: nil)
    let events = store.events(matching: pred)
        .filter { !$0.isAllDay && !declined($0) && $0.endDate > now }
        .sorted { $0.startDate < $1.startDate }
    let lines = events.map {
        "\(Int($0.startDate.timeIntervalSince1970))\t\(Int($0.endDate.timeIntervalSince1970))\t\(clean($0.title ?? "Busy"))\t\(joinURL($0))"
    }
    let agenda = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
    writeStatus(store.calendars(for: .event).isEmpty ? "no-calendars" : "ok")
    guard agenda != lastAgenda else { return }
    lastAgenda = agenda
    try? agenda.write(to: agendaFile, atomically: true, encoding: .utf8)
    bar(["--trigger", "calendar_update"])
}

func startCalendar() {
    NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
        refreshAgenda()
    }
    if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
        writeStatus("pending")
        store.requestFullAccessToEvents { _, _ in
            DispatchQueue.main.async { store.reset(); refreshAgenda() }
        }
    }
    refreshAgenda()
}

// MARK: - main

try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
signal(SIGPIPE, SIG_IGN)

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

startAV()
startCalendar()

// Safety net: re-sync every 5 minutes (also rolls the agenda window forward).
Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
    watchDevices(); updateAV(); refreshAgenda()
}
// Re-announce state after wake / when sketchybar restarts and asks for it.
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
    updateAV(force: true); refreshAgenda()
}
DistributedNotificationCenter.default().addObserver(
    forName: Notification.Name("local.sketchybar-events.resync"), object: nil, queue: .main) { _ in
    lastAgenda = nil; updateAV(force: true); refreshAgenda()
}

app.run()
