#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="bedside.service"
SERVICE_TARGET="/etc/systemd/system/$SERVICE_NAME"
SUDOERS_TARGET="/etc/sudoers.d/bedside-clock"
VENV_DIR="$REPO_DIR/.venv"
SERVICE_USER="${SUDO_USER:-${USER:-}}"
CHROMIUM_BIN=""
SYSTEMCTL_BIN="$(command -v systemctl)"
TEE_BIN="$(command -v tee)"
REBOOT_BIN="$(command -v reboot)"
SKIP_SYSTEM_SETUP="${SKIP_SYSTEM_SETUP:-0}"
BACKLIGHT_DIR="$(find /sys/class/backlight -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1 || true)"
BACKLIGHT_BRIGHTNESS_FILE=""

if [ "$SERVICE_USER" = "root" ]; then
  SERVICE_USER="$(logname 2>/dev/null || echo pi)"
fi

if [ -z "$SERVICE_USER" ]; then
  SERVICE_USER="$(id -un)"
fi

AUTOSTART_DIR="/home/$SERVICE_USER/.config/autostart"
KIOSK_DESKTOP_FILE="$AUTOSTART_DIR/bedside-kiosk.desktop"

if [ -n "$BACKLIGHT_DIR" ]; then
  BACKLIGHT_BRIGHTNESS_FILE="$BACKLIGHT_DIR/brightness"
  printf '%s\n' "$BACKLIGHT_BRIGHTNESS_FILE" > "$REPO_DIR/.backlight_tee_path"
fi

echo "Setting up Bedside Clock..."

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not installed."
  exit 1
fi

if ! python3 -m venv "$VENV_DIR" >/dev/null 2>&1; then
  echo "python3-venv is required but not installed."
  echo "Install it with: sudo apt-get install python3-venv"
  exit 1
fi

if command -v chromium-browser >/dev/null 2>&1; then
  CHROMIUM_BIN="$(command -v chromium-browser)"
elif command -v chromium >/dev/null 2>&1; then
  CHROMIUM_BIN="$(command -v chromium)"
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel
"$VENV_DIR/bin/pip" install --prefer-binary -r "$REPO_DIR/requirements.txt"
chmod +x "$REPO_DIR/kiosk.sh" "$REPO_DIR/display_manager.sh"

if [ "$SKIP_SYSTEM_SETUP" != "1" ]; then
  sudo tee "$SUDOERS_TARGET" >/dev/null <<EOF
$SERVICE_USER ALL=(root) NOPASSWD: $TEE_BIN $SERVICE_TARGET
$SERVICE_USER ALL=(root) NOPASSWD: $SYSTEMCTL_BIN daemon-reload
$SERVICE_USER ALL=(root) NOPASSWD: $SYSTEMCTL_BIN enable $SERVICE_NAME
$SERVICE_USER ALL=(root) NOPASSWD: $SYSTEMCTL_BIN restart $SERVICE_NAME
$SERVICE_USER ALL=(root) NOPASSWD: $REBOOT_BIN
EOF
  if [ -n "$BACKLIGHT_BRIGHTNESS_FILE" ]; then
    printf '%s ALL=(root) NOPASSWD: %s %s\n' "$SERVICE_USER" "$TEE_BIN" "$BACKLIGHT_BRIGHTNESS_FILE" | sudo tee -a "$SUDOERS_TARGET" >/dev/null
  fi
  sudo chmod 0440 "$SUDOERS_TARGET"

  sudo tee "$SERVICE_TARGET" >/dev/null <<EOF
[Unit]
Description=Bedside Clock Backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$REPO_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=-$REPO_DIR/.env
ExecStart=$VENV_DIR/bin/python $REPO_DIR/backend/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable "$SERVICE_NAME"
  sudo systemctl restart "$SERVICE_NAME"

  if [ -n "$CHROMIUM_BIN" ]; then
    mkdir -p "$AUTOSTART_DIR"
    cat > "$KIOSK_DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Bedside Clock Kiosk
Exec=/bin/bash $REPO_DIR/kiosk.sh $CHROMIUM_BIN
X-GNOME-Autostart-enabled=true
EOF
    echo "Kiosk autostart installed for $CHROMIUM_BIN."
  else
    echo "Chromium not found; skipping kiosk autostart."
    echo "Install chromium-browser or chromium if you want automatic kiosk mode."
  fi
fi

echo "Setup complete."
echo "The backend is available at http://localhost:5000/ on the Pi."
