# Development

[← Back to README](../README.md)

- [Requirements](#requirements)
- [Build and run](#build-and-run)
- [Code signing](#code-signing)
- [Releasing](#releasing)
- [README images](#readme-images)
- [Code layout](#code-layout)

## Requirements

- macOS 14 or later
- The Swift toolchain. Command Line Tools are enough; full Xcode isn't needed.
- [GitHub CLI](https://cli.github.com) (`gh`), for publishing releases only

## Build and run

```sh
./scripts/build-app.sh         # builds build/Pinpin.app
./scripts/build-app.sh --run   # builds it, quits any running Pinpin, and opens the new build
```

By default this builds for your Mac's architecture only. To build a universal (Apple Silicon + Intel) binary, set `PINPIN_UNIVERSAL=1`:

```sh
PINPIN_UNIVERSAL=1 ./scripts/build-app.sh
```

The script also renders the app icon from `assets/icon.png` and signs the app.

## Code signing

Run this once per Mac:

```sh
./scripts/setup-signing.sh
```

It creates a self-signed **Pinpin Local Signing** certificate in your login keychain. `build-app.sh` signs every build with it.

**Why it matters:** macOS ties Screen Recording and Accessibility grants to the app's signature. With a stable signature, you grant permissions once and they survive rebuilds. Without the certificate, builds are signed ad-hoc. Each rebuild then looks like a new app to macOS, and it asks for permissions again.

To sign with a different identity, set `PINPIN_SIGN_IDENTITY`:

```sh
PINPIN_SIGN_IDENTITY="Developer ID Application: …" ./scripts/build-app.sh
```

> [!IMPORTANT]
> Every published release must be signed with the same certificate, or users lose their permission grants when they update. Keep the **Pinpin Local Signing** keychain item and don't recreate it.

## Releasing

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Commit and push.
3. Run the release script:

```sh
./scripts/release.sh               # builds a universal DMG and publishes GitHub release vX.Y.Z
./scripts/release.sh --no-publish  # same, but stops after build/Pinpin-X.Y.Z.dmg
```

The script:

- Refuses to run if release `vX.Y.Z` already exists.
- Requires the **Pinpin Local Signing** certificate.
- Builds a universal app and packages it into a DMG with the usual drag-to-Applications layout.
- Publishes the release with notes generated from merged pull requests.

## README images

The demo GIF and the social preview image are drawn by scripts, so you can regenerate them after UI changes without recording your screen:

```sh
swift scripts/render-demo.swift            # writes assets/demo.gif
swift scripts/render-social-preview.swift  # writes assets/social-preview.png
```

The demo is a mock. It only draws what Pinpin really shows (the menu bar icon and the Activated/Deactivated pill), so update `render-demo.swift` if those change. After regenerating the social preview, upload it in **Settings → General → Social preview** on GitHub.

## Code layout

| Path | Purpose |
| --- | --- |
| `Sources/Pinpin/PinpinApp.swift` | App entry point and launch setup |
| `Sources/Pinpin/StatusItemController.swift` | Menu bar button and the dropdown panel, which resizes to fit its content |
| `Sources/Pinpin/MenuView.swift` | Dropdown UI: settings, permission banners, window list, Unpin All |
| `Sources/Pinpin/PinManager.swift` | Pinned state, pin numbering, hotkey action, window tracking and stacking |
| `Sources/Pinpin/PinOverlay.swift` | Per-window overlay panel and its live ScreenCaptureKit mirror |
| `Sources/Pinpin/HoverFocus.swift` | Focus pinned windows on hover, and hand focus back on leave |
| `Sources/Pinpin/WindowList.swift` | Window enumeration and coordinate conversion |
| `Sources/Pinpin/Permissions.swift` | Permission checks, the Grant flow, and focusing a specific window |
| `Sources/Pinpin/HotKeyCenter.swift` | Global hotkey registration (Carbon) |
| `Sources/Pinpin/Shortcut.swift` | Hotkey model, validation, and display |
| `Sources/Pinpin/Settings.swift` | Saved settings and the login item |
| `Sources/Pinpin/Feedback.swift` | Synthesized toggle sounds and the bottom-of-screen pill |
| `Sources/Pinpin/PinIcon.swift` | Custom pin icons |
| `Resources/Info.plist` | Bundle metadata and version |
| `assets/` | App icon master and pin icon SVGs |
| `scripts/` | Build, signing, release, and README image scripts |

For how the pieces fit together, see [How it works](HOW-IT-WORKS.md).
