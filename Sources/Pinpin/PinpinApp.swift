import AppKit
import SwiftUI

@main
struct PinpinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The UI lives in the status item's dropdown (StatusItemController); an app needs at least one scene.
        SwiftUI.Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        MainActor.assumeIsolated {
            statusItemController = StatusItemController()

            HotKeyCenter.shared.onPress = {
                MainActor.assumeIsolated { PinManager.shared.toggleFrontmostWindow() }
            }
            Settings.shared.activateShortcut()
            Settings.shared.setUpLaunchAtLogin()

            Permissions.requestMissingOnFirstLaunch()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { PinManager.shared.unpinAll(announce: false) }
    }
}
