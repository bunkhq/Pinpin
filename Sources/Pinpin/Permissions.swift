import AppKit
import ApplicationServices

enum Permission: String {
    /// Needed to mirror window contents and to read window titles.
    case screenRecording
    /// Needed to raise a specific window when its floating mirror is clicked.
    case accessibility

    var name: String {
        switch self {
        case .screenRecording: "Screen Recording"
        case .accessibility: "Accessibility"
        }
    }

    fileprivate var settingsURL: String {
        switch self {
        case .screenRecording: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .accessibility: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
    }
}

@MainActor
enum Permissions {
    static var hasScreenRecording: Bool { isGranted(.screenRecording) }
    static var hasAccessibility: Bool { isGranted(.accessibility) }

    private static let didPromptKey = "didPromptForPermissions"
    /// Set right before relaunching to pick up Screen Recording, so a second miss can be recognized as stale.
    private static let relaunchedForScreenRecordingKey = "relaunchedForScreenRecording"

    private static func grantedKey(_ permission: Permission) -> String { "granted.\(permission.rawValue)" }

    /// Checks with macOS right now, and remembers a grant once it's seen.
    static func isGranted(_ permission: Permission) -> Bool {
        let granted = switch permission {
        case .screenRecording: CGPreflightScreenCaptureAccess() || canReadOtherWindowTitles()
        case .accessibility: AXIsProcessTrusted()
        }
        if granted {
            UserDefaults.standard.set(true, forKey: grantedKey(permission))
            UserDefaults.standard.removeObject(forKey: relaunchedForScreenRecordingKey)
        }
        return granted
    }

    /// Whether the permission was granted at some point. Once it has been, Pinpin stops asking for it
    /// on its own and only asks again when something actually needs it and macOS says it's missing.
    static func wasGranted(_ permission: Permission) -> Bool {
        UserDefaults.standard.bool(forKey: grantedKey(permission))
    }

    /// Whether to show the "Grant" banner: missing now and never granted before.
    static func shouldOffer(_ permission: Permission) -> Bool {
        !isGranted(permission) && !wasGranted(permission)
    }

    /// `CGPreflightScreenCaptureAccess` only reads the permission when the process starts. Other apps'
    /// window titles are only visible with Screen Recording, and that check is live.
    private static func canReadOtherWindowTitles() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let ownPID = getpid()
        return list.contains { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  info[kCGWindowLayer as String] as? Int == 0,
                  let owner = info[kCGWindowOwnerName as String] as? String,
                  owner != "Dock", owner != "Window Server",
                  let title = info[kCGWindowName as String] as? String else { return false }
            return !title.isEmpty
        }
    }

    /// Only the very first launch prompts on its own; after that, missing permissions show in the menu.
    static func requestMissingOnFirstLaunch() {
        // Record anything already granted, e.g. when updating from a version that didn't remember grants.
        let missing = [Permission.screenRecording, .accessibility].filter { !isGranted($0) }
        guard !UserDefaults.standard.bool(forKey: didPromptKey) else { return }
        UserDefaults.standard.set(true, forKey: didPromptKey)
        if missing.contains(.screenRecording) {
            CGRequestScreenCaptureAccess()
        }
        if missing.contains(.accessibility) {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    /// The Grant flow. Checks first and does nothing if the permission is already there. Otherwise
    /// asks whether it's already on in System Settings, since macOS can show it on for an entry
    /// that no longer matches this copy of Pinpin, and Screen Recording needs a relaunch to apply.
    static func request(_ permission: Permission) {
        guard !isGranted(permission) else { return }

        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Pinpin needs \(permission.name) access"
        alert.informativeText = switch permission {
        case .screenRecording: "This lets Pinpin keep windows on top and show window titles. Is Screen Recording already turned on for Pinpin in System Settings?"
        case .accessibility: "This lets Pinpin focus the right window when you click a pinned one. Is Accessibility already turned on for Pinpin in System Settings?"
        }
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "It's Already On")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            openSettings(for: permission)
        case .alertSecondButtonReturn:
            alreadyOn(permission)
        default:
            break
        }
    }

    private static func openSettings(for permission: Permission) {
        // Adds Pinpin to the list in System Settings (the system prompt itself only ever shows once).
        switch permission {
        case .screenRecording:
            CGRequestScreenCaptureAccess()
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        if let url = URL(string: permission.settingsURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// The user says it's on, but macOS says it isn't.
    private static func alreadyOn(_ permission: Permission) {
        let defaults = UserDefaults.standard
        if permission == .screenRecording && !defaults.bool(forKey: relaunchedForScreenRecordingKey) {
            // macOS only applies a new Screen Recording grant to apps launched after it.
            let alert = NSAlert()
            alert.messageText = "Relaunch Pinpin to finish"
            alert.informativeText = "macOS applies Screen Recording after Pinpin restarts. Your pins will be cleared."
            alert.addButton(withTitle: "Relaunch")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                defaults.set(true, forKey: relaunchedForScreenRecordingKey)
                relaunch()
            }
            return
        }
        // It's on, but for an entry that doesn't match this copy of Pinpin, typically left behind
        // by a version signed differently. Removing it and adding Pinpin again fixes it.
        let alert = NSAlert()
        alert.messageText = "macOS doesn't recognize this copy of Pinpin"
        alert.informativeText = "The \(permission.name) entry for Pinpin belongs to a different copy of the app, usually an earlier version. In System Settings, select Pinpin, remove it with the – button, then add it again with + (or relaunch Pinpin) and turn it on."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            defaults.removeObject(forKey: relaunchedForScreenRecordingKey)
            openSettings(for: permission)
        }
    }

    private static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

enum WindowActivator {
    /// Brings a specific window of another app to the front and gives it focus.
    static func focus(pid: pid_t, windowID: CGWindowID) {
        if AXIsProcessTrusted() {
            let app = AXUIElementCreateApplication(pid)
            if let window = axWindow(in: app, id: windowID) {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            }
            AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
        NSRunningApplication(processIdentifier: pid)?.activate(options: [])
    }

    private static func axWindow(in app: AXUIElement, id: CGWindowID) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return nil
        }
        return windows.first { window in
            var windowID: CGWindowID = 0
            return _AXUIElementGetWindow(window, &windowID) == .success && windowID == id
        }
    }
}
