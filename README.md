# CSIAS Desktop

**Chainshift Integrated Automation System** - Tistory 블로그 포스팅 자동화 데스크탑 애플리케이션

## 주요 기능

- HTML 파일을 Tistory 블로그에 자동 포스팅
- 다중 파일 일괄 업로드 지원
- 파일별 태그 설정 (쉼표 구분, 최대 10개)
- 태그 중복 검사 및 시각적 표시
- Kakao 계정 로그인 자동화
- 로그인 세션 저장 (재로그인 불필요)

## 시스템 요구사항

- macOS 10.15 이상
- Google Chrome 브라우저 설치 필요

## 설치 방법

### 원클릭 설치 (권장)

터미널에서 아래 명령어를 실행하면 모든 것이 자동으로 설치됩니다:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ParkShinUng/flutter-csias-desktop/master/scripts/setup.sh)"
```

설치되는 항목:
- Homebrew (패키지 관리자)
- Flutter SDK
- Node.js
- CSIAS Desktop 소스코드 및 의존성

설치 위치: `~/Applications/csias_desktop`

### 설치 후 사용

```bash
# 앱 실행
cd ~/Applications/csias_desktop
./scripts/run.sh

# 업데이트 (최신 버전으로)
./scripts/update.sh
```

### 개발자 빌드

```bash
# 저장소 클론
git clone https://github.com/ParkShinUng/flutter-csias-desktop.git
cd flutter-csias-desktop

# 환경 구축 (Node.js 바이너리, npm 모듈 설치)
./scripts/setup_env.sh

# 개발 모드 실행
./scripts/run.sh

# 릴리즈 빌드 및 DMG 생성
./scripts/build_release.sh
```

## 사용 방법

1. **계정 정보 입력**
   - Kakao ID, 비밀번호, 블로그 이름 입력

2. **HTML 파일 추가**
   - 파일을 드래그 앤 드롭하거나 클릭하여 선택
   - `.html`, `.htm` 파일만 지원

3. **태그 입력**
   - 각 파일별로 태그 입력 (쉼표로 구분)
   - 예: `뷰티, 맛집, 서울`

4. **포스팅 시작**
   - "포스팅 시작" 버튼 클릭
   - 자동으로 Tistory에 로그인 후 포스팅 진행

## 프로젝트 구조

```
csias_desktop/
├── lib/
│   ├── app/                    # 앱 설정, 라우터
│   ├── core/                   # 공통 모듈
│   │   ├── runner/             # Node.js 프로세스 관리
│   │   ├── theme/              # 앱 테마
│   │   ├── ui/                 # 공통 UI 컴포넌트
│   │   └── widgets/            # 공통 위젯
│   └── features/
│       └── tistory_posting/    # Tistory 포스팅 기능
│           ├── domain/         # 모델
│           └── presentation/   # UI, 상태 관리
├── assets/
│   └── runner/                 # Node.js 자동화 스크립트
│       └── runner.js           # Playwright 기반 자동화
├── scripts/
│   ├── build_release.sh        # 릴리즈 빌드 스크립트
│   └── installer/              # 설치 스크립트
└── macos/                      # macOS 네이티브 설정
```

## 기술 스택

- **Frontend**: Flutter (Dart)
- **State Management**: Riverpod
- **Automation**: Node.js + Playwright
- **IPC**: JSON-line 프로토콜 (stdin/stdout)

## 빌드 스크립트

```bash
# 릴리즈 빌드 + DMG 생성
./scripts/build_release.sh
```

출력: `dist/csias_desktop.dmg`

## 라이선스

Private - All rights reserved
