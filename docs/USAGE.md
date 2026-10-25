# Usage

[← Back to README](../README.md)

- [The hotkey](#the-hotkey)
- [The menu bar dropdown](#the-menu-bar-dropdown)
- [Pin numbering and stacking](#pin-numbering-and-stacking)
- [Focus pinned windows on hover](#focus-pinned-windows-on-hover)
- [Settings](#settings)
- [Feedback: sounds and notifications](#feedback-sounds-and-notifications)

## The hotkey

Press the hotkey (default **⌥Space**) to toggle the focused window:

- If the window isn't pinned, Pinpin pins it on top.
- If it's already pinned, Pinpin unpins it.

The hotkey acts on the frontmost window of the frontmost app. If there's no window to act on, for example when Pinpin's own dropdown is focused, macOS plays the alert sound.

### Changing the hotkey

1. Open the dropdown and click the shortcut field.
2. Press the new key combination. **Esc** cancels.
3. To restore **⌥Space**, click **↺**.

Rules for hotkeys:

- A hotkey must include at least one modifier (**⌃**, **⌥**, **⇧** or **⌘**). The only exception is function keys (F1–F19), which work on their own. A single key without a modifier would interfere with normal typing.
- If another app already uses the combination, the dropdown says so. Record a different one.
- The hotkey is turned off while you record a new one, so you can press the current combination without triggering it.

## The menu bar dropdown

Click the pin icon in the menu bar to open the dropdown. The dropdown has three parts:

1. **Header:** how many windows are pinned, plus a **Grant** banner for each permission Pinpin is missing.
2. **Settings:** hotkey and toggles. See [Settings](#settings).
3. **Window list:** see below.

### Window list

The **Windows** section lists, in this order:

1. **Pinned windows,** by pin number. Each one is highlighted blue and shows its number.
2. **Other windows on the current desktop,** most recently focused first.

The **Other Desktops & Minimized** section lists unpinned windows that are minimized or on another desktop. Pinning one of them brings it to you.

Click a window to pin or unpin it. The dropdown stays open and on top while you pin, so you can pin several windows in a row.

**Unpin All Windows** removes every pin at once.

### Closing the dropdown

Click anywhere outside it, press **Esc**, or click the menu bar icon again.

## Pin numbering and stacking

Pins are numbered in the order you make them: 1, 2, 3, and so on.

- **A higher number always sits above a lower one,** whichever window has focus. For example, pin #2 stays above pin #1 even while you're typing in #1.
- **Unpinning closes the gap.** If you unpin #3 of 5, the old #4 and #5 become #3 and #4. Their order relative to each other doesn't change.
- **Pins don't survive a relaunch.** Quitting or restarting Pinpin clears every pin.

## Focus pinned windows on hover

This setting is off by default. When it's on:

1. Rest the pointer on a pinned window. After a short moment (about 0.1 seconds), the window takes focus. Your first click or keystroke goes straight to it.
2. If you move away without clicking or typing, focus goes back to the window you were using before.
3. If you click or type in the pinned window, it keeps focus after you move away.

Details:

- Where pinned windows overlap, the one with the highest pin number gets focus.
- Moving straight from one pinned window to another focuses the second one. Focus still goes back to your original window when you leave both.
- If you switch apps yourself (for example with **⌘Tab** or the Dock), Pinpin leaves focus where you put it.
- Hovering the Dock or menu bar over a pinned window's edge doesn't move focus.
- Hover focus pauses while the Pinpin dropdown is open.

Turn hover focus on if you want to scroll a pinned window while another app is focused. See [Known limitations](HOW-IT-WORKS.md#known-limitations).

## Settings

| Setting | Default | What it does |
| --- | --- | --- |
| Hotkey | **⌥Space** | Toggles a pin on the focused window. See [Changing the hotkey](#changing-the-hotkey). |
| Sound effects | On | Plays a chime when you pin or unpin. |
| Notifications | On | Shows a small pill at the bottom of the screen when you pin or unpin. |
| Focus pinned windows on hover | Off | See [Focus pinned windows on hover](#focus-pinned-windows-on-hover). |
| Open at login | On | Starts Pinpin when you log in. It also appears in **System Settings → General → Login Items**. |

Settings are saved and survive relaunches. Pins are not saved.

Open at login is turned on once, the first time Pinpin runs. After that, Pinpin keeps whatever you choose, either in the dropdown or in System Settings.

## Feedback: sounds and notifications

Each pin or unpin gives two kinds of feedback. You can turn each one off separately.

- **Sound:** a soft rising chime for pin and a falling chime for unpin.
- **Notification:** a blue **Activated** or red **Deactivated** pill at the bottom of the screen, for about a second.
