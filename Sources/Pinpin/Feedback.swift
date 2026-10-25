import AppKit
import SwiftUI

/// Sound and on-screen confirmation when the user toggles a window, each respecting its own setting.
@MainActor
enum Feedback {
    static func announce(window: WindowInfo, pinned: Bool) {
        let settings = Settings.shared
        if settings.soundsEnabled {
            SoundEffects.play(activated: pinned)
        }
        if settings.notificationsEnabled {
            Toast.shared.show(activated: pinned, near: window.bounds)
        }
    }

    static func announceUnpinAll() {
        let settings = Settings.shared
        if settings.soundsEnabled {
            SoundEffects.play(activated: false)
        }
        if settings.notificationsEnabled {
            Toast.shared.show(activated: false, near: nil)
        }
    }
}

// MARK: - Sounds

/// Two soft sine "blips": rising for activate, falling for deactivate. Synthesized so there are no assets.
enum SoundEffects {
    private static let activate = makeChime(notes: [784, 1175])   // G5 → D6
    private static let deactivate = makeChime(notes: [1175, 784]) // D6 → G5

    static func play(activated: Bool) {
        guard let sound = activated ? activate : deactivate else { return }
        sound.stop()
        sound.play()
    }

    private static func makeChime(notes: [Double]) -> NSSound? {
        let sampleRate = 44_100.0
        let noteDuration = 0.075
        let gap = 0.02
        let amplitude = 0.16

        var samples: [Int16] = []
        for (index, frequency) in notes.enumerated() {
            let count = Int(noteDuration * sampleRate)
            for i in 0..<count {
                let t = Double(i) / sampleRate
                let attack = min(1, t / 0.004)
                let decay = exp(-t * 38)
                // A touch of the octave harmonic keeps it from sounding like a test tone.
                let wave = sin(2 * .pi * frequency * t) + 0.25 * sin(4 * .pi * frequency * t)
                samples.append(Int16(wave / 1.25 * attack * decay * amplitude * Double(Int16.max)))
            }
            if index < notes.count - 1 {
                samples += Array(repeating: 0, count: Int(gap * sampleRate))
            }
        }
        return NSSound(data: wavData(samples: samples, sampleRate: Int(sampleRate)))
    }

    private static func wavData(samples: [Int16], sampleRate: Int) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let byteCount = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
        append(UInt16(1)); append(UInt16(1)) // PCM, mono
        append(UInt32(sampleRate)); append(UInt32(sampleRate * 2))
        append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(byteCount))
        samples.forEach { append($0) }
        return data
    }
}

// MARK: - Toast

/// A small pill near the bottom of the screen that confirms a toggle, then fades away after a second.
@MainActor
final class Toast {
    static let shared = Toast()

    private let panel: NSPanel
    private var hideWork: DispatchWorkItem?

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    /// `near` is the toggled window's CoreGraphics bounds; the toast appears on that window's screen.
    func show(activated: Bool, near bounds: CGRect?) {
        let hosting = NSHostingView(rootView: ToastView(activated: activated))
        let size = hosting.fittingSize
        panel.contentView = hosting

        let screen = bounds.flatMap(screen(containing:)) ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? .zero
        panel.setFrame(
            CGRect(x: visible.midX - size.width / 2, y: visible.minY + 28, width: size.width, height: size.height),
            display: true
        )

        hideWork?.cancel()
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                self.panel.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated {
                    if self.panel.alphaValue == 0 { self.panel.orderOut(nil) }
                }
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func screen(containing cgBounds: CGRect) -> NSScreen? {
        let rect = ScreenGeometry.cocoaRect(fromCG: cgBounds)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }
}

private struct ToastView: View {
    let activated: Bool

    private var tint: Color { activated ? .blue : .red }

    var body: some View {
        HStack(spacing: 7) {
            PinGlyph(image: activated ? PinIcon.filled : PinIcon.remove, size: 13)
            Text(activated ? "Activated" : "Deactivated")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(tint, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        // Room for the shadow inside the borderless panel.
        .padding(10)
    }
}
