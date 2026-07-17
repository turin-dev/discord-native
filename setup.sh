#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter가 PATH에 없습니다: https://docs.flutter.dev/get-started/install/windows' >&2
  exit 1
fi

flutter config --enable-windows-desktop
flutter doctor
flutter pub get
printf '%s\n' '설정 완료: flutter run -d windows'
