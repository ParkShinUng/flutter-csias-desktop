#!/bin/bash

#===============================================================================
# CSIAS Desktop - 원클릭 설치 및 릴리스 빌드 스크립트
#
# 이 스크립트는 다음을 수행합니다:
#   1. 필요한 모든 도구 설치 (Homebrew, Flutter, Git, Node.js)
#   2. Git 저장소 클론 (~/Desktop/csias_desktop)
#   3. 실행 환경 구축 (Node.js 바이너리, npm 모듈)
#   4. Release 빌드 생성
#   5. 실행 가능한 앱을 Desktop에 복사
#
# 사용법:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ParkShinUng/flutter-csias-desktop/master/scripts/install_and_build.sh)"
#===============================================================================

set -e

APP_NAME="csias_desktop"
REPO_URL="https://github.com/ParkShinUng/flutter-csias-desktop.git"
INSTALL_DIR="$HOME/Desktop/$APP_NAME"
DESKTOP_DIR="$HOME/Desktop"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 시작
print_header "CSIAS Desktop 원클릭 설치 및 빌드"

echo "이 스크립트는 다음을 수행합니다:"
echo "  1. 필요한 도구 설치 (Homebrew, Flutter, Git, Node.js)"
echo "  2. 소스코드 다운로드"
echo "  3. 실행 환경 구축"
echo "  4. Release 빌드 생성"
echo "  5. 실행 가능한 앱을 Desktop에 복사"
echo ""
echo "설치 위치: $INSTALL_DIR"
echo "최종 앱 위치: $DESKTOP_DIR/$APP_NAME.app"
echo ""
read -p "계속하시겠습니까? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "설치가 취소되었습니다."
    exit 0
fi

#===============================================================================
# Phase 1: 필수 도구 설치
#===============================================================================

# 1. Homebrew 설치 확인
print_header "Phase 1: 필수 도구 설치 (1/4 - Homebrew)"

if command -v brew &> /dev/null; then
    print_step "Homebrew가 이미 설치되어 있습니다."
else
    print_warning "Homebrew를 설치합니다..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Apple Silicon Mac의 경우 PATH 설정
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    print_step "Homebrew 설치 완료"
fi

# 2. Git 설치 확인
print_header "Phase 1: 필수 도구 설치 (2/4 - Git)"

if command -v git &> /dev/null; then
    print_step "Git이 이미 설치되어 있습니다."
else
    print_warning "Git을 설치합니다..."
    brew install git
    print_step "Git 설치 완료"
fi

# 3. Flutter 설치 확인
print_header "Phase 1: 필수 도구 설치 (3/4 - Flutter SDK)"

if command -v flutter &> /dev/null; then
    print_step "Flutter가 이미 설치되어 있습니다."
    flutter --version
else
    print_warning "Flutter를 설치합니다... (시간이 걸릴 수 있습니다)"
    brew install --cask flutter

    # PATH에 Flutter 추가
    export PATH="$PATH:/opt/homebrew/Caskroom/flutter/*/flutter/bin"

    print_step "Flutter 설치 완료"

    # Flutter doctor 실행
    print_warning "Flutter 환경을 확인합니다..."
    flutter doctor -v || true
fi

# 4. Node.js 설치 확인
print_header "Phase 1: 필수 도구 설치 (4/4 - Node.js)"

if command -v node &> /dev/null; then
    print_step "Node.js가 이미 설치되어 있습니다."
    node --version
else
    print_warning "Node.js를 설치합니다..."
    brew install node
    print_step "Node.js 설치 완료"
fi

#===============================================================================
# Phase 2: 저장소 클론
#===============================================================================

print_header "Phase 2: 소스코드 다운로드"

if [ -d "$INSTALL_DIR" ]; then
    print_warning "기존 설치 폴더가 존재합니다: $INSTALL_DIR"
    read -p "삭제하고 새로 설치하시겠습니까? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
    else
        print_error "설치가 취소되었습니다."
        exit 1
    fi
fi

print_warning "저장소를 클론합니다..."
git clone "$REPO_URL" "$INSTALL_DIR"
print_step "소스코드 다운로드 완료"

cd "$INSTALL_DIR"

#===============================================================================
# Phase 3: 환경 구축
#===============================================================================

print_header "Phase 3: 실행 환경 구축 (1/3 - Flutter 패키지)"

print_warning "flutter pub get 실행 중..."
flutter pub get
print_step "Flutter 패키지 설치 완료"

print_header "Phase 3: 실행 환경 구축 (2/3 - Node.js 바이너리)"

NODE_DIR="$INSTALL_DIR/assets/bin/macos"
NODE_BINARY="$NODE_DIR/node-darwin-x64-darwin-arm64"
NODE_VERSION="v20.11.0"

# Windows 플레이스홀더 생성
WINDOWS_DIR="$INSTALL_DIR/assets/bin/windows"
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

    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    ARCH=$(uname -m)

    if [[ "$ARCH" == "arm64" ]]; then
        NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-darwin-arm64.tar.gz"
        print_warning "Apple Silicon용 Node.js 다운로드 중..."
    else
        NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-darwin-x64.tar.gz"
        print_warning "Intel Mac용 Node.js 다운로드 중..."
    fi

    curl -fsSL "$NODE_URL" -o node.tar.gz
    tar -xzf node.tar.gz

    NODE_EXTRACTED_DIR=$(ls -d node-*)
    cp "$NODE_EXTRACTED_DIR/bin/node" "$NODE_BINARY"
    chmod +x "$NODE_BINARY"

    cd "$INSTALL_DIR"
    rm -rf "$TEMP_DIR"

    print_step "Node.js 바이너리 다운로드 완료"
fi

print_header "Phase 3: 실행 환경 구축 (3/3 - Runner 모듈)"

RUNNER_DIR="$INSTALL_DIR/assets/runner"

if [ -d "$RUNNER_DIR/node_modules" ]; then
    print_step "Runner node_modules가 이미 존재합니다."
else
    print_warning "Runner 모듈을 설치합니다..."
    cd "$RUNNER_DIR"
    npm install
    print_step "Runner 모듈 설치 완료"
    cd "$INSTALL_DIR"
fi

#===============================================================================
# Phase 4: Release 빌드
#===============================================================================

print_header "Phase 4: Release 빌드"

cd "$INSTALL_DIR"

BUILD_DIR="$INSTALL_DIR/build/macos/Build/Products/Release"

print_warning "Flutter macOS release 빌드 중... (시간이 걸릴 수 있습니다)"
flutter build macos --release
print_step "Flutter 빌드 완료"

# Node.js 바이너리 권한 및 서명
print_warning "앱 서명 중..."

NODE_BINARY_IN_APP="$BUILD_DIR/$APP_NAME.app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/bin/macos/node-darwin-x64-darwin-arm64"
if [ -f "$NODE_BINARY_IN_APP" ]; then
    chmod +x "$NODE_BINARY_IN_APP"
    codesign --force --sign - "$NODE_BINARY_IN_APP"
fi

# 앱 전체 서명 (entitlements 적용)
ENTITLEMENTS="$INSTALL_DIR/macos/Runner/Release.entitlements"
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$BUILD_DIR/$APP_NAME.app"
print_step "앱 서명 완료"

#===============================================================================
# Phase 5: Desktop에 앱 복사
#===============================================================================

print_header "Phase 5: Desktop에 앱 복사"

# 기존 앱 제거
if [ -d "$DESKTOP_DIR/$APP_NAME.app" ]; then
    print_warning "기존 앱을 제거합니다..."
    rm -rf "$DESKTOP_DIR/$APP_NAME.app"
fi

# 앱 복사
print_warning "앱을 Desktop에 복사합니다..."
cp -R "$BUILD_DIR/$APP_NAME.app" "$DESKTOP_DIR/"

# Quarantine 속성 제거
xattr -cr "$DESKTOP_DIR/$APP_NAME.app"

print_step "앱 복사 완료"

#===============================================================================
# 완료
#===============================================================================

print_header "설치 및 빌드 완료!"

echo "CSIAS Desktop이 성공적으로 빌드되었습니다."
echo ""
echo -e "${GREEN}앱 위치:${NC} $DESKTOP_DIR/$APP_NAME.app"
echo -e "${GREEN}소스 위치:${NC} $INSTALL_DIR"
echo ""
echo -e "${YELLOW}실행 방법:${NC}"
echo "  1. Desktop에서 $APP_NAME.app을 더블클릭"
echo "  2. 또는 터미널에서: open \"$DESKTOP_DIR/$APP_NAME.app\""
echo ""
echo -e "${YELLOW}개발 모드 실행:${NC}"
echo "  cd $INSTALL_DIR && ./scripts/run.sh"
echo ""

# 바로 실행할지 물어보기
read -p "지금 CSIAS Desktop을 실행하시겠습니까? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$DESKTOP_DIR/$APP_NAME.app"
fi
