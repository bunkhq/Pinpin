#!/usr/bin/env bash
# Builds Pinpin.dmg and publishes it as a GitHub release.
# The version comes from CFBundleShortVersionString in Resources/Info.plist; bump it before releasing.
#
# The app is not signed with a Developer ID, so Gatekeeper blocks the first launch until the user
# approves it. See README → Install. It is signed with the self-signed "Pinpin Local Signing"
# certificate (./scripts/setup-signing.sh): macOS doesn't trust it, but it's stable, so Screen Recording
# and Accessibility grants carry over from one release to the next. Ad-hoc signatures change every build.
#
# Usage: ./scripts/release.sh [--no-publish]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Pinpin.app"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Resources/Info.plist")"
TAG="v$VERSION"
DMG="$ROOT/build/Pinpin-$VERSION.dmg"

if [[ "${1:-}" != "--no-publish" ]] && gh release view "$TAG" >/dev/null 2>&1; then
  echo "error: release $TAG already exists. Bump CFBundleShortVersionString in Resources/Info.plist." >&2
  exit 1
fi

IDENTITY="Pinpin Local Signing"
if ! security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  echo "error: no \"$IDENTITY\" certificate. Run ./scripts/setup-signing.sh once (and keep the keychain item; releases must all use it)." >&2
  exit 1
fi

# Universal (Apple Silicon + Intel).
PINPIN_UNIVERSAL=1 PINPIN_SIGN_IDENTITY="$IDENTITY" "$ROOT/scripts/build-app.sh"

# Disk image with the usual drag-to-Applications layout.
STAGING="$ROOT/build/dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Pinpin" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGING"

echo "Built $DMG"

if [[ "${1:-}" == "--no-publish" ]]; then
  exit 0
fi

gh release create "$TAG" "$DMG" --title "Pinpin $VERSION" --generate-notes --target "$(git -C "$ROOT" rev-parse HEAD)"
