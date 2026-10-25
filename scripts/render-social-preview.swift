// Renders assets/social-preview.png, the 1280x640 image GitHub shows in link previews.
// Upload it in Settings > General > Social preview after changing it.
//
//   swift scripts/render-social-preview.swift

import AppKit
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let icon = NSImage(contentsOf: root.appendingPathComponent("assets/icon.png"))!
let W = 1280.0, H = 640.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let bg = NSGradient(starting: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.14, alpha: 1), ending: NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.26, alpha: 1))!
bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 315)
icon.draw(in: NSRect(x: 110, y: (H-300)/2, width: 300, height: 300))
func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor, _ y: CGFloat, _ tx: CGFloat = 480) {
  let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
  NSAttributedString(string: s, attributes: a).draw(at: NSPoint(x: tx, y: y))
}
text("Pinpin", 110, .bold, .white, 340)
text("Keep any window on top on macOS.", 40, .medium, NSColor(white: 0.85, alpha: 1), 270)
// key caps
var x = 480.0
func cap(_ s: String) {
  let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 34, weight: .semibold), .foregroundColor: NSColor.white]
  let str = NSAttributedString(string: s, attributes: a)
  let w = str.size().width + 44
  let r = NSRect(x: x, y: 170, width: w, height: 64)
  NSColor(white: 1, alpha: 0.12).setFill(); NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12).fill()
  NSColor(white: 1, alpha: 0.35).setStroke(); let p = NSBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12); p.lineWidth = 2; p.stroke()
  str.draw(at: NSPoint(x: x + 22, y: 180)); x += w + 14
}
cap("⌥"); cap("Space")
text("to pin", 32, .regular, NSColor(white: 0.75, alpha: 1), 183, x + 2); text("Free and open source", 28, .regular, NSColor(white: 0.6, alpha: 1), 110)
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("assets/social-preview.png"))
