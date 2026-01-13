======================================
  CSIAS Desktop 설치 안내
======================================

macOS 보안 정책으로 인해 아래 명령어를 터미널에서 실행해주세요.

[설치 방법]

1. 터미널 앱을 엽니다 (Spotlight에서 "터미널" 검색)

2. 아래 명령어를 복사해서 붙여넣고 Enter:

   xattr -cr ~/Downloads/csias_desktop.dmg && open ~/Downloads/csias_desktop.dmg

3. DMG가 열리면 앱을 Applications 폴더로 드래그

4. 앱 첫 실행 시 우클릭 → "열기" 선택


[다른 위치에 다운로드한 경우]

다운로드 경로를 수정해서 실행하세요:
   xattr -cr /경로/csias_desktop.dmg && open /경로/csias_desktop.dmg


[문제 해결]

앱이 실행되지 않으면:
   xattr -cr /Applications/csias_desktop.app

