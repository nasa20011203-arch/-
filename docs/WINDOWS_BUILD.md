# Windows 실행 파일 빌드

GitHub Actions의 `Windows executable` 워크플로는 Windows Server 2022 / Visual Studio 2022 머신에서 Windows x64 Release 실행 파일을 생성합니다. 현재 이 워크플로는 로컬에 작성되어 있으며 아직 GitHub에 업로드하거나 실행하지 않았습니다.

## 수행 내용

1. Flutter 3.35.7 Windows SDK 다운로드 후 공식 릴리스 메타데이터의 SHA256과 비교.
2. 고정된 의존성 설치, Drift 생성, 정적 분석.
3. `flutter build windows --release`로 C++ 네이티브 모듈과 Flutter UI 빌드.
4. 생성된 SQLite DLL을 사용하는 단위/위젯 테스트 실행. 실패 시 중단.
5. 잠금 파일/생성 코드가 예상치 않게 바뀌지 않았는지 확인.
6. 실행 파일, SQLite/Flutter/플러그인 DLL 및 data 폴더를 묶은 ZIP을 Actions artifact로 업로드.

최소 권한은 `contents: read`이며 Release 게시나 소스 수정·push를 수행하지 않습니다. `main`으로 push하거나 Actions에서 수동 실행하면 작동합니다. `main` 업로드는 이 로컬 작업과 별개의 원격 작업입니다.

## 결과 다운로드

성공한 실행의 Artifacts에서 `offline-calendar-windows-x64`를 다운로드합니다. GitHub artifact ZIP 안의 `offline_calendar-windows-release.zip`도 압축을 풀고 `offline_calendar.exe`를 실행합니다. exe와 함께 DLL·data 폴더를 유지해야 합니다. 빌드 결과물 보관 기간은 14일입니다.

Windows 10/11 x64용이며 서명되지 않은 개발 버전입니다. Microsoft Visual C++ 2015–2022 x64 런타임이 없는 PC에는 공식 런타임 설치가 필요할 수 있습니다. 자동 테스트 성공은 Win+D·Explorer·실제 DPI 동작의 검증을 뜻하지 않으며 기존 [검증표](WINDOWS_VALIDATION.md)를 수행해야 합니다.

## Windows PC에서 직접 빌드

```powershell
.\tool\build_windows.ps1 -Configuration Release
```

생성 예정 경로:

- `build/windows/x64/runner/Release/offline_calendar.exe`
- `dist/offline_calendar-windows-release.zip`

Debug 빌드는 `-Configuration Debug`로 실행합니다(기본값). 현재 Linux 환경에서는 이 PowerShell 빌드와 Windows 실행 파일을 실행 검증할 수 없습니다.

## 이번 변경의 검증

- actionlint 1.7.7로 GitHub Actions YAML 검사 통과.
- PowerShell 7.4.6 실제 파서로 빌드 스크립트 및 워크플로의 PowerShell 구문 검사 통과.
- Flutter Windows SDK SHA256은 공식 릴리스 메타데이터에서 확인한 값을 사용.
- Windows 빌드 명령 자체와 새 GitHub Actions 실행은 아직 미실행. 구문 검사 성공을 실행 파일 생성 성공으로 보지 않습니다.
