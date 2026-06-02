#!/bin/bash
# build.sh - compile Display BT Toggle.app from source.
#
# Usage:
#   ./build.sh                 # build ./Display BT Toggle.app
#   INSTALL=1 ./build.sh       # also move to /Applications
#
# Requirements:
#   - macOS with osacompile (built-in)
#   - Xcode command line tools (for codesign)

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Display BT Toggle"
APP_BUNDLE="${APP_NAME}.app"

rm -rf "$APP_BUNDLE"

# Compile the AppleScript wrapper.
osacompile -o "$APP_BUNDLE" display_bt_toggle.applescript

# Bundle the watcher script.
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp display-bt-watcher.sh "$APP_BUNDLE/Contents/Resources/display-bt-watcher.sh"
chmod +x "$APP_BUNDLE/Contents/Resources/display-bt-watcher.sh"

# Configure as a menu bar app (no Dock icon, no menu bar).
PLIST="$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :OSAAppletStayOpen bool true" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :OSAAppletStayOpen true" "$PLIST"

# Re-sign (modifying Info.plist invalidates the previous signature).
codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1

echo "Built: $APP_BUNDLE"

if [ "${INSTALL:-0}" = "1" ]; then
    rm -rf "/Applications/$APP_BUNDLE"
    mv "$APP_BUNDLE" "/Applications/$APP_BUNDLE"
    echo "Installed to /Applications/$APP_BUNDLE"
fi
