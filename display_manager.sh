#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="/tmp/bedside-brightness-state"
DISPLAY_NAME="${DISPLAY:-:0}"
BACKLIGHT_DIR="$(find /sys/class/backlight -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1 || true)"
BACKLIGHT_BRIGHTNESS_FILE=""
BACKLIGHT_MAX_FILE=""
BACKLIGHT_TEE_RULE=""

if [ -n "$BACKLIGHT_DIR" ]; then
  BACKLIGHT_BRIGHTNESS_FILE="$BACKLIGHT_DIR/brightness"
  BACKLIGHT_MAX_FILE="$BACKLIGHT_DIR/max_brightness"
  BACKLIGHT_TEE_RULE="$(cat "$REPO_DIR/.backlight_tee_path" 2>/dev/null || true)"
fi

get_connected_output() {
  xrandr --current 2>/dev/null | awk '/ connected/{print $1; exit}'
}

set_x11_brightness() {
  local level="$1"
  local output
  output="$(get_connected_output)"
  if [ -n "$output" ]; then
    xrandr --output "$output" --brightness "$level" >/dev/null 2>&1 || true
  fi
}

set_backlight_brightness() {
  local percent="$1"
  if [ -z "$BACKLIGHT_BRIGHTNESS_FILE" ] || [ -z "$BACKLIGHT_MAX_FILE" ]; then
    return 1
  fi

  local max_value target
  max_value="$(cat "$BACKLIGHT_MAX_FILE")"
  target=$(( max_value * percent / 100 ))
  if [ "$target" -lt 1 ]; then
    target=1
  fi

  if [ -w "$BACKLIGHT_BRIGHTNESS_FILE" ]; then
    printf '%s\n' "$target" > "$BACKLIGHT_BRIGHTNESS_FILE"
    return 0
  fi

  if [ -n "$BACKLIGHT_TEE_RULE" ]; then
    printf '%s\n' "$target" | sudo -n tee "$BACKLIGHT_BRIGHTNESS_FILE" >/dev/null
    return 0
  fi

  return 1
}

apply_brightness() {
  local mode="$1"
  case "$mode" in
    sleep)
      set_backlight_brightness 5 || set_x11_brightness 0.05
      ;;
    dim)
      set_backlight_brightness 50 || set_x11_brightness 0.5
      ;;
    awake)
      set_backlight_brightness 100 || set_x11_brightness 1.0
      ;;
  esac
}

current_mode() {
  local weekday hhmm tomorrow
  weekday="$(date +%u)"
  hhmm=$((10#$(date +%H%M)))
  tomorrow=$(( weekday % 7 + 1 ))

  if [ "$hhmm" -le 100 ] && [[ "$weekday" =~ ^(7|1|2|3)$ ]]; then
    echo "sleep"
    return
  fi

  if [ "$hhmm" -ge 1930 ] && [[ "$tomorrow" =~ ^(7|1|2|3)$ ]]; then
    echo "sleep"
    return
  fi

  if [ "$hhmm" -ge 1900 ] && [ "$hhmm" -lt 1930 ] && [[ "$tomorrow" =~ ^(7|1|2|3)$ ]]; then
    echo "dim"
    return
  fi

  echo "awake"
}

while true; do
  mode="$(current_mode)"
  last_mode="$(cat "$STATE_FILE" 2>/dev/null || true)"

  xset s off >/dev/null 2>&1 || true
  xset -dpms >/dev/null 2>&1 || true
  xset s noblank >/dev/null 2>&1 || true

  if [ "$mode" != "$last_mode" ]; then
    apply_brightness "$mode"
    printf '%s\n' "$mode" > "$STATE_FILE"
  fi

  sleep 30
done
