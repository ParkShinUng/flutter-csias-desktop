#!/bin/bash

set -e

APP_NAME="csias_desktop"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/macos/Build/Products/Release"
OUTPUT_DIR="$PROJECT_DIR/dist"
DMG_STAGING="$PROJECT_DIR/build/dmg_staging"
INSTALLER_SCRIPT="$PROJECT_DIR/scripts/installer/install.command"

echo "========================================"
echo "  $APP_NAME Release Build Script"
echo "========================================"

# 1. Clean & Build
echo ""
echo "[1/5] Building Flutter macOS release..."
cd "$PROJECT_DIR"
flutter build macos --release

# 2. Fix permissions and Code Sign
echo ""
echo "[2/5] Fixing permissions and signing application..."

# Node.js 바이너리에 실행 권한 부여
NODE_BINARY="$BUILD_DIR/$APP_NAME.app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/bin/macos/node-darwin-x64-darwin-arm64"
if [ -f "$NODE_BINARY" ]; then
    echo "  - Setting execute permission for Node.js binary..."
    chmod +x "$NODE_BINARY"
    echo "  - Signing Node.js binary..."
    codesign --force --sign - "$NODE_BINARY"
fi

# 앱 전체 서명 (entitlements 적용)
echo "  - Signing application bundle with entitlements..."
ENTITLEMENTS="$PROJECT_DIR/macos/Runner/Release.entitlements"
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$BUILD_DIR/$APP_NAME.app"

# 3. Prepare DMG staging folder
echo ""
echo "[3/5] Preparing DMG contents..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy app
cp -R "$BUILD_DIR/$APP_NAME.app" "$DMG_STAGING/"

# Create Applications symlink for drag-and-drop install
ln -s /Applications "$DMG_STAGING/Applications"

# Remove quarantine attributes from all files
xattr -cr "$DMG_STAGING"

# 4. Create output directory
echo ""
echo "[4/5] Creating output directory..."
mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/$APP_NAME.dmg"

# 5. Create DMG
echo ""
echo "[5/5] Creating DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$OUTPUT_DIR/$APP_NAME.dmg"

# Cleanup
rm -rf "$DMG_STAGING"

# Done
echo ""
echo "========================================"
echo "  Build Complete!"
echo "========================================"
echo ""
echo "Output: $OUTPUT_DIR/$APP_NAME.dmg"
echo ""
echo "사용자 안내문:"
echo "----------------------------------------"
echo "1. 터미널에서 아래 명령어 실행:"
echo ""
echo "   xattr -cr ~/Downloads/$APP_NAME.dmg && open ~/Downloads/$APP_NAME.dmg"
echo ""
echo "2. DMG가 열리면 앱을 Applications 폴더로 드래그"
echo "3. 앱 첫 실행 시 우클릭 → '열기' 선택"
echo "----------------------------------------"
