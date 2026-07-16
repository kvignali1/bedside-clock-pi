#!/bin/bash

set -euo pipefail

REPO_DIR="/home/pi/Bedside_clock_pi"
SERVICE_NAME="bedside.service"
SERVICE_SOURCE="$REPO_DIR/$SERVICE_NAME"
SERVICE_TARGET="/etc/systemd/system/$SERVICE_NAME"
VENV_DIR="$REPO_DIR/.venv"

echo "Setting up Bedside Clock..."

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not installed."
  exit 1
fi

if ! command -v pip3 >/dev/null 2>&1; then
  echo "pip3 is required but not installed."
  exit 1
fi

if [ ! -d "$REPO_DIR" ]; then
  echo "Repository not found at $REPO_DIR"
  exit 1
fi

python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install -r "$REPO_DIR/requirements.txt"

if [ ! -f "$SERVICE_SOURCE" ]; then
  echo "Service file not found at $SERVICE_SOURCE"
  exit 1
fi

sudo cp "$SERVICE_SOURCE" "$SERVICE_TARGET"
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo "Setup complete."
