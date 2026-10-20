#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter --version
flutter pub get --enforce-lockfile
dart --suppress-analytics run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
