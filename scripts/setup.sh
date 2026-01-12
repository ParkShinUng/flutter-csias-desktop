#!/bin/bash

#===============================================================================
# CSIAS Desktop - 초기 설치 스크립트
#
# 이 스크립트는 CSIAS Desktop을 처음 설치할 때 실행합니다.
# Homebrew, Flutter, Git을 설치하고 저장소를 클론합니다.
#
# 사용법:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ParkShinUng/flutter-csias-desktop/master/scripts/setup.sh)"
#===============================================================================

set -e

APP_NAME="csias_desktop"
REPO_URL="https://github.com/ParkShinUng/flutter-csias-desktop.git"
INSTALL_DIR="$HOME/Applications/$APP_NAME"

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
print_header "CSIAS Desktop 설치 프로그램"

echo "이 스크립트는 다음을 설치합니다:"
echo "  - Homebrew (패키지 관리자)"
echo "  - Flutter SDK (앱 빌드 도구)"
echo "  - Node.js (자동화 스크립트용)"
echo "  - CSIAS Desktop 소스코드"
echo ""
read -p "계속하시겠습니까? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "설치가 취소되었습니다."
    exit 0
fi

# 1. Homebrew 설치 확인
print_header "1/5 - Homebrew 확인"

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
print_header "2/5 - Git 확인"

if command -v git &> /dev/null; then
    print_step "Git이 이미 설치되어 있습니다."
else
    print_warning "Git을 설치합니다..."
    brew install git
    print_step "Git 설치 완료"
fi

# 3. Flutter 설치 확인
print_header "3/5 - Flutter SDK 확인"

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

# 4. Node.js 설치 확인 (npm 사용을 위해)
print_header "4/5 - Node.js 확인"

if command -v node &> /dev/null; then
    print_step "Node.js가 이미 설치되어 있습니다."
    node --version
else
    print_warning "Node.js를 설치합니다..."
    brew install node
    print_step "Node.js 설치 완료"
fi

# 5. 저장소 클론
print_header "5/5 - CSIAS Desktop 다운로드"

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

# 6. 환경 구축 스크립트 실행
print_header "환경 구축"

cd "$INSTALL_DIR"
chmod +x scripts/setup_env.sh
./scripts/setup_env.sh

# 완료
print_header "설치 완료!"

echo "CSIAS Desktop이 설치되었습니다."
echo ""
echo "설치 위치: $INSTALL_DIR"
echo ""
echo -e "${GREEN}사용 방법:${NC}"
echo "  앱 실행:    cd $INSTALL_DIR && ./scripts/run.sh"
echo "  업데이트:   cd $INSTALL_DIR && ./scripts/update.sh"
echo ""
echo -e "${YELLOW}팁: 터미널에서 빠르게 실행하려면 alias를 추가하세요:${NC}"
echo "  echo 'alias csias=\"cd $INSTALL_DIR && ./scripts/run.sh\"' >> ~/.zshrc"
echo "  source ~/.zshrc"
echo "  csias  # 이제 이 명령어로 실행 가능"
echo ""

# 바로 실행할지 물어보기
read -p "지금 CSIAS Desktop을 실행하시겠습니까? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/run.sh
fi
