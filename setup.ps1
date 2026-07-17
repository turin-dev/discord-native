[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter가 PATH에 없습니다. https://docs.flutter.dev/get-started/install/windows 에서 설치하세요.'
}

flutter config --enable-windows-desktop
if ($LASTEXITCODE -ne 0) { throw 'Windows desktop 활성화에 실패했습니다.' }

flutter doctor
if ($LASTEXITCODE -ne 0) { throw 'flutter doctor가 필요한 개발 도구 문제를 발견했습니다.' }

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency 설치에 실패했습니다.' }

Write-Host '설정 완료: flutter run -d windows'
