#!/usr/bin/env bash
# Builds Pinpin.app into ./build. Pass --run to launch it afterwards.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Pinpin.app"

if [[ -n "${PINPIN_UNIVERSAL:-}" ]]; then
  # Build each architecture and merge them (swift build's own multi-arch mode needs full Xcode).
  BIN="$ROOT/build/Pinpin-universal"
  mkdir -p "$ROOT/build"
  SLICES=()
  for arch in arm64 x86_64; do
    swift build -c release --package-path "$ROOT" --triple "$arch-apple-macosx14.0"
    # Newer SwiftPM builds every triple into the same bin path, so copy each slice out before the next build.
    cp "$(swift build -c release --package-path "$ROOT" --triple "$arch-apple-macosx14.0" --show-bin-path)/Pinpin" "$ROOT/build/Pinpin-$arch"
    SLICES+=("$ROOT/build/Pinpin-$arch")
  done
  lipo -create "${SLICES[@]}" -output "$BIN"
else
  swift build -c release --package-path "$ROOT"
  BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/Pinpin"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pinpin"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# App icon: render every size macOS wants from the 1024px master.
ICONSET="$ROOT/build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$ROOT/assets/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$ROOT/assets/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# A stable signing identity keeps Screen Recording / Accessibility grants valid across rebuilds.
# Ad-hoc signatures change every build, so macOS would treat each build as a new app.
LOCAL_IDENTITY="Pinpin Local Signing"
if [[ -n "${PINPIN_SIGN_IDENTITY:-}" ]]; then
  IDENTITY="$PINPIN_SIGN_IDENTITY"
elif security find-certificate -c "$LOCAL_IDENTITY" >/dev/null 2>&1; then
  IDENTITY="$LOCAL_IDENTITY"
else
  IDENTITY="-"
  echo "warning: signing ad-hoc; permissions will reset every build. Run ./scripts/setup-signing.sh once to fix." >&2
fi
codesign --force --sign "$IDENTITY" --identifier com.trelakor.pinpin "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--run" ]]; then
  pkill -x Pinpin 2>/dev/null || true
  open "$APP"
fi
