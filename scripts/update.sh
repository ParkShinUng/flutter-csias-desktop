#!/bin/bash

#===============================================================================
# CSIAS Desktop - 업데이트 스크립트
#
# Git에서 최신 소스를 가져오고 환경을 다시 구축합니다.
#
# 사용법:
#   ./scripts/update.sh
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

print_header "CSIAS Desktop 업데이트"

# 1. 현재 상태 확인
print_warning "현재 버전 확인 중..."
CURRENT_COMMIT=$(git rev-parse --short HEAD)
echo "현재 버전: $CURRENT_COMMIT"

# 2. 로컬 변경사항 확인
if [[ -n $(git status --porcelain) ]]; then
    print_warning "로컬에 변경된 파일이 있습니다:"
    git status --short
    echo ""
    read -p "변경사항을 무시하고 업데이트하시겠습니까? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "업데이트가 취소되었습니다."
        exit 1
    fi
    # 변경사항 되돌리기
    git checkout .
    git clean -fd
fi

# 3. 최신 소스 가져오기
print_warning "최신 소스를 가져옵니다..."
git fetch origin
git pull origin master

NEW_COMMIT=$(git rev-parse --short HEAD)
echo ""

if [[ "$CURRENT_COMMIT" == "$NEW_COMMIT" ]]; then
    print_step "이미 최신 버전입니다."
else
    print_step "업데이트 완료: $CURRENT_COMMIT → $NEW_COMMIT"

    # 4. 변경 로그 표시
    print_warning "변경 내역:"
    git log --oneline "$CURRENT_COMMIT..$NEW_COMMIT"
    echo ""
fi

# 5. 환경 다시 구축
print_warning "환경을 다시 구축합니다..."

# Flutter 패키지 업데이트
flutter pub get

# Runner 모듈 업데이트 (package.json이 변경된 경우)
cd "$PROJECT_DIR/assets/runner"
if command -v npm &> /dev/null; then
    npm install
fi
cd "$PROJECT_DIR"

print_step "환경 구축 완료"

# 완료
print_header "업데이트 완료!"

echo "최신 버전으로 업데이트되었습니다."
echo ""
echo "앱을 실행하려면:"
echo "  ./scripts/run.sh"
echo ""

# 바로 실행할지 물어보기
read -p "지금 CSIAS Desktop을 실행하시겠습니까? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/run.sh
fi
