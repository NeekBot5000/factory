#!/usr/bin/env bash
# Uploads a new version to itch.io with butler (itch's own upload tool), once the page exists.
#   1. Install butler: https://itch.io/docs/butler/   then run:  butler login
#   2. Download the "Timber-itch" artifact from the latest green GitHub Actions run and unzip it somewhere.
#   3. tools/push_itch.sh <your-itch-username> <folder-with-the-three-zips>
# Each zip goes to its own channel (web, windows, linux). itch tags the Windows and Linux uploads from the channel
# names; the web one you mark once on the edit page ("This file will be played in the browser"). butler only uploads
# what changed. The version shown on itch is read from project.godot.
# Note: uploads made by hand on the website aren't channels - if you started that way, delete them once you switch.
set -euo pipefail
USER_NAME=${1:?"usage: tools/push_itch.sh <itch-username> <folder with Timber-*.zip>"}
DIR=${2:?"usage: tools/push_itch.sh <itch-username> <folder with Timber-*.zip>"}
VERSION=$(grep -m1 '^config/version=' "$(dirname "$0")/../project.godot" | cut -d'"' -f2)
for p in web windows linux; do
  butler push "$DIR/Timber-$p.zip" "$USER_NAME/timber:$p" --userversion "$VERSION"
done
