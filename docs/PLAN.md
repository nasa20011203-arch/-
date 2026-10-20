# Phase 1 개발 계획

범위: Windows 10/11 오프라인 월간 달력. Google Drive, 모바일, 계정, 네트워크 서비스는 구현하지 않는다.

1. Flutter 3.35.7 / Dart 3.9 계열 프로젝트, Windows runner 및 기본 위젯 실행 확인.
2. Drift / SQLite schema v1, UUID 메모, 활성 날짜 유일성, UTC·revision·tombstone, Repository와 재시작 테스트.
3. 일요일 시작 4~6주 달력과 월 이동, 오늘 표시, 셀 내 여러 줄 메모.
4. 날짜 더블클릭 편집, 직렬화한 debounce 저장, 닫기 flush, 실패 시 편집 내용 보존과 retry.
5. MethodChannel로 분리한 Win32 창 제어. 비문서 WorkerW 연결은 별도 파일, 실패 시 일반 창.
6. SQLite 설정 저장, 창 경계/DPI 복원, 투명도/글자 크기/자동 실행/모드.
7. 회귀 테스트와 Windows 수동 검증표. 검증 불가 항목은 명확히 미검증으로 남긴다.
8. Windows 개발 빌드 스크립트와 실행 문서. Linux에서는 Windows 바이너리를 생성·실행할 수 없다.

## 구조

- lib/core: 날짜 및 의존성 구성
- lib/models: 플랫폼 독립 모델
- lib/database: Drift schema / migration / 연결
- lib/repositories: 메모·설정 저장 추상화 및 구현
- lib/features/calendar, notes, settings: UI 및 로직
- lib/platform/windows: Dart channel adapter
- windows/runner/platform: Win32 구현 및 실험적 shell 연동
- test, integration_test: 실제 SQLite/위젯/프로세스 재연결 검증

테스트용 Linux runner는 개발 검증 도구로만 사용하며 모바일 앱은 생성하지 않는다. 저장 로직은 Windows API를 import하지 않는다.

## 2026-10-20 이어서 진행한 작업

- 소스와 README, PLAN, TEST_RESULTS, WINDOWS_BUILD가 모두 존재함을 확인했다.
- 전체 소스를 `nasa20011203-arch/-`의 main에 업로드하고 GitHub Actions Windows 빌드를 시작했다.
- 이번 Linux 실행에서도 정적 분석과 단위/위젯 테스트 19개, 별도 프로세스 SQLite 유지 검사가 통과했다.
- Windows 빌드 결과와 다운로드 위치는 WINDOWS_BUILD, 실행 근거와 남은 한계는 TEST_RESULTS에 기록한다.
- Windows GUI smoke test 및 WINDOWS_VALIDATION 실기 항목은 별도 수행 대상이다. Explorer의 HWND 파괴 후 창/엔진 재생성은 미완료다.
