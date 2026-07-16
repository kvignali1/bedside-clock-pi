#!/bin/bash

set -euo pipefail

echo "Updating Bedside Dashboard..."

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

git pull --ff-only
SKIP_SYSTEM_SETUP=1 bash ./setup.sh
sudo -n reboot

echo "Update complete!"
