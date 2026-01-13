#!/bin/bash

#===============================================================================
# CSIAS Desktop - 실행 스크립트
#
# 앱을 빌드하고 실행합니다.
#
# 사용법:
#   ./scripts/run.sh          # 디버그 모드로 실행
#   ./scripts/run.sh release  # 릴리즈 모드로 실행
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

cd "$PROJECT_DIR"

# Flutter 확인
if ! command -v flutter &> /dev/null; then
    print_error "Flutter가 설치되어 있지 않습니다."
    print_error "먼저 install_and_build.sh를 실행해주세요."
    exit 1
fi

# Node.js 바이너리 확인 및 설치
NODE_DIR="$PROJECT_DIR/assets/bin/macos"
NODE_BINARY="$NODE_DIR/node-darwin-x64-darwin-arm64"
NODE_VERSION="v20.11.0"

if [ ! -f "$NODE_BINARY" ]; then
    print_warning "Node.js 바이너리가 없습니다. 다운로드합니다..."

    mkdir -p "$NODE_DIR"
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-darwin-arm64.tar.gz"
    else
        NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-darwin-x64.tar.gz"
    fi

    curl -fsSL "$NODE_URL" -o node.tar.gz
    tar -xzf node.tar.gz
    NODE_EXTRACTED_DIR=$(ls -d node-*)
    cp "$NODE_EXTRACTED_DIR/bin/node" "$NODE_BINARY"
    chmod +x "$NODE_BINARY"

    cd "$PROJECT_DIR"
    rm -rf "$TEMP_DIR"

    print_step "Node.js 바이너리 다운로드 완료"
fi

# Windows 플레이스홀더 확인
WINDOWS_DIR="$PROJECT_DIR/assets/bin/windows"
if [ ! -f "$WINDOWS_DIR/node.exe" ]; then
    mkdir -p "$WINDOWS_DIR"
    touch "$WINDOWS_DIR/node.exe"
fi

# Runner node_modules 확인 및 설치
RUNNER_DIR="$PROJECT_DIR/assets/runner"
if [ ! -d "$RUNNER_DIR/node_modules" ]; then
    print_warning "Runner 모듈이 없습니다. 설치합니다..."

    if ! command -v npm &> /dev/null; then
        print_error "npm이 설치되어 있지 않습니다."
        print_error "Node.js를 먼저 설치해주세요: brew install node"
        exit 1
    fi

    cd "$RUNNER_DIR"
    npm install
    cd "$PROJECT_DIR"

    print_step "Runner 모듈 설치 완료"
fi

# 실행 모드 확인
MODE="${1:-debug}"

if [[ "$MODE" == "release" ]]; then
    print_header "CSIAS Desktop 실행 (Release)"
    print_warning "릴리즈 모드로 빌드 중..."
    flutter build macos --release

    # 서명
    BUILD_DIR="$PROJECT_DIR/build/macos/Build/Products/Release"
    ENTITLEMENTS="$PROJECT_DIR/macos/Runner/Release.entitlements"
    NODE_BINARY_IN_APP="$BUILD_DIR/csias_desktop.app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/bin/macos/node-darwin-x64-darwin-arm64"

    if [ -f "$NODE_BINARY_IN_APP" ]; then
        chmod +x "$NODE_BINARY_IN_APP"
        codesign --force --sign - "$NODE_BINARY_IN_APP"
    fi
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$BUILD_DIR/csias_desktop.app"

    APP_PATH="$BUILD_DIR/csias_desktop.app"
    print_step "빌드 완료"
    print_warning "앱을 실행합니다..."
    open "$APP_PATH"
else
    print_header "CSIAS Desktop 실행 (Debug)"
    print_warning "디버그 모드로 실행 중..."
    flutter run -d macos
fi
