#!/bin/bash
# Builds UVCMirror.app from the Swift package sources.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="UVCMirror.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/UVCMirror" "$APP/Contents/MacOS/UVCMirror"
cp "Info.plist" "$APP/Contents/Info.plist"

codesign --force --deep --sign - "$APP"

echo "Built $APP"
