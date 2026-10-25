import AppKit
import SwiftUI

struct MenuView: View {
    static let cornerRadius: CGFloat = 14

    /// Reports the content's size so the dropdown panel can resize to fit it exactly.
    var onSizeChange: (CGSize) -> Void = { _ in }

    @EnvironmentObject private var manager: PinManager
    @EnvironmentObject private var settings: Settings
    @State private var offerScreenRecording = Permissions.shouldOffer(.screenRecording)
    @State private var offerAccessibility = Permissions.shouldOffer(.accessibility)

    private static let rowSpacing: CGFloat = 6
    private static let sectionHeaderHeight: CGFloat = 22
    private static let maxListHeight: CGFloat = 340

    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            settingsSection
            permissionWarnings
            Divider()
            windowSection
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onSizeChange($0) }
        .onAppear(perform: refresh)
        .onReceive(refreshTimer) { _ in refresh() }
    }

    private var header: some View {
        HStack {
            PinGlyph(size: 16).foregroundStyle(.blue)
            Text("Pinpin").font(.headline)
            Spacer()
            Text("\(manager.pinnedCount) pinned")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HotkeyRow()
            SettingRow(title: "Sound effects") {
                Toggle("Sound effects", isOn: $settings.soundsEnabled)
            }
            SettingRow(title: "Notifications") {
                Toggle("Notifications", isOn: $settings.notificationsEnabled)
            }
            SettingRow(title: "Focus pinned windows on hover") {
                Toggle("Focus pinned windows on hover", isOn: $settings.autoFocusEnabled)
            }
            SettingRow(title: "Open at login") {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
            }
        }
        .toggleStyle(.switch)
    }

    @ViewBuilder
    private var permissionWarnings: some View {
        if offerScreenRecording {
            PermissionBanner(message: "Screen Recording lets Pinpin keep windows on top and show window titles.") {
                grant(.screenRecording)
            }
        }
        if offerAccessibility {
            PermissionBanner(message: "Accessibility lets Pinpin focus the right window when you click a pinned one.") {
                grant(.accessibility)
            }
        }
        if let error = manager.lastError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var windowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Windows")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if manager.windows.isEmpty && manager.otherWindows.isEmpty {
                Text("No windows open.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Self.rowSpacing) {
                        rows(for: manager.windows)
                        if !manager.otherWindows.isEmpty {
                            Text("Other Desktops & Minimized")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                                .frame(height: Self.sectionHeaderHeight, alignment: .bottomLeading)
                            rows(for: manager.otherWindows)
                        }
                    }
                    .padding(3)
                }
                // A ScrollView has no natural height, which would leave the MenuBarExtra window
                // mis-sized. Rows have a fixed height, so compute the list height up front.
                .frame(height: listHeight)
                .scrollBounceBehavior(.basedOnSize)
            }

            Button(role: .destructive) {
                manager.unpinAll()
            } label: {
                Label {
                    Text("Unpin All Windows")
                } icon: {
                    PinGlyph(image: PinIcon.remove, size: 16)
                }
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(manager.pinnedCount == 0)
        }
    }

    private func rows(for windows: [WindowInfo]) -> some View {
        ForEach(windows) { window in
            WindowRow(window: window, pinIndex: manager.pinIndex(of: window.id)) {
                manager.toggle(window)
            }
        }
    }

    private var listHeight: CGFloat {
        let rowCount = manager.windows.count + manager.otherWindows.count
        let headerCount = manager.otherWindows.isEmpty ? 0 : 1
        let itemCount = rowCount + headerCount
        let content = CGFloat(rowCount) * WindowRow.height
            + CGFloat(headerCount) * Self.sectionHeaderHeight
            + CGFloat(max(0, itemCount - 1)) * Self.rowSpacing
            + 6 // vertical padding
        return min(content, Self.maxListHeight)
    }

    private var footer: some View {
        HStack {
            Text("Click a window to pin it on top.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private func grant(_ permission: Permission) {
        Permissions.request(permission)
        refresh()
    }

    private func refresh() {
        manager.refreshWindows()
        offerScreenRecording = Permissions.shouldOffer(.screenRecording)
        offerAccessibility = Permissions.shouldOffer(.accessibility)
        settings.refreshLaunchAtLogin()
    }
}

private struct WindowRow: View {
    static let height: CGFloat = 44

    let window: WindowInfo
    /// 1-based pin index; higher indexes sit above lower ones.
    let pinIndex: Int?
    private var isPinned: Bool { pinIndex != nil }
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(window.displayTitle)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(window.appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let pinIndex {
                    HStack(spacing: 3) {
                        PinGlyph(size: 13)
                        Text("\(pinIndex)")
                            .font(.caption.weight(.bold).monospacedDigit())
                    }
                    .foregroundStyle(.blue)
                    .help("Pin \(pinIndex): sits above pins with a lower number")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: Self.height)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPinned ? Color.blue.opacity(0.12) : Color.primary.opacity(isHovered ? 0.08 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isPinned ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(isPinned ? "Click to unpin" : "Click to keep on top")
    }

    private var appIcon: NSImage {
        NSRunningApplication(processIdentifier: window.pid)?.icon
            ?? NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
            ?? NSImage()
    }
}

/// A settings line: label on the leading edge, control on the trailing edge, fixed height,
/// so every setting lines up the same way.
private struct SettingRow<Control: View>: View {
    static var height: CGFloat { 26 }

    let title: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            control
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height)
    }
}

private struct HotkeyRow: View {
    @EnvironmentObject private var settings: Settings
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingRow(title: "Hotkey") {
                HStack(spacing: 6) {
                    if settings.shortcut != .default && !isRecording {
                        Button {
                            settings.resetShortcut()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Reset to ⌥Space")
                    }
                    Button(action: toggleRecording) {
                        Text(isRecording ? "Type shortcut…" : settings.shortcut.displayString)
                            .font(.system(.callout, design: .rounded).weight(.medium))
                            .frame(minWidth: 96)
                    }
                    .buttonStyle(.bordered)
                    .tint(isRecording ? .accentColor : nil)
                }
            }
            if isRecording {
                Text("Press a key combination with a modifier. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if settings.shortcutConflict {
                Text("\(settings.shortcut.displayString) is in use by another app. Record a different one.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        // Release the current hotkey so it can be recorded again if desired.
        settings.suspendShortcut()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 && event.modifierFlags.intersection(Shortcut.relevantModifiers).isEmpty {
                stopRecording()
                return nil
            }
            guard let shortcut = Shortcut(event: event) else {
                NSSound.beep()
                return nil
            }
            settings.setShortcut(shortcut)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            isRecording = false
            settings.activateShortcut()
        }
    }
}

private struct PermissionBanner: View {
    let message: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield").foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Grant", action: action)
                .controlSize(.small)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
    }
}
