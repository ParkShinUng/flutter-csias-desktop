#!/bin/bash

#===============================================================================
# CSIAS Desktop - 실행 환경 구축 스크립트
#
# Git에 포함되지 않은 파일들을 다운로드/설치합니다:
#   - Node.js 바이너리 (macOS universal)
#   - Runner node_modules (Playwright, cheerio)
#   - Flutter 패키지
#
# 사용법:
#   ./scripts/setup_env.sh
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

print_header "CSIAS Desktop 환경 구축"

# 1. Flutter 패키지 설치
print_header "1/4 - Flutter 패키지 설치"

if command -v flutter &> /dev/null; then
    print_warning "flutter pub get 실행 중..."
    flutter pub get
    print_step "Flutter 패키지 설치 완료"
else
    print_error "Flutter가 설치되어 있지 않습니다."
    print_error "먼저 setup.sh를 실행해주세요."
    exit 1
fi

# 2. Node.js 바이너리 다운로드 (macOS용)
print_header "2/4 - Node.js 바이너리 다운로드"

NODE_DIR="$PROJECT_DIR/assets/bin/macos"
NODE_BINARY="$NODE_DIR/node-darwin-x64-darwin-arm64"
NODE_VERSION="v20.11.0"

# Windows 플레이스홀더 생성 (Flutter 빌드 오류 방지)
WINDOWS_DIR="$PROJECT_DIR/assets/bin/windows"
mkdir -p "$WINDOWS_DIR"
if [ ! -f "$WINDOWS_DIR/node.exe" ]; then
    touch "$WINDOWS_DIR/node.exe"
    print_step "Windows 플레이스홀더 생성"
fi

mkdir -p "$NODE_DIR"

if [ -f "$NODE_BINARY" ]; then
    print_step "Node.js 바이너리가 이미 존재합니다."
else
    print_warning "Node.js 바이너리를 다운로드합니다..."

    # 임시 디렉토리 생성
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # 현재 아키텍처 확인
    ARCH=$(uname -m)

    if [[ "$ARCH" == "arm64" ]]; then
        # Apple Silicon
        NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-darwin-arm64.tar.gz"
        print_warning "Apple Silicon용 Node.js 다운로드 중..."
    else
        # Intel
        NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-darwin-x64.tar.gz"
        print_warning "Intel Mac용 Node.js 다운로드 중..."
    fi

    curl -fsSL "$NODE_URL" -o node.tar.gz
    tar -xzf node.tar.gz

    # node 바이너리 복사
    NODE_EXTRACTED_DIR=$(ls -d node-*)
    cp "$NODE_EXTRACTED_DIR/bin/node" "$NODE_BINARY"
    chmod +x "$NODE_BINARY"

    # 정리
    cd "$PROJECT_DIR"
    rm -rf "$TEMP_DIR"

    print_step "Node.js 바이너리 다운로드 완료"
fi

# 3. Runner node_modules 설치
print_header "3/4 - Runner 모듈 설치"

RUNNER_DIR="$PROJECT_DIR/assets/runner"

if [ -d "$RUNNER_DIR/node_modules" ]; then
    print_step "Runner node_modules가 이미 존재합니다."
else
    print_warning "Runner 모듈을 설치합니다..."
    cd "$RUNNER_DIR"

    if command -v npm &> /dev/null; then
        npm install
        print_step "Runner 모듈 설치 완료"
    else
        print_error "npm이 설치되어 있지 않습니다."
        print_error "Node.js를 먼저 설치해주세요: brew install node"
        exit 1
    fi

    cd "$PROJECT_DIR"
fi

# 4. Playwright 브라우저 설치 (선택사항 - Chrome 사용 권장)
print_header "4/4 - 브라우저 확인"

CHROME_PATH="/Applications/Google Chrome.app"
if [ -d "$CHROME_PATH" ]; then
    print_step "Google Chrome이 설치되어 있습니다."
else
    print_warning "Google Chrome이 설치되어 있지 않습니다."
    print_warning "앱 실행을 위해 Chrome 설치를 권장합니다."
    print_warning "https://www.google.com/chrome/"
fi

# 완료
print_header "환경 구축 완료!"

echo "모든 환경이 준비되었습니다."
echo ""
echo "앱을 실행하려면:"
echo "  ./scripts/run.sh"
echo ""
