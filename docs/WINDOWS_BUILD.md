# Windows 실행 파일 빌드

GitHub Actions의 `Windows executable` 워크플로는 Windows Server 2022 / Visual Studio 2022 머신에서 Windows x64 Release 실행 파일을 생성합니다. 2026-10-20 15:11 KST에 Actions #1이 성공했습니다. 소스 커밋은 `7081eef9ae0512bc30f2d615eaac0c079cec6537`입니다.

- [성공한 빌드 및 로그](https://github.com/nasa20011203-arch/-/actions/runs/39378551694)
- [offline-calendar-windows-x64 다운로드](https://github.com/nasa20011203-arch/-/actions/runs/39378551694/artifacts/12244288732)
- Windows Release C++/Flutter 빌드, 정적 분석, 단위/위젯 테스트 19개, 생성 코드/잠금 파일 변경 검사 통과.
- GUI 통합 smoke test와 Windows 10/11 실기 항목은 미실행입니다.

## 수행 내용

1. Flutter 3.35.7 Windows SDK 다운로드 후 공식 릴리스 메타데이터의 SHA256과 비교.
2. 고정된 의존성 설치, Drift 생성, 정적 분석.
3. `flutter build windows --release`로 C++ 네이티브 모듈과 Flutter UI 빌드.
4. 생성된 SQLite DLL을 사용하는 단위/위젯 테스트 실행. 실패 시 중단.
5. 잠금 파일/생성 코드가 예상치 않게 바뀌지 않았는지 확인.
6. 실행 파일, SQLite/Flutter/플러그인 DLL 및 data 폴더를 묶은 ZIP을 Actions artifact로 업로드.

최소 권한은 `contents: read`이며 Release 게시나 소스 수정·push를 수행하지 않습니다. `main`으로 push하거나 Actions에서 수동 실행하면 작동합니다. 이번에는 사용자 승인으로 main 업로드와 첫 빌드를 수행했습니다.

## 결과 다운로드

GitHub에 로그인한 후 위 다운로드 링크 또는 성공한 실행의 Artifacts에서 `offline-calendar-windows-x64`를 다운로드합니다. GitHub artifact ZIP 안의 `offline_calendar-windows-release.zip`도 압축을 풀고 `offline_calendar.exe`를 실행합니다. exe와 함께 DLL·data 폴더를 유지해야 합니다. 빌드 결과물 보관 기간은 14일이며 이번 결과는 2026-11-03 15:11 KST 만료 예정입니다.

Windows 10/11 x64용이며 서명되지 않은 개발 버전입니다. Microsoft Visual C++ 2015–2022 x64 런타임이 없는 PC에는 공식 런타임 설치가 필요할 수 있습니다. 자동 테스트 성공은 Win+D·Explorer·실제 DPI 동작의 검증을 뜻하지 않으며 기존 [검증표](WINDOWS_VALIDATION.md)를 수행해야 합니다.

## Windows PC에서 직접 빌드

```powershell
.\tool\build_windows.ps1 -Configuration Release
```

로컬 빌드 결과 경로:

- `build/windows/x64/runner/Release/offline_calendar.exe`
- `dist/offline_calendar-windows-release.zip`

Debug 빌드는 `-Configuration Debug`로 실행합니다(기본값). 현재 Linux 환경에서는 이 PowerShell 빌드와 Windows 실행 파일을 실행 검증할 수 없습니다.

## 이번 변경의 검증

- actionlint 1.7.7로 GitHub Actions YAML 검사 통과.
- PowerShell 7.4.6 실제 파서로 빌드 스크립트 및 워크플로의 PowerShell 구문 검사 통과.
- Flutter Windows SDK SHA256은 공식 릴리스 메타데이터에서 확인한 값을 사용.
- Actions #1에서 실제 Windows Release 빌드와 테스트 실행 성공, artifact ID `12244288732` 업로드 확인.
- 외부 artifact ZIP 크기: 12,736,191 bytes. SHA256: `d9f83eb69c797402b184892710c247a9aafa64a6fa8af3a87a245245bde22e8d`.
- 빌드된 앱 자체의 GUI 실행 및 수동 검증은 수행하지 않았습니다.
