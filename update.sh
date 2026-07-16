#!/bin/bash

set -euo pipefail

echo "Updating Bedside Dashboard..."

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
REBOOT_BIN="$(command -v reboot)"

cd "$REPO_DIR"

echo "Repo directory: $REPO_DIR"
echo "Pulling latest code..."
git pull --ff-only

echo "Refreshing dependencies..."
SKIP_SYSTEM_SETUP=1 bash ./setup.sh

echo "Rebooting Pi..."
sudo -n "$REBOOT_BIN"

echo "Update complete!"
