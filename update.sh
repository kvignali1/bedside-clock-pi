#!/bin/bash

set -e

echo "Updating Bedside Dashboard..."

cd /home/pi/bedside-dashboard

git pull --ff-only

sudo systemctl restart bedside-dashboard

echo "Update complete!"