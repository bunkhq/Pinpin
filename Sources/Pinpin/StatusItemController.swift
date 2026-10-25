import AppKit
import Combine
import SwiftUI

/// The menu bar button and its dropdown. This replaces SwiftUI's `MenuBarExtra`, whose window keeps the
/// size it had when it first opened and clips its content when the window list grows or shrinks.
/// Here the panel is resized to its content on every layout change, keeping its top edge under the menu bar.
@MainActor
final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panel = DropdownPanel()
    private let background = NSVisualEffectView()
    private var hostingView: NSHostingView<AnyView>?
    private var pinnedObserver: AnyCancellable?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var lastClosed = Date.distantPast

    init() {
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
        pinnedObserver = PinManager.shared.$pinOrder.sink { [weak self] ids in
            self?.updateIcon(hasPinned: !ids.isEmpty)
            // Pinning from the list can focus another app; keep the dropdown above everything so
            // the rest of the list stays reachable.
            DispatchQueue.main.async { self?.keepPanelInFront() }
        }

        background.material = .menu
        background.state = .active
        background.blendingMode = .behindWindow
        background.maskImage = Self.roundedMask(radius: MenuView.cornerRadius)
        panel.contentView = background
        panel.onCancel = { [weak self] in self?.close() }
    }

    private func updateIcon(hasPinned: Bool) {
        let image = (hasPinned ? PinIcon.filled : PinIcon.outline).copy() as! NSImage
        image.size = NSSize(width: 18, height: 18)
        image.accessibilityDescription = "Pinpin"
        statusItem.button?.image = image
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            close()
        } else if Date().timeIntervalSince(lastClosed) > 0.2 {
            // Skip if this same click just closed the panel by taking focus away from it.
            open()
        }
    }

    private func open() {
        // Load the window list before the first layout so the panel opens at its final size.
        PinManager.shared.refreshWindows()

        // A fresh view each time re-runs onAppear (permission checks, refresh timer).
        let root = MenuView { [weak self] size in self?.resize(to: size) }
            .environmentObject(PinManager.shared)
            .environmentObject(Settings.shared)
        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.subviews.forEach { $0.removeFromSuperview() }
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        hostingView = hosting

        resize(to: hosting.fittingSize)
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
        HoverFocus.shared.isSuspended = true

        // Close on clicks elsewhere: in other apps, or on one of Pinpin's own mirrors.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated { [weak self] in self?.close() }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                if let self, event.window !== self.panel, event.window !== self.statusItem.button?.window {
                    self.close()
                }
            }
            return event
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { [weak self] in self?.keepPanelInFront() }
        }
    }

    private func keepPanelInFront() {
        guard panel.isVisible else { return }
        panel.orderFrontRegardless()
    }

    private func close() {
        guard panel.isVisible else { return }
        lastClosed = Date()
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        HoverFocus.shared.isSuspended = false
        // Tearing the view down fires onDisappear, which ends any in-progress hotkey recording.
        hostingView?.removeFromSuperview()
        hostingView = nil
        for monitor in [outsideClickMonitor, localClickMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        outsideClickMonitor = nil
        localClickMonitor = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
    }

    /// Sizes the panel to the content and anchors it just below the status item, kept on-screen.
    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0,
              let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        var x = buttonFrame.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let top = min(buttonFrame.minY - 6, visible.maxY)
        let height = min(size.height, top - visible.minY - 8)

        let frame = CGRect(x: x, y: top - height, width: size.width, height: height).integral
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// Borderless, non-activating panel that can still become key (for the hotkey recorder and shortcuts)
/// without pulling the user's current app out of focus. It deliberately stays open when another app
/// takes focus (pinning a window can do that); clicks outside, Esc, or the menu bar button close it.
private final class DropdownPanel: NSPanel {
    var onCancel: (() -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .popUpMenu
        isFloatingPanel = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
