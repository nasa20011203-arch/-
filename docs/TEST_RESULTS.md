# Phase 1 구현 및 검증 결과

검증일: 2026-10-20. 환경: Linux x86_64, Flutter 3.35.7 / Dart 3.9.2. Windows 10/11 머신은 연결되지 않았습니다.

## 실제 실행 결과

- `flutter test test/bootstrap_test.dart`: Flutter 엔진 위젯 렌더링 통과.
- `dart --suppress-analytics run build_runner build --delete-conflicting-outputs`: Drift 코드 생성 성공.
- `flutter pub get --enforce-lockfile`: 잠금 파일로 재설치 성공.
- 재사용 설치 스크립트 `/workspace/tools/setup-calendar.sh` 재실행 성공.
- `flutter analyze --no-pub`: **No issues found**, 종료 코드 0. [원본 로그](validation/flutter_analyze.txt).
- `flutter test --no-pub --reporter expanded`: **19개 통과**, 실패 0. [원본 로그](validation/flutter_test.txt). 통합 테스트 폴더는 이 명령의 실행 대상에 포함하지 않았습니다.
- `dart ... tool/storage_probe.dart write /tmp/calendar-phase1-probe.sqlite` 후 **다른 프로세스**에서 `read`: 한글·영문·특수문자·줄바꿈·삭제 기록·revision·위치·크기·투명도·글자 크기 검증 통과. 임시 DB는 배포 소스에 포함하지 않습니다.
- `flutter build windows --debug --no-pub`: 실행했으나 `"build windows" only supported on Windows hosts.`로 중단. **Windows 빌드/컴파일 성공을 주장하지 않습니다.** Windows 바이너리와 ZIP 실행 묶음은 생성되지 않았습니다.
- `integration_test/windows_smoke_test.dart`: 작성·정적 분석 완료, **미실행 1개**. Windows에서 실행해야 합니다. 자동 테스트 통과 수에 포함하지 않습니다.

## 자동 테스트 구성

| 파일 | 개수 | 실제 검증 |
| --- | ---: | --- |
| bootstrap_test | 1 | 엔진 기본 렌더링 |
| calendar_date_test | 2 | 4/5/6주, 일요일 시작, 윤년·연도 경계, 40년간 월별 날짜 |
| repository_test | 8 | 파일 재연결, tombstone/복구/UUID/revision, 날짜 유일성, 공백 보존, 설정 유지, 실제 SQLite 쓰기 거절, 유효 날짜 검사, 인접 날짜 범위 |
| note_editor_controller_test | 3 | debounce, 저장 중 새 입력의 직렬화, 실패 후 draft 보존/재시도 |
| calendar_widget_test | 4 | 더블클릭·자동 저장·닫기 flush·월 이동·삭제, 실패 시 닫기 차단, 최소 창과 최대 글자, 네이티브 종료 요청을 모사한 저장/DB 종료 순서 |
| settings_test | 1 | 설정 값의 안전 범위와 음수 모니터 좌표 |

SQLite는 실제 네이티브 라이브러리를 사용합니다. 쓰기 오류는 `PRAGMA query_only=ON`으로 실제 SQLite가 쓰기를 거부하도록 유도했습니다. 물리 디스크 고장·디스크 가득 참을 실기 재현한 것은 아닙니다. 네이티브 종료 요청 테스트는 테스트 어댑터가 채널 콜백을 호출한 것으로, 실제 Windows Alt+F4 검증과 구분합니다.

## 요청하신 12개 검증 항목

| 번호 | 항목 | 현재 근거/상태 |
| --- | --- | --- |
| 1 | 날짜 더블클릭 편집창 | Flutter 위젯 테스트 통과; Windows 실제 마우스/IME 미검증 |
| 2 | 작성/자동 저장 | 위젯 및 controller 테스트 통과 |
| 3 | 종료/재실행 메모 유지 | 실제 파일 재연결·별도 프로세스 검사 통과; Windows 앱 전체 재실행 미검증 |
| 4 | 날짜/월 이동 후 유지 | 위젯 및 DB 테스트 통과 |
| 5 | 한글/여러 줄 | 실제 SQLite와 위젯 왕복 통과; Windows IME 조합 미검증 |
| 6 | 삭제 후 재실행 | 파일 재연결과 별도 프로세스 tombstone 검사 통과 |
| 7 | 위치/크기/투명도 유지 | SQLite 설정 왕복 통과; 실제 HWND 복원·합성 미검증 |
| 8 | Windows 바탕화면 보기 | 미실행 |
| 9 | 최대화 프로그램과 창 계층 | 미실행 |
| 10 | Explorer 재시작 | 미실행; HWND 파괴 시 복구 경로 미완료 |
| 11 | DPI 배율 | Windows 실기 미실행; 최소 크기/최대 글자 위젯 테스트만 통과 |
| 12 | 저장 실패 데이터 보호 | 실제 SQLite 거절·위젯 닫기 차단·재시도 통과; 물리 장치 고장 미검증 |

## 제공된 구현

- 요청된 디렉터리 구조와 플랫폼 독립 모델/Repository, Riverpod 의존성 구성.
- 스키마 v1, 명시적 마이그레이션 진입점, UTC·UUID·revision·tombstone·활성 날짜 부분 유일 인덱스. 미래 버전의 실제 마이그레이션은 해당 버전 추가 시 작성해야 합니다.
- 일~토 4~6주 달력, 오늘·월 이동, 인접 월 셀 메모, 여러 줄 클리핑.
- 단일 날짜 자유 문서, 650ms 자동 저장, 직렬화, 편집창·앱 종료 저장 완료 대기, 오류 유지·재시도.
- 로컬 설정 저장과 범위 검사. Windows 네이티브 창 모드·경계·자동 실행 코드는 작성했으나 Windows 컴파일·실행 전입니다.
- Win32 MethodChannel 어댑터, 별도 WorkerW 모듈, bounded shell 요청, 타이머/TaskbarCreated 복구 시도 및 일반 창 전환 경로.
- Windows 개발 빌드 스크립트, Windows 통합 smoke test, 수동 검증표.

## 미완료 / 외부 검증이 필요한 부분

**Phase 1 전체 완료 상태가 아닙니다.** Windows 개발 실행 파일 생성, 네이티브 모듈 컴파일, 실제 일반 창·투명도·이동/크기·자동 실행 확인이 남아 있습니다. Windows 머신에서 `tool/build_windows.ps1`를 실행하고 [실기 검증표](WINDOWS_VALIDATION.md)를 수행해야 합니다.

Explorer가 Flutter의 HWND까지 파괴하는 경우 현재 복구 코드에는 창/엔진 재생성 경로가 없습니다. 이 경우의 복구와 미저장 입력 보호는 미완료이며, 자동 테스트 19개로 보장할 수 없습니다. 바탕화면 모드를 실험적으로 표시하고 기본은 일반 창 모드로 유지했습니다. Win+D와 DPI를 검증하기 전 정상적인 바탕화면 고정 구현으로 보고하지 않습니다.

Google Drive 동기화와 모바일 앱은 구현하지 않았습니다. [Phase 2 고려 사항](../README.md#phase-2-고려-사항)은 설계 참고만 제공합니다.

## 클라우드 재사용 설정

`install_script`와 `start_skill`을 환경 설정 초안에 저장했습니다. Flutter 설치에 필요한 `storage.googleapis.com`을 사용자 지정 허용 도메인에 추가했습니다. 비밀키·서버는 필요하지 않습니다. 현재 머신에서 Flutter와 SQLite 검증은 수행했으며, 새 작업에서의 스냅샷 복원과 환경 게시 여부는 검증하지 않았습니다. 설정에서 변경을 검토·저장한 뒤 환경을 게시해야 재사용 설정을 활성화할 수 있습니다.
