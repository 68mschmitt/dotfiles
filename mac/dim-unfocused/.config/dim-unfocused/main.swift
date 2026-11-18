// dim-unfocused — dims every window except the focused one.
//
// Draws a translucent black shape over each unfocused app window (and nothing
// else: desktop, menu bar, sketchybar, Dock and notifications stay untouched).
// The focused window and its JankyBorders border are always kept clear.
// No SIP changes and no special permissions: window frames come from
// CGWindowList (bounds/PID/owner only, no titles).
//
// Options:  --alpha <0..1>   darkness of the dimming (default 0.15)
//           --radius <pt>    corner radius of app windows (default 16)
//           --padding <pt>   clear margin around the focused window so its
//                            border stays bright (default 8)
//           --dump           print what would be dimmed and exit
import AppKit

func arg(_ name: String, _ fallback: CGFloat) -> CGFloat {
    let a = CommandLine.arguments
    if let i = a.firstIndex(of: name), i + 1 < a.count, let v = Double(a[i + 1]) { return CGFloat(v) }
    return fallback
}
let dimAlpha = arg("--alpha", 0.15)
let radius = arg("--radius", 16)
let padding = arg("--padding", 8)

// Helper windows that sit at the normal window layer but aren't real app windows.
let ignoredOwners: Set<String> = ["borders", "rift", "sketchybar", "Dock", "Window Server", "dim-unfocused"]

struct Scene: Equatable {
    var dimmed: [NSRect] = []   // AppKit global coords
    var focused: NSRect?
}

final class DimView: NSView {
    var dimmed: [NSRect] = []
    var focused: NSRect?
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        guard !dimmed.isEmpty else { return }
        // Union of all unfocused windows, filled once so overlaps don't get darker.
        let path = CGMutablePath()
        for r in dimmed { path.addRoundedRect(in: r, cornerWidth: radius, cornerHeight: radius) }
        ctx.addPath(path)
        ctx.setFillColor(NSColor.black.withAlphaComponent(dimAlpha).cgColor)
        ctx.fillPath(using: .winding)
        // Punch out the focused window (+ border) where it overlaps others.
        if let f = focused {
            let r = radius + padding
            ctx.setBlendMode(.clear)
            ctx.addPath(CGPath(roundedRect: f, cornerWidth: r, cornerHeight: r, transform: nil))
            ctx.fillPath()
            ctx.setBlendMode(.normal)
        }
    }
}

final class Overlay {
    let screen: NSScreen
    let window: NSWindow
    let view: DimView
    init(screen: NSScreen) {
        self.screen = screen
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        // Just above normal app windows; below menus, popovers, notifications, the Dock and sketchybar.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        view = DimView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = view
        window.setFrame(screen.frame, display: false)
        window.orderFrontRegardless()
    }
    func show(_ scene: Scene) {
        let o = screen.frame.origin
        let local = { (r: NSRect) in r.offsetBy(dx: -o.x, dy: -o.y) }
        let visible = NSRect(origin: .zero, size: screen.frame.size)
        view.dimmed = scene.dimmed.map(local).filter { $0.intersects(visible) }
        view.focused = scene.focused.map { local($0).insetBy(dx: -padding, dy: -padding) }
        view.needsDisplay = true
    }
}

final class Controller {
    var overlays: [Overlay] = []
    var last = Scene()
    var lastChange = Date.distantPast
    var timer: Timer?

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.lastChange = Date(); self?.tick()
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.rebuild()
        }
        rebuild()
    }

    func rebuild() {
        overlays.forEach { $0.window.orderOut(nil) }
        overlays = NSScreen.screens.map(Overlay.init)
        last = Scene(dimmed: [], focused: .zero)   // force a redraw
        tick()
    }

    func scene() -> Scene {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return Scene() }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var s = Scene()
        for w in list {   // front-to-back order
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  let owner = w[kCGWindowOwnerName as String] as? String, !ignoredOwners.contains(owner),
                  let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let cg = CGRect(dictionaryRepresentation: b),
                  cg.width >= 50, cg.height >= 50
            else { continue }
            if let a = w[kCGWindowAlpha as String] as? Double, a == 0 { continue }
            let r = NSRect(x: cg.minX, y: primaryHeight - cg.maxY, width: cg.width, height: cg.height)
            if s.focused == nil, (w[kCGWindowOwnerPID as String] as? pid_t) == pid {
                s.focused = r
            } else {
                s.dimmed.append(r)
            }
        }
        // Nothing focused (e.g. clicked the desktop) -> don't dim anything.
        if s.focused == nil { s.dimmed = [] }
        return s
    }

    func tick() {
        timer?.invalidate()
        let s = scene()
        if s != last {
            last = s
            lastChange = Date()
            overlays.forEach { $0.show(s) }
        }
        // Track fast (60 Hz) while windows are moving/animating, idle at 10 Hz otherwise.
        let interval = Date().timeIntervalSince(lastChange) < 1 ? 1.0 / 60 : 1.0 / 10
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in self?.tick() }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller()
// --dump: print what would be dimmed, then exit (for debugging)
if CommandLine.arguments.contains("--dump") {
    for s in NSScreen.screens { print("screen", s.localizedName, s.frame) }
    let s = controller.scene()
    print("focused", s.focused.map { "\($0)" } ?? "none")
    for r in s.dimmed { print("dimmed", r) }
    exit(0)
}
controller.start()
app.run()
