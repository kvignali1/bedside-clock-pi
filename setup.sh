#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="bedside.service"
SERVICE_TARGET="/etc/systemd/system/$SERVICE_NAME"
VENV_DIR="$REPO_DIR/.venv"
SERVICE_USER="${SUDO_USER:-$USER}"

if [ "$SERVICE_USER" = "root" ]; then
  SERVICE_USER="$(logname 2>/dev/null || echo pi)"
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

"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install -r "$REPO_DIR/requirements.txt"

sudo tee "$SERVICE_TARGET" >/dev/null <<EOF
[Unit]
Description=Bedside Clock Backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$REPO_DIR
Environment=PYTHONUNBUFFERED=1
ExecStart=$VENV_DIR/bin/python $REPO_DIR/backend/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo "Setup complete."
echo "The backend is available at http://localhost:5000/ on the Pi."
