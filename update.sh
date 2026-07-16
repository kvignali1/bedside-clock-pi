#!/bin/bash

set -euo pipefail

if [ "${BEDSIDE_UPDATE_RUNNER:-0}" != "1" ]; then
  REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
  TMP_SCRIPT="$(mktemp)"
  cp "$0" "$TMP_SCRIPT"
  chmod +x "$TMP_SCRIPT"
  BEDSIDE_REPO_DIR="$REPO_DIR" BEDSIDE_UPDATE_RUNNER=1 exec /bin/bash "$TMP_SCRIPT"
fi

echo "Updating Bedside Dashboard..."

REPO_DIR="${BEDSIDE_REPO_DIR:-$(cd "$(dirname "$0")" && pwd)}"
REBOOT_BIN="$(command -v reboot)"

cd "$REPO_DIR"

echo "Repo directory: $REPO_DIR"
echo "Pulling latest code..."

if ! git diff --quiet --ignore-submodules -- || ! git diff --cached --quiet --ignore-submodules --; then
  echo "Stashing local changes before pull..."
  git stash push -m "bedside auto-update $(date '+%Y-%m-%d %H:%M:%S')"
fi

git pull --ff-only

echo "Refreshing dependencies..."
SKIP_SYSTEM_SETUP=1 bash ./setup.sh

echo "Rebooting Pi..."
sudo -n "$REBOOT_BIN"

echo "Update complete!"
