#!/usr/bin/env bash
set -euo pipefail

workspace="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$workspace"

if command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$workspace/setup.ps1"
  exit $?
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter가 PATH에 없습니다: https://docs.flutter.dev/get-started/install/windows' >&2
  exit 1
fi

flutter pub get
printf '%s\n' 'Dart/Flutter dependency 설정 완료.'
printf '%s\n' 'Windows build와 실행은 Windows PowerShell에서 ./setup.ps1을 사용하세요.'
