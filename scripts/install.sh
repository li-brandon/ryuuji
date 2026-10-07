#!/bin/sh
# Builds a Release copy of Ryuuji and installs it to /Applications.
set -eu

cd "$(dirname "$0")/.."
xcodebuild -project Ryuuji.xcodeproj -scheme Ryuuji -configuration Release -derivedDataPath build build
osascript -e 'quit app "Ryuuji"' 2>/dev/null || true
rm -rf /Applications/Ryuuji.app
cp -R build/Build/Products/Release/Ryuuji.app /Applications/
open /Applications/Ryuuji.app
