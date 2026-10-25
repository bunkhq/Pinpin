import AppKit

/// Owns the pinned windows and their stacking order.
///
/// Every pinned window has an index: its position in `pinOrder`, starting at 1 for the first pin.
/// Higher indexes always sit above lower ones, no matter which window has focus. Unpinning removes
/// a window's index and the ones after it move down by one, so indexes stay 1…n.
@MainActor
final class PinManager: ObservableObject {
    static let shared = PinManager()

    /// The main window list: pinned windows first, in index order (wherever they are), then the
    /// other windows on the current desktop, most recently focused first.
    @Published private(set) var windows: [WindowInfo] = []
    /// Unpinned windows that are minimized or on another desktop.
    @Published private(set) var otherWindows: [WindowInfo] = []
    /// Pinned windows, lowest index first. Pins don't persist, so this starts empty on every launch.
    @Published private(set) var pinOrder: [CGWindowID] = []
    @Published var lastError: String?

    private var overlays: [CGWindowID: PinOverlay] = [:]
    /// Last-seen info for pinned windows, so they stay listed while minimized or on another Space.
    private var knownWindows: [CGWindowID: WindowInfo] = [:]
    private var trackingTimer: Timer?
    private var mouseMonitor: Any?
    private var activationObserver: NSObjectProtocol?

    private init() {}

    var pinnedCount: Int { pinOrder.count }

    func isPinned(_ id: CGWindowID) -> Bool { overlays[id] != nil }

    /// The window's 1-based pin index, or nil if it isn't pinned.
    func pinIndex(of id: CGWindowID) -> Int? {
        pinOrder.firstIndex(of: id).map { $0 + 1 }
    }

    func refreshWindows() {
        let onScreen = WindowList.userWindows()
        let onScreenIDs = Set(onScreen.map(\.id))
        let offScreen = WindowList.offScreenUserWindows().filter { !onScreenIDs.contains($0.id) }
        for window in onScreen + offScreen where isPinned(window.id) {
            knownWindows[window.id] = window
        }
        // Pinned windows that are gone from both lists keep their last-seen info until they're unpinned.
        let pinned = pinOrder.compactMap { knownWindows[$0] }
        windows = pinned + onScreen.filter { !isPinned($0.id) }
        otherWindows = offScreen.filter { !isPinned($0.id) }
    }

    /// User-initiated toggle (hotkey or menu), with sound and on-screen feedback.
    func toggle(_ window: WindowInfo) {
        if isPinned(window.id) {
            unpin(window.id)
            Feedback.announce(window: window, pinned: false)
        } else if pin(window) {
            if !window.isOnScreen {
                // Bring a minimized or other-desktop window here so the user can see it.
                WindowActivator.focus(pid: window.pid, windowID: window.id)
            }
            Feedback.announce(window: window, pinned: true)
        }
    }

    /// Hotkey action: toggles the frontmost window of the frontmost app.
    func toggleFrontmostWindow() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != WindowList.ownPID,
              let window = WindowList.userWindows().first(where: { $0.pid == app.processIdentifier }) else {
            NSSound.beep()
            return
        }
        toggle(window)
    }

    func unpinAll(announce: Bool = true) {
        let count = pinOrder.count
        for id in pinOrder.reversed() {
            unpin(id)
        }
        if announce && count > 0 {
            Feedback.announceUnpinAll()
        }
    }

    private func pin(_ window: WindowInfo) -> Bool {
        guard Permissions.hasScreenRecording else {
            lastError = "Pinpin needs Screen Recording permission to keep windows on top."
            // Let the current click or hotkey finish before showing the dialog.
            DispatchQueue.main.async {
                Permissions.request(.screenRecording)
                if Permissions.hasScreenRecording { self.lastError = nil }
            }
            return false
        }
        lastError = nil
        let id = window.id
        let overlay = PinOverlay(window: window) { [weak self] error in
            guard let self, self.overlays[id] != nil else { return }
            self.unpin(id)
            self.lastError = error.localizedDescription
        }
        overlays[id] = overlay
        knownWindows[id] = window
        pinOrder.append(id) // the newest pin gets the highest index
        overlay.start()
        startTracking()
        tick()
        refreshWindows()
        return true
    }

    private func unpin(_ id: CGWindowID) {
        HoverFocus.shared.windowUnpinned(id)
        overlays.removeValue(forKey: id)?.stop()
        knownWindows.removeValue(forKey: id)
        // Later pins shift down by one; their relative order (and stacking) is unchanged.
        pinOrder.removeAll { $0 == id }
        if overlays.isEmpty {
            stopTracking()
        }
        refreshWindows()
    }

    // MARK: Tracking

    private func startTracking() {
        guard trackingTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { _ in
            MainActor.assumeIsolated { PinManager.shared.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer

        // React the instant focus is about to move elsewhere, before the window server reorders
        // windows, so a pinned window never visibly drops behind another one.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { _ in
            MainActor.assumeIsolated { PinManager.shared.mouseDownElsewhere() }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let pid = app?.processIdentifier
            MainActor.assumeIsolated { PinManager.shared.appActivated(pid: pid) }
        }
    }

    private func stopTracking() {
        HoverFocus.shared.cancel()
        trackingTimer?.invalidate()
        trackingTimer = nil
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        mouseMonitor = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
    }

    private func mouseDownElsewhere() {
        // A click goes to the topmost pinned window under the pointer; every other pinned window
        // may be about to lose focus, so cover it before the window server reorders anything.
        let hit = topPinnedWindowID(at: pointerLocation())
        for (id, overlay) in overlays where id != hit {
            overlay.showMirrorNow()
        }
    }

    /// Puts the mirror over a pinned window right away, ahead of focus moving elsewhere.
    func coverNow(_ id: CGWindowID) {
        overlays[id]?.showMirrorNow()
    }

    private func appActivated(pid: pid_t?) {
        for overlay in overlays.values where overlay.pid != pid {
            overlay.showMirrorNow()
        }
        tick()
    }

    /// Follows each pinned window's position and decides how it's drawn.
    ///
    /// At most one pinned window is shown "for real": the one the user is working in, when nothing
    /// else overlaps it. Every other pinned window is shown as its mirror, and mirrors are stacked
    /// by index. A real window sits under all the mirrors, so mirrors with a lower index get a hole
    /// where it is; mirrors with a higher index stay on top of it.
    private func tick() {
        let stack = WindowList.allOnScreen()
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        var plan: [(overlay: PinOverlay, bounds: CGRect, mirror: Bool)] = []
        for id in pinOrder {
            guard let overlay = overlays[id] else { continue }
            guard let index = stack.firstIndex(where: { $0.id == id }) else {
                if WindowList.exists(id) {
                    overlay.hide() // minimized or on another Space
                } else {
                    unpin(id)
                }
                continue
            }
            let target = stack[index]
            let isActive = target.pid == frontmostPID && !isCovered(target, at: index, in: stack)
            overlay.move(to: target.bounds)
            plan.append((overlay, target.bounds, overlay.resolveMirror(wanted: !isActive)))
        }

        // Order matters to avoid a one-frame glimpse of the wrong window: put mirrors up first,
        // then cut holes for real windows, and only then uncover the real windows.
        for step in plan where step.mirror {
            step.overlay.setMirrorVisible(true)
        }
        for (position, step) in plan.enumerated() {
            let holes = plan[(position + 1)...].filter { !$0.mirror }.map(\.bounds)
            step.overlay.setHoles(holes)
        }
        for step in plan where !step.mirror {
            step.overlay.setMirrorVisible(false)
        }
        restackIfNeeded(plan.map(\.overlay), stack: stack)

        HoverFocus.shared.update(hovered: hoveredPinnedWindow(in: stack), stack: stack)
    }

    /// Whether anything the user may be looking at sits on top of the window. Other apps' windows
    /// always count, as do the app's own other windows, except ones fully inside the window (sheets,
    /// dialogs, popovers), which belong with it.
    private func isCovered(_ target: WindowInfo, at index: Int, in stack: [WindowInfo]) -> Bool {
        stack[..<index].contains { other in
            guard other.isUserWindow, other.pid != WindowList.ownPID else { return false }
            let overlap = other.bounds.intersection(target.bounds)
            guard !overlap.isNull, overlap.width > 1, overlap.height > 1 else { return false }
            return other.pid != target.pid || !target.bounds.insetBy(dx: -2, dy: -2).contains(other.bounds)
        }
    }

    /// Keeps overlay panels stacked by index, highest on top. Re-orders them if one is missing from the
    /// screen or anything shuffled them.
    private func restackIfNeeded(_ ordered: [PinOverlay], stack: [WindowInfo]) {
        let position = Dictionary(stack.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        // The stack is front to back, so going up in index the positions must go down.
        let positions = ordered.map { position[$0.panelWindowID] }
        let inOrder = !positions.contains(nil) && zip(positions, positions.dropFirst()).allSatisfy { $0! > $1! }
        guard !inOrder || ordered.contains(where: { !$0.isOnScreen }) else { return }
        for overlay in ordered {
            overlay.orderFront()
        }
    }

    // MARK: Pointer

    private func pointerLocation() -> CGPoint {
        // Cocoa coordinates (bottom-left origin) to CoreGraphics (top-left), which window bounds use.
        let location = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: location.x, y: primaryHeight - location.y)
    }

    /// The highest-index pinned window on screen containing the point.
    private func topPinnedWindowID(at point: CGPoint) -> CGWindowID? {
        pinOrder.last { id in
            guard let overlay = overlays[id] else { return false }
            return overlay.isOnScreen && overlay.bounds.contains(point)
        }
    }

    /// The pinned window under the pointer for auto-focus: the highest index wins where pinned windows overlap.
    private func hoveredPinnedWindow(in stack: [WindowInfo]) -> WindowInfo? {
        // The Dock and menu bar can sit over a window's edges; hovering them shouldn't move focus.
        guard NSScreen.screens.contains(where: { $0.visibleFrame.contains(NSEvent.mouseLocation) }) else { return nil }
        let point = pointerLocation()
        // Pinpin's own dropdown sits above everything.
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        if stack.contains(where: { $0.pid == WindowList.ownPID && $0.layer >= menuLevel && $0.bounds.contains(point) }) {
            return nil
        }
        guard let id = topPinnedWindowID(at: point) else { return nil }
        return stack.first { $0.id == id }
    }
}
