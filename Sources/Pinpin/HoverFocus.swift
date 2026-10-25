import AppKit

/// Auto-focus: while the pointer rests on a pinned window, that window gets focus, so the first click
/// and keystrokes go straight to it. If the pointer leaves without a click or keystroke, focus goes back
/// to the window that had it before.
@MainActor
final class HoverFocus {
    static let shared = HoverFocus()

    private struct FocusTarget {
        let pid: pid_t
        let windowID: CGWindowID
    }

    private struct Session {
        let target: FocusTarget
        /// The window that had focus before auto-focus took over, restored when the pointer leaves.
        let previous: FocusTarget?
        let startedAt = Date()
        /// Set once the pinned window's app has actually become frontmost.
        var confirmed = false
    }

    /// How long the pointer has to rest on a pinned window before it takes focus.
    private static let dwell: TimeInterval = 0.12
    /// How long the pointer has to be off it before focus is handed back.
    private static let leaveGrace: TimeInterval = 0.1

    private var session: Session?
    private var hoveredID: CGWindowID?
    private var hoveredSince = Date.distantPast
    private var monitors: [Any] = []

    /// Set while Pinpin's dropdown is open, so focus doesn't move and bring windows up over it.
    var isSuspended = false {
        didSet {
            if isSuspended { cancel() }
        }
    }

    private init() {}

    /// Called on every tracking tick with the pinned window under the pointer (topmost first), if any.
    func update(hovered: WindowInfo?, stack: [WindowInfo]) {
        guard Settings.shared.autoFocusEnabled, !isSuspended else {
            cancel()
            // Start the dwell over once it resumes, rather than focusing the instant the menu closes.
            hoveredID = nil
            return
        }
        let now = Date()
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        if var current = session {
            if frontPID == current.target.pid {
                current.confirmed = true
                session = current
            } else if current.confirmed || now.timeIntervalSince(current.startedAt) > 1 {
                // The user switched apps themselves (⌘Tab, Dock, …): leave focus where they put it.
                cancel()
            }
        }

        if hovered?.id != hoveredID {
            hoveredID = hovered?.id
            hoveredSince = now
        }
        let settleTime = hovered == nil ? Self.leaveGrace : Self.dwell
        guard now.timeIntervalSince(hoveredSince) >= settleTime,
              NSEvent.pressedMouseButtons == 0 else { return }

        if let current = session {
            guard hovered?.id != current.target.windowID else { return }
            PinManager.shared.coverNow(current.target.windowID)
            if let hovered {
                // Moved straight onto another pinned window: focus it, but still return to the original window later.
                focus(hovered)
                session = Session(target: FocusTarget(pid: hovered.pid, windowID: hovered.id), previous: current.previous)
            } else {
                cancel()
                if let previous = current.previous, WindowList.exists(previous.windowID) {
                    WindowActivator.focus(pid: previous.pid, windowID: previous.windowID)
                }
            }
        } else if let hovered, !isFocused(hovered, frontPID: frontPID, stack: stack) {
            let previous = focusedWindow(frontPID: frontPID, stack: stack)
            focus(hovered)
            session = Session(target: FocusTarget(pid: hovered.pid, windowID: hovered.id), previous: previous)
            startMonitoring()
        }
    }

    /// Ends the current session without restoring focus.
    func cancel() {
        session = nil
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    func windowUnpinned(_ id: CGWindowID) {
        if session?.target.windowID == id {
            cancel()
        }
    }

    private func focus(_ window: WindowInfo) {
        WindowActivator.focus(pid: window.pid, windowID: window.id)
    }

    /// A click or keystroke means the user is working in the window, so it keeps focus when the pointer leaves.
    private func startMonitoring() {
        guard monitors.isEmpty else { return }
        let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { _ in
            MainActor.assumeIsolated { HoverFocus.shared.userInteracted() }
        }) {
            monitors.append(global)
        }
        // Clicks on a pinned window's mirror land in our own overlay panel.
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { event in
            MainActor.assumeIsolated { HoverFocus.shared.userInteracted() }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func userInteracted() {
        cancel()
    }

    private func isFocused(_ window: WindowInfo, frontPID: pid_t?, stack: [WindowInfo]) -> Bool {
        frontPID == window.pid && focusedWindow(frontPID: frontPID, stack: stack)?.windowID == window.id
    }

    /// The frontmost app's topmost normal window.
    private func focusedWindow(frontPID: pid_t?, stack: [WindowInfo]) -> FocusTarget? {
        guard let frontPID, frontPID != WindowList.ownPID,
              let window = stack.first(where: { $0.pid == frontPID && $0.isUserWindow }) else {
            return nil
        }
        return FocusTarget(pid: frontPID, windowID: window.id)
    }
}
