#!/bin/bash
# display-bt-watcher.sh
# Listens to macOS unified log for display power events and toggles a
# user-configured Bluetooth device via blueutil. See README.md.

LOCKFILE=/tmp/macos-bt-disconnect.lock
if [ -f "$LOCKFILE" ] && kill -0 "$(cat "$LOCKFILE")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

# --- Config ---------------------------------------------------------------
# Load user config if it exists.
CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/macos-bluetooth-disconnect/config}"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

# Defaults (overridden by config file).
: "${BT:=/opt/homebrew/bin/blueutil}"
: "${MAC:=88-92-cc-e5-ce-aa}"
: "${LOG_PREDICATE:=category == \"display\" AND subsystem == \"com.apple.SkyLight\"}"
: "${SLEEP_PATTERN:=Event: Will Sleep|Event: Did Sleep}"
: "${WAKE_PATTERN:=Event: Did Wake}"
: "${ON_SLEEP_CMD:=$BT --disconnect $MAC}"
: "${ON_WAKE_CMD:=$BT --connect $MAC}"

# --- Main loop ------------------------------------------------------------
/usr/bin/log stream --predicate "$LOG_PREDICATE" --style compact 2>&1 | \
/usr/bin/awk \
    -v sleep_pat="$SLEEP_PATTERN" \
    -v wake_pat="$WAKE_PATTERN" \
    -v on_sleep="$ON_SLEEP_CMD" \
    -v on_wake="$ON_WAKE_CMD" \
    '
    $0 ~ sleep_pat { system(on_sleep) }
    $0 ~ wake_pat  { system(on_wake)  }
    '
