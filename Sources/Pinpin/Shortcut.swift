import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut: a virtual key code plus Cocoa modifier flags.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlags: UInt
    var keyName: String

    static let `default` = Shortcut(
        keyCode: UInt32(kVK_Space),
        modifierFlags: NSEvent.ModifierFlags.option.rawValue,
        keyName: "Space"
    )

    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags).intersection(Self.relevantModifiers)
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + keyName
    }

    /// Builds a shortcut from a key-down event, or nil if the combination isn't usable as a global hotkey.
    init?(event: NSEvent) {
        let mods = event.modifierFlags.intersection(Self.relevantModifiers)
        let isFunctionKey = Self.functionKeyCodes.contains(Int(event.keyCode))
        // Bare keys (other than F-keys) would hijack normal typing.
        guard !mods.isEmpty || isFunctionKey else { return nil }
        self.keyCode = UInt32(event.keyCode)
        self.modifierFlags = mods.rawValue
        self.keyName = Self.name(forKeyCode: Int(event.keyCode), characters: event.charactersIgnoringModifiers)
    }

    init(keyCode: UInt32, modifierFlags: UInt, keyName: String) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.keyName = keyName
    }

    private static let functionKeyCodes: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19,
    ]

    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_DownArrow: "↓", kVK_UpArrow: "↑", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19",
    ]

    private static func name(forKeyCode keyCode: Int, characters: String?) -> String {
        if let special = specialKeyNames[keyCode] { return special }
        let chars = (characters ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return chars.isEmpty ? "Key \(keyCode)" : chars.uppercased()
    }
}
