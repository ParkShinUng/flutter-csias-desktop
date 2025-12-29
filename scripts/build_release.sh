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

# 2. Code Sign
echo ""
echo "[2/5] Signing application..."
codesign --force --deep --sign - "$BUILD_DIR/$APP_NAME.app"

# 3. Prepare DMG staging folder
echo ""
echo "[3/5] Preparing DMG contents..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy app
cp -R "$BUILD_DIR/$APP_NAME.app" "$DMG_STAGING/"

# Copy and prepare installer script
cp "$INSTALLER_SCRIPT" "$DMG_STAGING/설치.command"
chmod +x "$DMG_STAGING/설치.command"

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
echo "1. DMG 파일 열기"
echo "2. '설치.command' 우클릭 → '열기' 선택"
echo "3. 경고창에서 '열기' 클릭"
echo "4. 터미널이 열리면 자동 설치 진행"
echo ""
echo "※ 보안 경고가 나타나면 우클릭으로 열어야 합니다"
echo "----------------------------------------"
