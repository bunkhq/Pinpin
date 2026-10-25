import AppKit
import CoreGraphics

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let layer: Int
    let alpha: Double
    let isOnScreen: Bool
    /// Global display coordinates with a top-left origin (CoreGraphics space).
    let bounds: CGRect

    var displayTitle: String { title.isEmpty ? appName : title }

    var isUserWindow: Bool {
        layer == 0 && alpha > 0 && bounds.width >= 60 && bounds.height >= 40
    }
}

enum WindowList {
    static let ownPID = ProcessInfo.processInfo.processIdentifier

    /// Every on-screen window, front to back, including our own and system chrome.
    static func allOnScreen() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return raw.compactMap(parse)
    }

    /// Normal app windows the user can pin, front to back.
    static func userWindows() -> [WindowInfo] {
        allOnScreen().filter { $0.isUserWindow && $0.pid != ownPID }
    }

    /// Windows that are minimized or on another Space. The full window list is full of invisible helper
    /// windows, so only titled, reasonably sized windows of regular (Dock) apps are included.
    static func offScreenUserWindows() -> [WindowInfo] {
        let regularPIDs = Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .map(\.processIdentifier)
        )
        guard let raw = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return raw.compactMap(parse).filter { window in
            !window.isOnScreen
                && window.layer == 0
                && window.alpha > 0
                && window.pid != ownPID
                && regularPIDs.contains(window.pid)
                && !window.title.isEmpty
                && window.bounds.width >= 150
                && window.bounds.height >= 100
        }
    }

    /// Whether the window still exists anywhere (it may be minimized or on another Space).
    static func exists(_ id: CGWindowID) -> Bool {
        let ids = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 1)
        defer { ids.deallocate() }
        ids[0] = UnsafeRawPointer(bitPattern: UInt(id))
        guard let array = CFArrayCreate(nil, ids, 1, nil),
              let info = CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]] else {
            return false
        }
        return !info.isEmpty
    }

    private static func parse(_ dict: [String: Any]) -> WindowInfo? {
        guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
              let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
              let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
            return nil
        }
        return WindowInfo(
            id: id,
            pid: pid,
            appName: dict[kCGWindowOwnerName as String] as? String ?? "Unknown",
            title: dict[kCGWindowName as String] as? String ?? "",
            layer: dict[kCGWindowLayer as String] as? Int ?? 0,
            alpha: dict[kCGWindowAlpha as String] as? Double ?? 1,
            isOnScreen: dict[kCGWindowIsOnscreen as String] as? Bool ?? false,
            bounds: bounds
        )
    }
}

enum ScreenGeometry {
    /// Converts a CoreGraphics (top-left origin) rect into Cocoa (bottom-left origin) screen space.
    static func cocoaRect(fromCG rect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func backingScale(for cocoaRect: CGRect) -> CGFloat {
        let screen = NSScreen.screens.max { a, b in
            a.frame.intersection(cocoaRect).area < b.frame.intersection(cocoaRect).area
        }
        return screen?.backingScaleFactor ?? 2
    }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
