#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="RDPConnect"
APP_DIR="$APP_NAME.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp Info.plist "$APP_DIR/Contents/Info.plist"

swiftc -O \
    -o "$APP_DIR/Contents/MacOS/$APP_NAME" \
    Sources/*.swift

echo "Built $APP_DIR"
