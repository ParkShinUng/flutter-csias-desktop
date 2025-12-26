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

### 사용자 설치

1. `csias_desktop.dmg` 파일 다운로드
2. DMG 파일 더블클릭하여 마운트
3. `설치.command` 더블클릭
4. 터미널이 열리면 자동 설치 진행

### 개발자 빌드

```bash
# 의존성 설치
flutter pub get
cd assets/runner && npm install && cd ../..

# 개발 모드 실행
flutter run -d macos

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
