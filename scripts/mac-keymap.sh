#!/usr/bin/env bash
# Toggle a macOS-like keymap on Linux X11: swap Cmd/Ctrl, fix right Alt,
# and use Caps Lock + hjkl as arrow keys.
# Source: https://akuszyk.com/2023-02-19-xmodmap-for-mac.html
#
# Keycodes below assume a standard PC104/105 layout (left Ctrl=37,
# left/right Super=133/134, right Alt=108). If your keyboard differs,
# find the real keycodes with `xev` and adjust.

set -euo pipefail

ACTION="${1:-status}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mac-keymap"
BACKUP_FILE="$STATE_DIR/original.xmodmap"
MARKER="$STATE_DIR/enabled"

require_x11() {
    if ! command -v xmodmap >/dev/null 2>&1; then
        echo "xmodmap not found. Install: sudo apt install x11-xserver-utils" >&2
        exit 1
    fi
    if [[ -z "${DISPLAY:-}" ]]; then
        echo "No \$DISPLAY set — this only works in an X11 session (not Wayland-only, not a bare SSH session)." >&2
        exit 1
    fi
}

enable_keymap() {
    require_x11
    mkdir -p "$STATE_DIR"

    if [[ -f "$MARKER" ]]; then
        echo "mac-keymap already enabled."
        return 0
    fi

    xmodmap -pke > "$BACKUP_FILE"

    # 1. Swap Cmd <-> Ctrl
    xmodmap -e 'clear control'
    xmodmap -e 'clear mod4'
    xmodmap -e 'keycode 133 = Control_L NoSymbol Control_L'
    xmodmap -e 'keycode 134 = Control_R NoSymbol Control_R'
    xmodmap -e 'keycode 37  = Super_L NoSymbol Super_L'
    xmodmap -e 'add control = Control_L'
    xmodmap -e 'add control = Control_R'
    xmodmap -e 'add mod4 = Super_L'

    # 2. Right Alt breaks after the remap above; put it back
    xmodmap -e 'clear mod5'
    xmodmap -e 'keycode 108 = Alt_L NoSymbol Alt_L'

    # 3. Caps Lock as a modifier + hjkl as arrow keys while held
    xmodmap -e 'keycode 43 = h H Left h hstroke Hstroke hstroke'
    xmodmap -e 'keycode 44 = j J Down j dead_hook dead_horn dead_hook'
    xmodmap -e 'keycode 45 = k K Up k kra ampersand kra'
    xmodmap -e 'keycode 46 = l L Right l lstroke Lstroke lstroke'
    xmodmap -e 'keycode 66 = Mode_switch NoSymbol Caps_Lock'

    touch "$MARKER"
    echo "mac-keymap enabled."
}

disable_keymap() {
    require_x11

    if [[ ! -f "$MARKER" ]]; then
        echo "mac-keymap already disabled."
        return 0
    fi

    if [[ -f "$BACKUP_FILE" ]]; then
        xmodmap "$BACKUP_FILE"
    else
        echo "No backup found; falling back to setxkbmap reset (us layout)." >&2
        setxkbmap -layout us
    fi

    rm -f "$MARKER"
    echo "mac-keymap disabled."
}

status_keymap() {
    if [[ -f "$MARKER" ]]; then
        echo "mac-keymap: enabled"
    else
        echo "mac-keymap: disabled"
    fi
}

case "$ACTION" in
    on|enable)   enable_keymap ;;
    off|disable) disable_keymap ;;
    toggle)
        if [[ -f "$MARKER" ]]; then disable_keymap; else enable_keymap; fi
        ;;
    status) status_keymap ;;
    *)
        echo "Usage: $0 {on|off|toggle|status}" >&2
        exit 1
        ;;
esac
