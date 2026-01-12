#!/bin/bash

APP_NAME="csias_desktop"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/$APP_NAME.app"
DEST_PATH="/Applications/$APP_NAME.app"

echo ""
echo "========================================"
echo "  $APP_NAME 설치 프로그램"
echo "========================================"
echo ""

# Check if app exists in DMG
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 오류: $APP_NAME.app을 찾을 수 없습니다."
    echo "   DMG 파일을 먼저 열어주세요."
    echo ""
    read -p "아무 키나 누르면 종료합니다..."
    exit 1
fi

# Remove existing app if present
if [ -d "$DEST_PATH" ]; then
    echo "기존 버전을 삭제합니다..."
    rm -rf "$DEST_PATH"
fi

# Copy app to Applications
echo "Applications 폴더에 설치 중..."
cp -R "$APP_PATH" "$DEST_PATH"

# Remove quarantine attribute
echo "보안 속성 제거 중..."
xattr -cr "$DEST_PATH"

# Set execute permission for Node.js binary
NODE_BINARY="$DEST_PATH/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/bin/macos/node-darwin-x64-darwin-arm64"
if [ -f "$NODE_BINARY" ]; then
    echo "Node.js 바이너리 권한 설정 중..."
    chmod +x "$NODE_BINARY"
fi

echo ""
echo "========================================"
echo "  ✅ 설치 완료!"
echo "========================================"
echo ""

# Ask to launch
read -p "$APP_NAME을 실행하시겠습니까? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$DEST_PATH"
fi

echo ""
echo "이 창을 닫아도 됩니다."
