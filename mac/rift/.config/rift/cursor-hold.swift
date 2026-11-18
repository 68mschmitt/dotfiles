// cursor-hold <ms>: keep the mouse cursor where it is for <ms> milliseconds,
// undoing any warp (a jump > 150pt between 5ms samples) while still following
// small, real mouse movement. Afterwards it posts a mouse-moved event at the
// final position so Rift's focus-follows-mouse focuses the window under it.
// Used by move-stay.sh; built on demand into ~/.local/bin/rift-cursor-hold.
import CoreGraphics
import Foundation

func location() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }
func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }

let ms = Double(CommandLine.arguments.dropFirst().first ?? "") ?? 400
var held = location()
let deadline = Date().addingTimeInterval(ms / 1000)
while Date() < deadline {
    usleep(5000)
    let now = location()
    if distance(now, held) > 150 {
        CGWarpMouseCursorPosition(held)
        CGAssociateMouseAndMouseCursorPosition(1)
    } else {
        held = now
    }
}
CGWarpMouseCursorPosition(held)
CGAssociateMouseAndMouseCursorPosition(1)
// Nudge: a real mouse-moved event at the same spot triggers focus-follows-mouse.
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: held,
        mouseButton: .left)?.post(tap: .cghidEventTap)
