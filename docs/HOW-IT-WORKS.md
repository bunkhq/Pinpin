# How it works

[← Back to README](../README.md)

- [The problem](#the-problem)
- [Live mirrors](#live-mirrors)
- [Stacking several pins](#stacking-several-pins)
- [Clicking a pinned window](#clicking-a-pinned-window)
- [Known limitations](#known-limitations)

## The problem

macOS doesn't let one app change the window level of another app's windows unless System Integrity Protection (SIP) is disabled. Pinpin can't make a window "always on top" directly. It keeps the window *looking* on top instead.

## Live mirrors

For each pinned window, Pinpin:

1. Streams the window's contents with **ScreenCaptureKit**, at up to 60 frames per second.
2. Places a borderless, click-through panel exactly over the real window, above normal windows. The panel never takes focus from the app you're using.
3. Shows a **live mirror** of the window in that panel whenever the real window might be covered.

The mirror goes up when:

- You click outside the pinned window.
- You switch apps, including with **⌘Tab**.
- Another window overlaps the pinned window.

Pinpin puts the mirror up *before* macOS reorders the windows, so the pinned window never visibly drops behind. The mirror appears without any fade, and the panel follows the real window as you move or resize it. Pinpin checks window positions about 30 times per second.

When the pinned window is minimized or on another desktop, its panel is taken off screen until it comes back.

## Stacking several pins

At most one pinned window is shown for real: the one you're working in, when nothing covers it. Every other pinned window is shown as its mirror.

- Mirrors are stacked by pin number, highest on top.
- The real window sits below all the mirrors. Mirrors with a **lower** number get a hole cut where the real window is, so it shows through. Mirrors with a **higher** number stay on top of it.
- Holes have rounded corners to match macOS windows.

To avoid a one-frame glimpse of the wrong window, every update happens in a fixed order: mirrors go up first, then holes are cut, and only then are real windows uncovered.

## Clicking a pinned window

Clicking a mirror focuses the real window through **Accessibility**. The mirror stays up until the real window is actually in front, then gets out of the way.

A pinned window's own sheets, dialogs, and popovers count as part of it. They don't trigger the mirror.

## Known limitations

- **The mirror is view-only.** While another app is focused, scrolling over a pinned window doesn't reach it. The first click on a mirror focuses the real window instead of passing through to what you clicked. Turn on [Focus pinned windows on hover](USAGE.md#focus-pinned-windows-on-hover) to avoid both.
- **Screen Recording needs a relaunch.** macOS applies a new grant only after Pinpin restarts. See [Permissions](PERMISSIONS.md#screen-recording-is-on-but-pinpin-says-its-missing).
- **The hotkey can't be a key on its own.** It needs a modifier, except for function keys. See [Changing the hotkey](USAGE.md#changing-the-hotkey).
- **Not notarized.** Pinpin isn't signed with an Apple Developer ID, so macOS blocks the first launch. See [Install](../README.md#install).
