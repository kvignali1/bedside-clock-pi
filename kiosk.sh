#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROMIUM_BIN="${1:-chromium-browser}"

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/home/$(id -un)/.Xauthority}"

xset s off
xset -dpms
xset s noblank

/bin/bash "$REPO_DIR/display_manager.sh" >/tmp/bedside-display.log 2>&1 &

exec "$CHROMIUM_BIN" --kiosk --noerrdialogs --disable-infobars --incognito --overscroll-history-navigation=0 http://localhost:5000/
