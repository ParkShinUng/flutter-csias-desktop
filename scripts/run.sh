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

# 환경 확인
if ! command -v flutter &> /dev/null; then
    print_error "Flutter가 설치되어 있지 않습니다."
    print_error "먼저 setup.sh를 실행해주세요."
    exit 1
fi

# Node.js 바이너리 확인
NODE_BINARY="$PROJECT_DIR/assets/bin/macos/node-darwin-x64-darwin-arm64"
if [ ! -f "$NODE_BINARY" ]; then
    print_warning "Node.js 바이너리가 없습니다. 환경을 구축합니다..."
    ./scripts/setup_env.sh
fi

# Runner node_modules 확인
if [ ! -d "$PROJECT_DIR/assets/runner/node_modules" ]; then
    print_warning "Runner 모듈이 없습니다. 환경을 구축합니다..."
    ./scripts/setup_env.sh
fi

# 실행 모드 확인
MODE="${1:-debug}"

if [[ "$MODE" == "release" ]]; then
    print_header "CSIAS Desktop 실행 (Release)"
    print_warning "릴리즈 모드로 빌드 중..."
    flutter build macos --release

    APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/csias_desktop.app"
    print_step "빌드 완료"
    print_warning "앱을 실행합니다..."
    open "$APP_PATH"
else
    print_header "CSIAS Desktop 실행 (Debug)"
    print_warning "디버그 모드로 실행 중..."
    flutter run -d macos
fi
