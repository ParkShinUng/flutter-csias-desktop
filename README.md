# CSIAS Desktop

**Chainshift Integrated Automation System** - Tistory 블로그 포스팅 자동화 및 Google 색인 관리 데스크탑 애플리케이션

## 주요 기능

### Tistory 자동 포스팅
- HTML 파일을 Tistory 블로그에 자동 포스팅
- 다중 파일 일괄 업로드 지원
- 파일별 태그 설정 (쉼표 구분, 최대 10개)
- 태그 중복 검사 및 시각적 표시
- Kakao 계정 로그인 자동화
- 로그인 세션 저장 (재로그인 불필요)

### Google 색인 관리
- **Sitemap 기반 URL 추출**: 블로그 sitemap에서 URL 자동 수집
- **URL Inspection API**: OAuth 2.0 인증으로 색인 상태 확인
- **Live URL Test**: 실시간 크롤링으로 현재 색인 상태 검사
- **Indexing API**: 서비스 계정으로 색인 요청 자동화
- **모바일 URL 필터링**: `/m/` 경로 URL 자동 제외
- **일일 할당량 관리**: API 사용량 추적 및 표시

## 시스템 요구사항

- macOS 10.15 이상
- Google Chrome 브라우저 설치 필요

## 설치 방법

### 원클릭 설치 (권장)

터미널에서 아래 명령어를 실행하면 모든 것이 자동으로 설치됩니다:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ParkShinUng/flutter-csias-desktop/master/scripts/setup.sh)"
```

**자동으로 설치되는 항목:**
- Homebrew (패키지 관리자)
- Git
- Flutter SDK (앱 빌드 도구)
- Node.js (자동화 스크립트용)
- CSIAS Desktop 소스코드 및 의존성

**설치 위치:** `~/Applications/csias_desktop`

### 설치 후 사용

```bash
# 프로젝트 폴더로 이동
cd ~/Applications/csias_desktop

# 앱 실행 (디버그 모드)
./scripts/run.sh

# 앱 실행 (릴리즈 모드)
./scripts/run.sh release

# 최신 버전으로 업데이트
./scripts/update.sh
```

**빠른 실행 alias 설정 (선택사항):**

```bash
# ~/.zshrc에 alias 추가
echo 'alias csias="cd ~/Applications/csias_desktop && ./scripts/run.sh"' >> ~/.zshrc
source ~/.zshrc

# 이제 터미널에서 csias 명령어로 실행 가능
csias
```

### 수동 업데이트

업데이트 스크립트는 다음 작업을 수행합니다:
1. Git에서 최신 소스 가져오기
2. Flutter 패키지 업데이트
3. Runner 모듈 업데이트

```bash
cd ~/Applications/csias_desktop
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

### Tistory 포스팅

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

### Google 색인 관리

1. **서비스 계정 설정 (Indexing API)**
   - Google Cloud Console에서 서비스 계정 생성
   - JSON 키 파일을 지정된 경로에 복사
   - Search Console에서 서비스 계정 이메일에 소유자 권한 부여

2. **OAuth 인증 (URL Inspection API)**
   - Google Cloud Console에서 OAuth 2.0 자격증명 생성
   - JSON 파일을 지정된 경로에 복사
   - 앱에서 "인증" 버튼 클릭하여 Google 계정 인증

3. **색인 요청**
   - "전체 색인 요청" 버튼 클릭
   - 자동으로 sitemap에서 URL 추출
   - 색인되지 않은 URL만 Indexing API로 요청

## 스크립트 실행 순서

### 초기 설치 흐름

```
setup.sh (원클릭 설치)
    │
    ├── 1. Homebrew 설치/확인
    ├── 2. Git 설치/확인
    ├── 3. Flutter SDK 설치/확인
    ├── 4. Node.js 설치/확인
    ├── 5. Git 저장소 클론 → ~/Applications/csias_desktop
    │
    └── setup_env.sh 호출
            │
            ├── 1. Flutter 패키지 설치 (flutter pub get)
            ├── 2. Node.js 바이너리 다운로드 (macOS universal)
            ├── 3. Windows 플레이스홀더 생성 (빌드 오류 방지)
            ├── 4. Runner node_modules 설치 (npm install)
            └── 5. Google Chrome 설치 확인
```

### 앱 실행 흐름

```
run.sh
    │
    ├── 환경 확인 (Flutter, Node.js 바이너리, node_modules)
    ├── 누락 시 → setup_env.sh 자동 호출
    │
    └── flutter run -d macos (디버그) 또는
        flutter build macos --release (릴리즈)
```

### 업데이트 흐름

```
update.sh
    │
    ├── 현재 버전 확인
    ├── 로컬 변경사항 확인/정리
    ├── git pull origin master
    ├── flutter pub get
    └── npm install (Runner 모듈)
```

## 필수 파일 및 경로

### 앱 실행에 필요한 파일

| 파일/폴더 | 경로 | 설명 |
|-----------|------|------|
| Node.js 바이너리 | `assets/bin/macos/node-darwin-x64-darwin-arm64` | Playwright 실행용 |
| Windows 플레이스홀더 | `assets/bin/windows/node.exe` | Flutter 빌드 오류 방지용 빈 파일 |
| Runner 스크립트 | `assets/runner/runner.js` | Tistory 자동화 스크립트 |
| Runner 모듈 | `assets/runner/node_modules/` | Playwright, cheerio 등 |
| Google Chrome | `/Applications/Google Chrome.app` | 브라우저 자동화용 |

### 사용자 데이터 저장 경로

**macOS**: `~/Library/Application Support/csias_desktop/data/`

| 파일 | 설명 |
|------|------|
| `accounts.json` | Tistory 계정 정보 (비밀번호 제외) |
| `passwords.json` | 암호화된 비밀번호 |
| `google_service_account.json` | Google Indexing API 서비스 계정 키 (사용자가 복사) |
| `google_oauth_credentials.json` | OAuth 2.0 클라이언트 자격증명 (사용자가 복사) |
| `google_oauth_tokens.json` | OAuth 액세스/리프레시 토큰 (자동 생성) |
| `indexed_urls.json` | 색인 요청 기록 및 일일 사용량 |

### Google API 자격증명 설정

1. **서비스 계정 (Indexing API)**
   ```
   ~/Library/Application Support/csias_desktop/data/google_service_account.json
   ```
   - Google Cloud Console → IAM → 서비스 계정 → JSON 키 다운로드
   - Search Console에서 해당 이메일에 소유자 권한 부여 필요

2. **OAuth 2.0 (URL Inspection API)**
   ```
   ~/Library/Application Support/csias_desktop/data/google_oauth_credentials.json
   ```
   - Google Cloud Console → API 및 서비스 → 사용자 인증 정보 → OAuth 2.0 클라이언트 ID
   - "데스크톱 앱" 유형으로 생성 후 JSON 다운로드

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
│       ├── tistory_posting/    # Tistory 포스팅 기능
│       │   ├── data/           # 스토리지 서비스
│       │   ├── domain/         # 모델
│       │   └── presentation/   # UI, 상태 관리
│       └── google_indexing/    # Google 색인 관리 기능
│           ├── data/           # API 서비스, 스토리지
│           ├── domain/         # 모델
│           └── presentation/   # UI, 상태 관리
├── assets/
│   ├── bin/                    # 플랫폼별 바이너리
│   │   ├── macos/              # Node.js (macOS universal)
│   │   └── windows/            # Node.js (Windows, 플레이스홀더)
│   ├── icon/                   # 앱 아이콘
│   └── runner/                 # Node.js 자동화 스크립트
│       ├── runner.js           # Playwright 기반 자동화
│       ├── package.json        # npm 의존성
│       └── node_modules/       # npm 모듈 (git 제외)
├── scripts/
│   ├── setup.sh                # 원클릭 설치 스크립트
│   ├── setup_env.sh            # 환경 구축 스크립트
│   ├── run.sh                  # 앱 실행 스크립트
│   ├── update.sh               # 업데이트 스크립트
│   └── build_release.sh        # 릴리즈 빌드 스크립트
└── macos/                      # macOS 네이티브 설정
```

## 스크립트 상세 설명

### setup.sh
- **용도**: 처음 설치할 때 한 번만 실행
- **기능**: Homebrew, Git, Flutter, Node.js 설치 및 저장소 클론
- **실행**: 터미널에서 curl 명령어로 실행

### setup_env.sh
- **용도**: Git에 포함되지 않은 파일 설치
- **기능**: Node.js 바이너리 다운로드, npm 모듈 설치, Flutter 패키지 설치
- **자동 호출**: setup.sh, run.sh에서 필요시 자동 호출

### run.sh
- **용도**: 앱 실행
- **옵션**:
  - `./scripts/run.sh` - 디버그 모드 (개발용, 핫 리로드 지원)
  - `./scripts/run.sh release` - 릴리즈 모드 (최적화됨)

### update.sh
- **용도**: 최신 버전으로 업데이트
- **기능**: git pull, flutter pub get, npm install

### build_release.sh
- **용도**: 배포용 DMG 파일 생성
- **출력**: `dist/csias_desktop.dmg`
- **포함 작업**: 빌드, Node.js 바이너리 서명, 앱 서명, DMG 생성

## 기술 스택

- **Frontend**: Flutter (Dart)
- **State Management**: Riverpod
- **Automation**: Node.js + Playwright
- **IPC**: JSON-line 프로토콜 (stdin/stdout)
- **Google APIs**: Indexing API, URL Inspection API
- **Authentication**: OAuth 2.0, Service Account

## API 할당량

| API | 일일 한도 |
|-----|----------|
| Indexing API | 200회 |
| URL Inspection API | 2,000회 |

## 빌드 스크립트

```bash
# 릴리즈 빌드 + DMG 생성
./scripts/build_release.sh
```

출력: `dist/csias_desktop.dmg`

## 라이선스

Private - All rights reserved
