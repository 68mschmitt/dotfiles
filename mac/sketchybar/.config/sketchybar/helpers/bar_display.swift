// bar_display: helpers for opening SketchyBar popups on the monitor the user
// clicked. SketchyBar only draws popups on the "active" display (the one with
// the active menu bar), so popup.sh makes the clicked display active first.
//   bar_display where           -> "x y" of the mouse (global, top-left origin)
//   bar_display active          -> UUID of the display with the active menu bar
//   bar_display hold <ms>       -> keep the cursor in place for <ms> (undo warps)
//   bar_display click <x> <y>   -> left-click at x,y, then put the cursor back
import CoreGraphics
import Foundation

@_silgen_name("SLSMainConnectionID") func SLSMainConnectionID() -> Int32
@_silgen_name("SLSCopyActiveMenuBarDisplayIdentifier")
func SLSCopyActiveMenuBarDisplayIdentifier(_ cid: Int32) -> CFString?

func location() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }
func warp(_ p: CGPoint) { CGWarpMouseCursorPosition(p); CGAssociateMouseAndMouseCursorPosition(1) }

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "where":
    let p = location(); print(Int(p.x), Int(p.y))
case "active":
    print(SLSCopyActiveMenuBarDisplayIdentifier(SLSMainConnectionID()) as String? ?? "")
case "hold":
    var held = location()
    let end = Date().addingTimeInterval((Double(args.dropFirst().first ?? "") ?? 500) / 1000)
    while Date() < end {
        usleep(5000)
        let now = location()
        if hypot(now.x - held.x, now.y - held.y) > 150 { warp(held) } else { held = now }
    }
    warp(held)
case "click":
    guard args.count == 3, let x = Double(args[1]), let y = Double(args[2]) else { exit(1) }
    let back = location(), p = CGPoint(x: x, y: y)
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        usleep(15000)
    }
    warp(back)
default:
    FileHandle.standardError.write("usage: bar_display where|active|hold <ms>|click <x> <y>\n".data(using: .utf8)!)
    exit(1)
}
