// Prints the Dock badge of every app that has one, as
// "App Name<TAB>label<TAB>bundle id".
// Reads the Dock's AXStatusLabel attributes, so the process that runs it
// (sketchybar) needs Accessibility permission. Built on demand by
// helpers/makefile into helpers/bin/dock_badges.
import AppKit
import ApplicationServices

guard AXIsProcessTrusted() else {
    FileHandle.standardError.write("dock-badges: no Accessibility permission\n".data(using: .utf8)!)
    exit(2)
}
guard let dock = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.apple.dock").first else { exit(1) }

func value(_ e: AXUIElement, _ attr: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, attr as CFString, &v) == .success ? v : nil
}

let root = AXUIElementCreateApplication(dock.processIdentifier)
for list in value(root, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
    for item in value(list, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        guard let label = value(item, "AXStatusLabel") as? String, !label.isEmpty,
              let title = value(item, kAXTitleAttribute) as? String else { continue }
        let url = value(item, kAXURLAttribute) as? URL
        let bundle = url.flatMap { Bundle(url: $0)?.bundleIdentifier } ?? ""
        print("\(title)\t\(label)\t\(bundle)")
    }
}
