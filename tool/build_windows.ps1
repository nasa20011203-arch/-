param(
  [ValidateSet('Debug', 'Release')]
  [string]$Configuration = 'Debug'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Check-Exit([string]$Step) {
  if ($LASTEXITCODE -ne 0) { throw "$Step failed (exit $LASTEXITCODE)" }
}
flutter --version
Check-Exit 'Flutter version'
flutter pub get --enforce-lockfile
Check-Exit 'Dependency install'
dart --suppress-analytics run build_runner build --delete-conflicting-outputs
Check-Exit 'Drift code generation'
flutter analyze
Check-Exit 'Static analysis'
flutter build windows "--$($Configuration.ToLowerInvariant())"
Check-Exit 'Windows build'
$bundle = "build/windows/x64/runner/$Configuration"
if (!(Test-Path "$bundle/offline_calendar.exe")) { throw 'Executable not found' }
# flutter_tester must resolve the same bundled SQLite used by the runner.
$env:PATH = (Resolve-Path $bundle).Path + [IO.Path]::PathSeparator + $env:PATH
flutter test --reporter expanded
Check-Exit 'Unit and widget tests'
New-Item -ItemType Directory -Force 'dist' | Out-Null
Compress-Archive -Path "$bundle/*" -DestinationPath "dist/offline_calendar-windows-$($Configuration.ToLowerInvariant()).zip" -Force
Write-Output "Build complete ($Configuration). Run the exe with its entire bundle folder. Windows GUI verification is still required."
