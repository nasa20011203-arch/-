# 오프라인 바탕화면 캘린더 — Phase 1

Flutter / Dart, Riverpod, Drift / SQLite, C++ / Win32로 구현하는 Windows 10·11용 개발 버전입니다. 앱에서 서버나 인터넷을 사용하지 않습니다. 일반 창 모드가 기본값이며, Explorer 바탕화면 연결은 실험적입니다.

**현재 Windows 실행 파일과 Windows 실기 검증은 제공되지 않았습니다.** 이 저장소에는 전체 소스와 Windows 빌드 스크립트가 있습니다. 검증 범위와 한계는 [테스트 결과](docs/TEST_RESULTS.md)에 기록합니다.

## 실행 / 빌드

검증 도구 버전: Flutter **3.35.7**, Dart **3.9.2**. 의존성은 `pubspec.yaml`에서 직접 버전을 고정하고, 간접 의존성은 `pubspec.lock`으로 고정합니다.

Windows 준비물:

- Windows 10/11 x64
- Flutter 3.35.7 stable, Git
- Visual Studio 2022: **Desktop development with C++**, Windows 10/11 SDK, CMake 구성 요소
- `flutter doctor -v`에서 Windows toolchain 확인

PowerShell에서 저장소 루트로 이동한 다음:

```powershell
flutter pub get --enforce-lockfile
dart --suppress-analytics run build_runner build --delete-conflicting-outputs
flutter run -d windows
```

개발 실행 파일과 전체 폴더 ZIP 생성:

```powershell
.\tool\build_windows.ps1
```

로컬 스크립트 실행이 제한된 환경에서는 스크립트의 명령을 직접 실행할 수 있습니다. 스크립트는 코드 생성·정적 분석·Windows Debug 빌드·테스트를 수행하며 실패하면 중단합니다. 결과는 `build/windows/x64/runner/Debug/offline_calendar.exe`, 전체 묶음은 `dist/offline_calendar-windows-debug.zip`입니다. **이 경로는 생성 예정 경로이며, 현재 Windows 빌드 성공을 뜻하지 않습니다.** exe만 옮기지 말고 DLL·data를 포함한 전체 폴더를 사용하세요. Debug 배포는 개발 도구/런타임이 있는 개발 PC용입니다.

Windows에서 SQLite 테스트를 단독 실행할 때에는 먼저 Windows runner를 빌드하고 `sqlite3.dll`이 들어 있는 Debug 폴더를 해당 PowerShell 세션 PATH에 추가하세요. 빌드 스크립트가 이 작업을 처리합니다.

GitHub Actions Windows 빌드와 Release 실행 파일 생성 절차는 [Windows 빌드](docs/WINDOWS_BUILD.md)를 참고하세요. 워크플로는 아직 실행하지 않았습니다.

## 사용

- 일~토 월간 달력, 이전/다음 달과 오늘 이동
- 날짜 더블클릭 → 해당 날짜의 자유 메모 편집
- 650ms 디바운스 자동 저장, 편집창 닫기/앱 종료 시 저장 완료 대기
- 빈 문자열은 삭제 기록으로 저장; 공백과 줄바꿈은 그대로 보존
- 저장 실패 시 오류를 표시하고 편집창과 입력을 유지; 재시도 가능
- 제목을 끌어 이동, 오른쪽 아래 모서리를 끌어 크기 조절
- 설정에서 배경 불투명도, 글자 크기, 자동 실행, 모드 변경
- 바탕화면 연결 실패 시 일반 창으로 전환 시도

일반 창 모드도 최상위 창을 사용하지 않습니다. 투명 배경은 Windows compositor와 window_manager를 통해 설정하고 달력 배경 알파만 조절하므로 글자에는 설정 불투명도를 적용하지 않습니다. 실제 합성과 클릭 동작은 Windows에서 검증해야 합니다.

## 데이터

`path_provider.getApplicationSupportDirectory()` 아래 `calendar.sqlite`에 저장합니다. Windows에서는 사용자별 애플리케이션 지원 폴더를 사용합니다. 고정된 사용자 경로를 하드코딩하지 않습니다.

[스키마](docs/DATABASE.md), [구조와 단계](docs/PLAN.md), [Windows 검증표](docs/WINDOWS_VALIDATION.md)를 참고하세요. DB를 읽거나 마이그레이션하지 못하면 오류를 표시하며 자동 초기화/삭제하지 않습니다. 백업 시 앱을 종료하고 DB 파일을 복사하거나 SQLite backup API를 사용하세요. 실행 중에는 WAL 파일을 무시하고 본체만 복사하면 최신 변경을 놓칠 수 있습니다.

## 테스트

```sh
flutter test --reporter expanded
flutter analyze
```

Linux 테스트에는 `libsqlite3.so` 개발 링크가 필요합니다. 이 클라우드에서는 `source /workspace/tools/calendar-env.sh`로 Flutter·캐시·시스템 SQLite 링크를 활성화합니다. Linux runner는 개발 검증용이며 Phase 1 배포 대상은 Windows입니다.

별도 프로세스 간 파일 유지 검증(임시 경로만 사용):

```sh
dart --suppress-analytics run tool/storage_probe.dart write /tmp/calendar-probe.sqlite
dart --suppress-analytics run tool/storage_probe.dart read /tmp/calendar-probe.sqlite
```

Windows GUI 통합 테스트는 `flutter test integration_test/windows_smoke_test.dart -d windows`로 실행합니다. 실제 화면·Explorer·DPI 검증은 별도의 수동 검증표를 완료해야 합니다.

## Phase 2 고려 사항

동기화는 구현하지 않았습니다. 날짜 키는 로컬 달력의 `YYYY-MM-DD`, 수정 시각은 UTC 마이크로초, ID는 UUID, 삭제는 tombstone, 수정 횟수는 revision으로 분리했습니다. 향후 동기화 계층은 Repository 위에 두고, 명시적인 업데이트 버튼으로만 호출해야 합니다. 장치별 revision은 전역 순서가 아니므로 충돌 정책, 장치 식별자, 삭제 기록 보존 기간, Drive 원자적 업로드와 중단 복구, 백업·복원 정책을 별도로 설계해야 합니다. SQLite 파일 자체를 여러 장치에서 덮어쓰는 방식은 사용하지 않는 것이 좋습니다. 모바일에서는 DB 경로 어댑터와 UI를 추가하고 모델/Repository는 재사용할 수 있습니다.
