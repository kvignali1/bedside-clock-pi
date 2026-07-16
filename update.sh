#!/bin/bash

set -euo pipefail

echo "Updating Bedside Dashboard..."

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

git pull --ff-only
./setup.sh
sudo systemctl restart bedside.service

echo "Update complete!"
