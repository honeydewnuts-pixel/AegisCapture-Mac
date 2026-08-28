#!/usr/bin/env bash
# Build AEGIS Capture DMG on macOS (requires Xcode / Swift toolchain).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
APP_NAME="AEGIS_Capture"
VERSION="1.0.0"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RES"

echo "==> Compiling Swift sources…"
swiftc -O \
  -framework SwiftUI -framework AppKit -framework Foundation -framework ScreenCaptureKit -framework CoreMedia \
  AegisCaptureApp.swift ContentView.swift config.swift CaptureService.swift TradeBridge.swift \
  -o "$MACOS/$APP_NAME"

cp Info.plist "$CONTENTS/Info.plist"
cp Resources/mt5_color_match_guide.jpg "$RES/" 2>/dev/null || true
cp guides/mt5_color_match_guide.jpg "$RES/" 2>/dev/null || true
cp mq5/AEGIS_Executor.mq5 "$RES/" 2>/dev/null || true

chmod +x "$MACOS/$APP_NAME"

DMG_NAME="AEGIS_Capture_v${VERSION}.dmg"
rm -f "$ROOT/$DMG_NAME"
hdiutil create -volname "AEGIS Capture" -srcfolder "$APP_DIR" -ov -format UDZO "$ROOT/$DMG_NAME"
echo "==> Built $ROOT/$DMG_NAME"
ls -lh "$ROOT/$DMG_NAME"
