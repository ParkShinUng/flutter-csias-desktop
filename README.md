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
- **URL Inspection API**: OAuth 2.0 인증으로 색인 상태 확인 (이미 색인된 URL은 요청 스킵)
- **Indexing API**: 서비스 계정으로 색인 요청 자동화
- **모바일 URL 필터링**: `/m/` 경로 URL 자동 제외
- **일일 할당량 관리**: API 사용량 추적 및 표시

## 시스템 요구사항

- macOS 10.15 이상
- Google Chrome 브라우저 설치 필요

## 설치 방법

### 원클릭 설치 및 빌드 (권장)

터미널에서 아래 명령어를 실행하면 모든 것이 자동으로 설치되고 앱이 빌드됩니다:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ParkShinUng/flutter-csias-desktop/master/scripts/install_and_build.sh)"
```

**자동으로 수행되는 작업:**
1. 필요한 도구 설치 (Homebrew, Git, Flutter, Node.js)
2. 소스코드 다운로드 → `~/Desktop/csias_desktop`
3. 실행 환경 구축 (Node.js 바이너리, npm 모듈)
4. Release 빌드 생성
5. 실행 가능한 앱을 Desktop에 복사 → `~/Desktop/csias_desktop.app`

### 앱 실행

설치 완료 후 Desktop에 있는 `csias_desktop.app`을 더블클릭하여 실행합니다.

또는 터미널에서:
```bash
open ~/Desktop/csias_desktop.app
```

### 업데이트

최신 버전으로 업데이트하려면 `install_and_build.sh`를 다시 실행합니다:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ParkShinUng/flutter-csias-desktop/master/scripts/install_and_build.sh)"
```

### 개발자 모드 실행 (디버그)

개발 중 핫 리로드가 필요한 경우:

```bash
cd ~/Desktop/csias_desktop
./scripts/run.sh          # 디버그 모드
./scripts/run.sh release  # 릴리즈 모드
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

## 필수 파일 및 경로

### 앱 실행에 필요한 파일

| 파일/폴더 | 경로 | 설명 |
|-----------|------|------|
| Node.js 바이너리 | `assets/bin/macos/node-darwin-x64-darwin-arm64` | Playwright 실행용 |
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
│   │   └── macos/              # Node.js (macOS)
│   ├── icon/                   # 앱 아이콘
│   └── runner/                 # Node.js 자동화 스크립트
│       ├── runner.js           # Playwright 기반 자동화
│       ├── package.json        # npm 의존성
│       └── node_modules/       # npm 모듈 (git 제외)
├── scripts/
│   ├── install_and_build.sh    # 원클릭 설치 및 빌드
│   └── run.sh                  # 개발용 실행 스크립트
└── macos/                      # macOS 네이티브 설정
```

## 스크립트 설명

### install_and_build.sh

원클릭 설치 및 빌드 스크립트입니다. 다음 작업을 자동으로 수행합니다:

1. **필수 도구 설치**: Homebrew, Git, Flutter, Node.js
2. **소스코드 다운로드**: GitHub에서 클론
3. **환경 구축**: Flutter 패키지, Node.js 바이너리, npm 모듈 설치
4. **Release 빌드**: Flutter macOS 앱 빌드
5. **앱 서명 및 복사**: Desktop에 실행 가능한 앱 복사

```bash
# 원격 실행
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ParkShinUng/flutter-csias-desktop/master/scripts/install_and_build.sh)"

# 로컬 실행 (소스가 있는 경우)
./scripts/install_and_build.sh
```

### run.sh

개발용 실행 스크립트입니다. 핫 리로드를 지원하는 디버그 모드로 앱을 실행합니다.

```bash
./scripts/run.sh          # 디버그 모드 (flutter run)
./scripts/run.sh release  # 릴리즈 모드 (flutter build + open)
```

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

## 라이선스

Private - All rights reserved
