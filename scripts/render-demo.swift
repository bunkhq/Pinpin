// Renders assets/demo.gif, a mock animation of pinning a window with Pinpin.
// The scene is drawn, not recorded, so it can be regenerated on any Mac:
//
//   swift scripts/render-demo.swift
//
// Only things Pinpin really shows are drawn: the menu bar icon filling in,
// and the blue "Activated" / red "Deactivated" pill. The key caps and the
// caption strip are annotations for the demo.

import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = root.appendingPathComponent("assets/demo.gif")

let W: CGFloat = 960, desktopH: CGFloat = 540, captionH: CGFloat = 60
let H = desktopH + captionH
let fps = 25.0
let duration = 10.0

// MARK: - Timeline

struct Key { let t: Double; let p: CGPoint }

func smooth(_ x: Double) -> Double { let c = min(max(x, 0), 1); return c * c * (3 - 2 * c) }

func interpolate(_ keys: [Key], _ t: Double) -> CGPoint {
    guard let next = keys.firstIndex(where: { $0.t > t }) else { return keys.last!.p }
    if next == 0 { return keys[0].p }
    let a = keys[next - 1], b = keys[next]
    let f = CGFloat(smooth((t - a.t) / (b.t - a.t)))
    return CGPoint(x: a.p.x + (b.p.x - a.p.x) * f, y: a.p.y + (b.p.y - a.p.y) * f)
}

let browserStart = CGRect(x: 140, y: 70, width: 560, height: 380)
let notesFrame = CGRect(x: 600, y: 150, width: 260, height: 230)
let dragDelta = CGPoint(x: 160, y: 40)

let cursorKeys = [
    Key(t: 0.0, p: CGPoint(x: 720, y: 300)),
    Key(t: 2.2, p: CGPoint(x: 720, y: 300)),
    Key(t: 3.0, p: CGPoint(x: 300, y: 250)),
    Key(t: 3.4, p: CGPoint(x: 300, y: 250)),
    Key(t: 3.8, p: CGPoint(x: 420, y: 88)),
    Key(t: 3.9, p: CGPoint(x: 420, y: 88)),
    Key(t: 5.3, p: CGPoint(x: 420 + dragDelta.x, y: 88 + dragDelta.y)),
    Key(t: 6.0, p: CGPoint(x: 420 + dragDelta.x, y: 88 + dragDelta.y)),
    Key(t: 6.8, p: CGPoint(x: 730, y: 330)),
    Key(t: 8.0, p: CGPoint(x: 730, y: 330)),
    Key(t: 8.5, p: CGPoint(x: 420, y: 300)),
]
let clicks: [Double] = [3.2, 3.9, 6.9, 8.6]

struct Scene {
    var cursor: CGPoint
    var browser: CGRect
    var browserActive: Bool
    var browserOnTop: Bool
    var pinned: Bool
    var click: Double?          // seconds since the last click, while it's fresh
    var keycast: Double?        // opacity
    var toast: (activated: Bool, opacity: Double)?
    var caption: String
}

func fade(_ t: Double, from start: Double, to end: Double) -> Double? {
    guard t >= start, t < end else { return nil }
    return min(1, (t - start) / 0.12, (end - t) / 0.2)
}

func scene(at t: Double) -> Scene {
    let drag = smooth((t - 3.9) / (5.3 - 3.9))
    var browser = browserStart
    browser.origin.x += dragDelta.x * drag
    browser.origin.y += dragDelta.y * drag

    let lastClick = clicks.last(where: { $0 <= t })
    let caption: String
    switch t {
    case ..<1.0: caption = "Focus the window you want to keep on top"
    case ..<2.2: caption = "Press ⌥Space to pin it"
    case ..<5.8: caption = "Keep working in other apps. The pinned window stays on top."
    case ..<8.0: caption = "Press ⌥Space again to unpin it"
    default: caption = "Unpinned windows behave normally again"
    }

    var toast: (Bool, Double)?
    if let o = fade(t, from: 1.1, to: 2.1) { toast = (true, o) }
    if let o = fade(t, from: 7.3, to: 8.3) { toast = (false, o) }

    return Scene(
        cursor: interpolate(cursorKeys, t),
        browser: browser,
        browserActive: (t >= 3.2 && t < 6.9) || t >= 8.6,
        browserOnTop: t >= 8.6,
        pinned: t >= 1.1 && t < 7.3,
        click: lastClick.flatMap { t - $0 < 0.35 ? t - $0 : nil },
        keycast: fade(t, from: 1.0, to: 1.9) ?? fade(t, from: 7.2, to: 8.1),
        toast: toast,
        caption: caption
    )
}

// MARK: - Drawing helpers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func fill(_ rect: CGRect, _ c: NSColor, radius: CGFloat = 0) {
    c.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func text(_ s: String, at p: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular,
          color c: NSColor = .black, centeredIn width: CGFloat? = nil) {
    let str = NSAttributedString(string: s, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: c,
    ])
    var origin = p
    if let width { origin.x += (width - str.size().width) / 2 }
    str.draw(at: origin)
}

func textWidth(_ s: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).size().width
}

func svg(_ name: String) -> NSImage {
    NSImage(contentsOf: root.appendingPathComponent("assets/\(name).svg"))!
}
let pinFilled = svg("pin-filled"), pinOutline = svg("pin-outline"), pinRemove = svg("pin-remove")

func drawTinted(_ image: NSImage, in rect: CGRect, _ c: NSColor) {
    let tinted = NSImage(size: rect.size, flipped: false) { r in
        image.draw(in: r)
        c.set()
        r.fill(using: .sourceAtop)
        return true
    }
    tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

func withShadow(_ blur: CGFloat, _ y: CGFloat, _ alpha: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: -y)
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - Scene pieces

func drawWallpaper() {
    NSGradient(colors: [color(0x2b3a67), color(0x5b4b8a), color(0xc0698f)])!
        .draw(in: CGRect(x: 0, y: 0, width: W, height: desktopH), angle: -35)
}

func drawMenuBar(_ s: Scene) {
    fill(CGRect(x: 0, y: 0, width: W, height: 26), NSColor.white.withAlphaComponent(0.22))
    let ink = NSColor.white
    text("\u{F8FF}", at: CGPoint(x: 16, y: 4), size: 15, color: ink)
    text(s.browserActive ? "Safari" : "Notes", at: CGPoint(x: 42, y: 5), size: 13, weight: .bold, color: ink)
    var x: CGFloat = s.browserActive ? 104 : 100
    for item in ["File", "Edit", "View", "Window"] {
        text(item, at: CGPoint(x: x, y: 5), size: 13, color: ink)
        x += textWidth(item, size: 13, weight: .regular) + 18
    }
    text("Sun 9:41 AM", at: CGPoint(x: W - 98, y: 5), size: 13, color: ink)
    drawTinted(s.pinned ? pinFilled : pinOutline, in: CGRect(x: W - 128, y: 4, width: 18, height: 18), ink)
}

func drawWindowChrome(_ frame: CGRect, active: Bool, background: NSColor) {
    withShadow(active ? 24 : 14, active ? 10 : 5, active ? 0.45 : 0.3) {
        fill(frame, background, radius: 10)
    }
    color(0x000000, 0.18).setStroke()
    NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10).stroke()
    let lights: [UInt32] = active ? [0xff5f57, 0xfebc2e, 0x28c840] : [0xcfcfcf, 0xcfcfcf, 0xcfcfcf]
    for (i, hex) in lights.enumerated() {
        fill(CGRect(x: frame.minX + 14 + CGFloat(i) * 20, y: frame.minY + 12, width: 12, height: 12), color(hex), radius: 6)
    }
}

func drawBrowser(_ f: CGRect, active: Bool) {
    drawWindowChrome(f, active: active, background: color(0xffffff))
    fill(CGRect(x: f.minX, y: f.minY + 36, width: f.width, height: 1), color(0xe2e2e2))
    let bar = CGRect(x: f.midX - 130, y: f.minY + 8, width: 260, height: 22)
    fill(bar, color(0xeeeeef), radius: 6)
    text("pinpin.app/docs", at: CGPoint(x: bar.minX, y: bar.minY + 3), size: 12,
         color: color(0x666666), centeredIn: bar.width)
    let c = f.insetBy(dx: 28, dy: 0)
    fill(CGRect(x: c.minX, y: f.minY + 60, width: 240, height: 20), color(0x2a2a2e), radius: 4)
    for (i, w) in [0.92, 0.86, 0.95, 0.6].enumerated() {
        fill(CGRect(x: c.minX, y: f.minY + 98 + CGFloat(i) * 20, width: c.width * w, height: 9), color(0xdadade), radius: 4)
    }
    fill(CGRect(x: c.minX, y: f.minY + 190, width: c.width, height: 120), color(0xdce8fb), radius: 8)
    for (i, w) in [0.9, 0.7].enumerated() {
        fill(CGRect(x: c.minX, y: f.minY + 328 + CGFloat(i) * 20, width: c.width * w, height: 9), color(0xdadade), radius: 4)
    }
}

func drawNotes(_ f: CGRect, active: Bool) {
    drawWindowChrome(f, active: active, background: color(0xfffbea))
    text("Notes", at: CGPoint(x: f.minX, y: f.minY + 8), size: 13, weight: .semibold,
         color: color(active ? 0x3a3a3a : 0x9a9a9a), centeredIn: f.width)
    let x = f.minX + 20
    text("Call agenda", at: CGPoint(x: x, y: f.minY + 42), size: 18, weight: .bold, color: color(0x2a2a2a))
    let items = [("☑", "Record the demo"), ("☐", "Review the PR"), ("☐", "Update the docs"), ("☐", "Ship 1.1")]
    for (i, item) in items.enumerated() {
        let y = f.minY + 80 + CGFloat(i) * 30
        text(item.0, at: CGPoint(x: x, y: y), size: 16, color: color(i == 0 ? 0xe0a100 : 0x8a8a8a))
        text(item.1, at: CGPoint(x: x + 26, y: y + 1), size: 15, color: color(i == 0 ? 0x9a9a9a : 0x2a2a2a))
    }
}

func drawKeycast(_ opacity: Double) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.setAlpha(opacity)
    var x: CGFloat = 24
    for key in ["⌥", "Space"] {
        let w = max(54, textWidth(key, size: 22, weight: .semibold) + 36)
        let r = CGRect(x: x, y: desktopH - 24 - 54, width: w, height: 54)
        withShadow(10, 3, 0.35) { fill(r, color(0x1c1c1e, 0.85), radius: 10) }
        text(key, at: CGPoint(x: r.minX, y: r.minY + 13), size: 22, weight: .semibold, color: .white, centeredIn: w)
        x += w + 10
    }
    ctx.restoreGState()
}

// Matches ToastView in Sources/Pinpin/Feedback.swift.
func drawToast(activated: Bool, opacity: Double) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.setAlpha(opacity)
    let label = activated ? "Activated" : "Deactivated"
    let w = 12 + 13 + 7 + textWidth(label, size: 12, weight: .semibold) + 12
    let r = CGRect(x: (W - w) / 2, y: desktopH - 60, width: w, height: 28)
    withShadow(6, 2, 0.18) { fill(r, activated ? .systemBlue : .systemRed, radius: 14) }
    drawTinted(activated ? pinFilled : pinRemove, in: CGRect(x: r.minX + 12, y: r.minY + 7.5, width: 13, height: 13), .white)
    text(label, at: CGPoint(x: r.minX + 32, y: r.minY + 6), size: 12, weight: .semibold, color: .white)
    ctx.restoreGState()
}

func drawCursor(_ p: CGPoint, click: Double?) {
    if let click {
        let f = CGFloat(click / 0.35)
        let radius = 8 + 18 * f
        NSColor.white.withAlphaComponent(0.7 * (1 - f)).setStroke()
        let ring = NSBezierPath(ovalIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
        ring.lineWidth = 3
        ring.stroke()
    }
    let scale: CGFloat = (click ?? 1) < 0.12 ? 0.88 : 1
    let pts: [CGPoint] = [(0, 0), (0, 22), (5.5, 17), (9.5, 26), (13, 24.5), (9, 16), (16, 16)]
        .map { CGPoint(x: p.x + $0.0 * scale, y: p.y + $0.1 * scale) }
    let arrow = NSBezierPath()
    arrow.move(to: pts[0])
    pts.dropFirst().forEach { arrow.line(to: $0) }
    arrow.close()
    withShadow(3, 1, 0.4) {
        NSColor.black.setFill()
        arrow.fill()
    }
    NSColor.white.setStroke()
    arrow.lineWidth = 1.5
    arrow.stroke()
}

func drawCaption(_ s: String) {
    fill(CGRect(x: 0, y: desktopH, width: W, height: captionH), color(0x16171c))
    text(s, at: CGPoint(x: 0, y: desktopH + 18), size: 20, weight: .medium, color: color(0xf2f2f5), centeredIn: W)
}

func draw(_ s: Scene) {
    drawWallpaper()
    drawMenuBar(s)
    if s.browserOnTop {
        drawNotes(notesFrame, active: !s.browserActive)
        drawBrowser(s.browser, active: s.browserActive)
    } else {
        drawBrowser(s.browser, active: s.browserActive)
        drawNotes(notesFrame, active: !s.browserActive)
    }
    if let k = s.keycast { drawKeycast(k) }
    if let toast = s.toast { drawToast(activated: toast.activated, opacity: toast.opacity) }
    drawCursor(s.cursor, click: s.click)
    drawCaption(s.caption)
}

// MARK: - Render

func renderFrame(_ t: Double) -> CGImage {
    let cg = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
    cg.translateBy(x: 0, y: H)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    draw(scene(at: t))
    // Cross-fade back to the first frame so the loop is seamless.
    let loopFade = (t - (duration - 0.6)) / 0.6
    if loopFade > 0 {
        cg.beginTransparencyLayer(auxiliaryInfo: nil)
        cg.setAlpha(smooth(loopFade))
        draw(scene(at: 0))
        cg.endTransparencyLayer()
    }
    NSGraphicsContext.current = nil
    return cg.makeImage()!
}

let frameCount = Int(duration * fps)
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frameCount, nil)!
CGImageDestinationSetProperties(destination, [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
] as CFDictionary)
let frameProperties = [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps],
] as CFDictionary
for i in 0..<frameCount {
    CGImageDestinationAddImage(destination, renderFrame(Double(i) / fps), frameProperties)
}
guard CGImageDestinationFinalize(destination) else { fatalError("Couldn't write \(output.path)") }
print("Wrote \(output.path) (\(frameCount) frames)")
