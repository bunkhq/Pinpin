import Foundation
import ServiceManagement

@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    private static let shortcutKey = "shortcut"
    private static let soundsKey = "soundsEnabled"
    private static let notificationsKey = "notificationsEnabled"
    private static let autoFocusKey = "autoFocusEnabled"
    private static let didSetUpLaunchAtLoginKey = "didSetUpLaunchAtLogin"

    @Published private(set) var shortcut: Shortcut
    /// Set when the current shortcut couldn't be registered system-wide.
    @Published private(set) var shortcutConflict = false

    @Published var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: Self.soundsKey) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsKey) }
    }

    /// Focus a pinned window while the pointer is over it, and hand focus back when it leaves.
    @Published var autoFocusEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoFocusEnabled, forKey: Self.autoFocusKey)
            if !autoFocusEnabled { HoverFocus.shared.cancel() }
        }
    }

    /// Mirrors the system's login item for this app, which the user can also change in System Settings.
    @Published private(set) var launchAtLogin = false

    private init() {
        UserDefaults.standard.register(defaults: [Self.soundsKey: true, Self.notificationsKey: true])
        soundsEnabled = UserDefaults.standard.bool(forKey: Self.soundsKey)
        notificationsEnabled = UserDefaults.standard.bool(forKey: Self.notificationsKey)
        autoFocusEnabled = UserDefaults.standard.bool(forKey: Self.autoFocusKey)
        if let data = UserDefaults.standard.data(forKey: Self.shortcutKey),
           let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
            shortcut = saved
        } else {
            shortcut = .default
        }
    }

    func setShortcut(_ newValue: Shortcut) {
        shortcut = newValue
        if let data = try? JSONEncoder().encode(newValue) {
            UserDefaults.standard.set(data, forKey: Self.shortcutKey)
        }
        activateShortcut()
    }

    func resetShortcut() {
        setShortcut(.default)
    }

    func activateShortcut() {
        shortcutConflict = !HotKeyCenter.shared.register(shortcut)
    }

    /// Launch at login is on by default: the first launch registers the login item once,
    /// after that the user's choice (here or in System Settings) is left alone.
    func setUpLaunchAtLogin() {
        if !UserDefaults.standard.bool(forKey: Self.didSetUpLaunchAtLoginKey) {
            UserDefaults.standard.set(true, forKey: Self.didSetUpLaunchAtLoginKey)
            try? SMAppService.mainApp.register()
        }
        refreshLaunchAtLogin()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Pinpin: couldn't update login item: \(error.localizedDescription)")
        }
        refreshLaunchAtLogin()
        if enabled && SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    func refreshLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        let enabled = status == .enabled || status == .requiresApproval
        if enabled != launchAtLogin { launchAtLogin = enabled }
    }

    func suspendShortcut() {
        HotKeyCenter.shared.unregister()
    }
}
