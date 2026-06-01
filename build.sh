#!/usr/bin/env bash
# build.sh — compile Sleepless.app from source with the Command Line Tools only.
#
# No Xcode project, no Package.swift: just `swiftc` + a hand-assembled .app bundle,
# ad-hoc signed. Works from any clone (no hardcoded paths or usernames).
#
# Usage:
#   ./build.sh                      # build into ./build/Sleepless.app
#   ./build.sh /Applications        # build straight into /Applications
#   DEST=/Applications ./build.sh   # same, via env
#   ./build.sh --regen-icon         # re-render the .icns from make-icon.swift first
#
# It NEVER touches sudo, sleep settings, or the menu bar. Use install.sh for the
# passwordless grant + login item.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Sleepless"
# macOS arm64 target. Sleepless is verified on macOS 26 (Tahoe) / Apple Silicon.
# Override with TARGET=... (e.g. CI on a runner whose SDK predates macOS 26).
TARGET="${TARGET:-arm64-apple-macos26.0}"

# Destination: first non-flag arg, else $DEST, else ./build
DEST="${DEST:-}"
REGEN_ICON=0
for arg in "$@"; do
  case "$arg" in
    --regen-icon) REGEN_ICON=1 ;;
    *) DEST="$arg" ;;
  esac
done
DEST="${DEST:-$REPO/build}"

APP="$DEST/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "==> Building $APP_NAME.app"
echo "    repo:   $REPO"
echo "    dest:   $DEST"
echo "    target: $TARGET"

command -v swiftc >/dev/null || { echo "error: swiftc not found. Install the Command Line Tools: xcode-select --install" >&2; exit 1; }

# 1. Optionally regenerate the icon from the SF Symbol (needs a GUI session for AppKit).
ICNS="$REPO/assets/$APP_NAME.icns"
if [ "$REGEN_ICON" = "1" ]; then
  echo "==> Regenerating icon from make-icon.swift"
  TMP_ICON="$(mktemp -d)"
  swiftc -O -framework AppKit "$REPO/make-icon.swift" -o "$TMP_ICON/mkicon"
  "$TMP_ICON/mkicon" "$TMP_ICON"
  iconutil -c icns "$TMP_ICON/$APP_NAME.iconset" -o "$REPO/assets/$APP_NAME.icns"
  rm -rf "$TMP_ICON"
fi
[ -f "$ICNS" ] || { echo "error: missing $ICNS (run ./build.sh --regen-icon)" >&2; exit 1; }

# 2. Compile the executable.
echo "==> Compiling App.swift"
BIN_TMP="$(mktemp -d)"
swiftc -O -parse-as-library -target "$TARGET" -framework AppKit \
  "$REPO/App.swift" -o "$BIN_TMP/$APP_NAME"

# 3. Assemble the bundle: Contents/{Info.plist, MacOS/<exe>, Resources/<name>.icns}
echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$REPO/Info.plist" "$CONTENTS/Info.plist"
cp "$BIN_TMP/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
cp "$ICNS" "$CONTENTS/Resources/$APP_NAME.icns"
chmod +x "$CONTENTS/MacOS/$APP_NAME"
rm -rf "$BIN_TMP"

# 4. Ad-hoc sign (no Apple Developer ID needed; trust comes from building it yourself).
echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=1 "$APP" 2>&1 | sed 's/^/    /' || true

echo ""
echo "✅ Built $APP"
echo "   Launch it:  open \"$APP\""
echo "   For lid-closed-on-battery to actually work, run ./install.sh once to add the"
echo "   passwordless grant (it explains exactly what it installs)."
