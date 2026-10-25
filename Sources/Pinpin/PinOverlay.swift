import AppKit
import ScreenCaptureKit

enum PinpinError: LocalizedError {
    case windowNotFound

    var errorDescription: String? {
        switch self {
        case .windowNotFound: return "Pinpin couldn't capture that window."
        }
    }
}

/// A borderless, non-activating panel that never steals focus from the app the user is working in.
private final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Shows a live mirror of the pinned window, laid exactly over the real one.
private final class OverlayView: NSView {
    let mirrorLayer = CALayer()
    var onClick: (() -> Void)?
    /// Areas cut out of the mirror, in view coordinates, where a higher pinned window is shown for real.
    private(set) var holes: [CGRect] = []
    private let holeMask = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        mirrorLayer.contentsGravity = .resizeAspect
        mirrorLayer.isHidden = true
        // No implicit animations: a fading mirror is exactly the flicker we're trying to avoid.
        mirrorLayer.actions = ["contents": NSNull(), "hidden": NSNull(), "bounds": NSNull(), "position": NSNull(), "mask": NSNull()]
        holeMask.fillRule = .evenOdd
        holeMask.actions = ["path": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(mirrorLayer)
    }

    func setHoles(_ newHoles: [CGRect]) {
        guard newHoles != holes else { return }
        holes = newHoles
        updateMask()
    }

    private func updateMask() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if holes.isEmpty {
            mirrorLayer.mask = nil
        } else {
            let path = CGMutablePath()
            path.addRect(bounds)
            for hole in holes {
                // Windows have rounded corners; a matching hole avoids a notch at each corner.
                path.addRoundedRect(in: hole, cornerWidth: 10, cornerHeight: 10)
            }
            holeMask.frame = bounds
            holeMask.path = path
            mirrorLayer.mask = holeMask
        }
        CATransaction.commit()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mirrorLayer.frame = bounds
        CATransaction.commit()
        updateMask()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !holes.contains(where: { $0.contains(point) }) else { return }
        onClick?()
    }
}

/// Keeps one window visually on top by laying a live ScreenCaptureKit mirror of it, in a floating
/// panel, exactly over the real window whenever the real one might be covered.
final class PinOverlay: NSObject, SCStreamOutput, SCStreamDelegate {
    let windowID: CGWindowID
    let pid: pid_t

    private let panel = OverlayPanel()
    private let view = OverlayView()
    private var stream: SCStream?
    private var captureSize: CGSize = .zero
    private var lastBounds: CGRect = .null
    private var isMirrorVisible = false
    /// After an early show, keep the mirror up briefly so a tick that lands before the window server
    /// reorders windows doesn't hide it again.
    private var mirrorHeldUntil = Date.distantPast
    private var isStopped = false
    private let sampleQueue = DispatchQueue(label: "pinpin.capture", qos: .userInteractive)
    private let onFailure: (Error) -> Void

    init(window: WindowInfo, onFailure: @escaping (Error) -> Void) {
        self.windowID = window.id
        self.pid = window.pid
        self.onFailure = onFailure
        super.init()
        panel.contentView = view
        view.onClick = { [weak self] in self?.bringRealWindowForward() }
    }

    func start() {
        Task { @MainActor in
            do {
                try await startCapture()
            } catch {
                if !isStopped { onFailure(error) }
            }
        }
    }

    func stop() {
        isStopped = true
        stream?.stopCapture { _ in }
        stream = nil
        panel.orderOut(nil)
    }

    /// The overlay panel's window number, as it appears in the system window list.
    var panelWindowID: CGWindowID { CGWindowID(panel.windowNumber) }

    /// Whether the overlay panel is on screen (it's taken off while the window is minimized or on another Space).
    var isOnScreen: Bool { panel.isVisible }

    /// The window's last known CoreGraphics bounds.
    var bounds: CGRect { lastBounds }

    /// Follows the real window's position and size.
    func move(to bounds: CGRect) {
        guard !isStopped, bounds != lastBounds else { return }
        lastBounds = bounds
        panel.setFrame(ScreenGeometry.cocoaRect(fromCG: bounds), display: true)
        updateCaptureSizeIfNeeded()
    }

    /// Whether the mirror should be up, given whether the caller wants it; an early show holds it up briefly.
    func resolveMirror(wanted: Bool) -> Bool {
        wanted || Date() < mirrorHeldUntil
    }

    /// Cuts holes in the mirror (CoreGraphics screen rects) where higher pinned windows are shown for real.
    func setHoles(_ rects: [CGRect]) {
        let local = rects.compactMap { rect -> CGRect? in
            let overlap = rect.intersection(lastBounds)
            guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return nil }
            // Into the view's bottom-left-origin space.
            return CGRect(x: rect.minX - lastBounds.minX, y: lastBounds.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        view.setHoles(local)
    }

    /// Brings the panel on screen above Pinpin's other overlays.
    func orderFront() {
        guard !isStopped else { return }
        panel.orderFrontRegardless()
    }

    /// Shows the mirror immediately, ahead of the real window being covered, so it never visibly drops behind.
    func showMirrorNow() {
        guard !isStopped, panel.isVisible else { return }
        mirrorHeldUntil = Date().addingTimeInterval(0.4)
        setMirrorVisible(true)
    }

    /// The window is minimized or on another Space.
    func hide() {
        panel.orderOut(nil)
    }

    func setMirrorVisible(_ visible: Bool) {
        guard visible != isMirrorVisible else { return }
        isMirrorVisible = visible
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.mirrorLayer.isHidden = !visible
        CATransaction.commit()
        // Only intercept clicks while the mirror is covering the real window.
        panel.ignoresMouseEvents = !visible
    }

    private func bringRealWindowForward() {
        // Leave the mirror up until the real window is actually frontmost; the tracking tick hides it then.
        // Hiding it now would briefly reveal whatever is still covering the real window.
        WindowActivator.focus(pid: pid, windowID: windowID)
    }

    // MARK: Capture

    @MainActor
    private func startCapture() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        guard !isStopped, let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
            throw PinpinError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        captureSize = pixelSize(for: scWindow.frame)
        config.width = Int(captureSize.width)
        config.height = Int(captureSize.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.queueDepth = 5
        config.ignoreShadowsSingleWindow = true

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        self.stream = stream
        try await stream.startCapture()
        if isStopped {
            try? await stream.stopCapture()
        }
    }

    private func pixelSize(for cgBounds: CGRect) -> CGSize {
        let scale = ScreenGeometry.backingScale(for: ScreenGeometry.cocoaRect(fromCG: cgBounds))
        return CGSize(width: max(1, (cgBounds.width * scale).rounded()), height: max(1, (cgBounds.height * scale).rounded()))
    }

    private func updateCaptureSizeIfNeeded() {
        guard let stream else { return }
        let size = pixelSize(for: lastBounds)
        guard size != captureSize else { return }
        captureSize = size
        let config = SCStreamConfiguration()
        config.width = Int(size.width)
        config.height = Int(size.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.queueDepth = 5
        config.ignoreShadowsSingleWindow = true
        stream.updateConfiguration(config) { _ in }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self?.view.mirrorLayer.contents = surface
            CATransaction.commit()
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isStopped else { return }
            self.onFailure(error)
        }
    }
}
