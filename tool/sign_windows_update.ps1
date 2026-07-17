[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$InstallerPath,
  [Parameter(Mandatory = $true)][string]$PrivateKeyPath,
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][string]$DownloadUrl,
  [string]$ReleaseNotesUrl = '',
  [string]$OutputPath = 'dist\appcast.xml',
  [string]$OpenSslDirectory = ''
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspacePrefix = $workspace.TrimEnd('\') + '\'
$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$privateKey = (Resolve-Path -LiteralPath $PrivateKeyPath).Path
if ($Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
  throw "유효하지 않은 version입니다: $Version"
}
$uri = $null
if (-not [Uri]::TryCreate($DownloadUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
  throw 'DownloadUrl은 유효한 HTTPS URL이어야 합니다.'
}
$output = if ([IO.Path]::IsPathRooted($OutputPath)) {
  [IO.Path]::GetFullPath($OutputPath)
} else {
  [IO.Path]::GetFullPath((Join-Path $workspace $OutputPath))
}
if (-not $output.StartsWith($workspacePrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw "OutputPath가 workspace 밖에 있습니다: $output"
}

if (-not $OpenSslDirectory) {
  $openssl = Get-Command openssl.exe -ErrorAction SilentlyContinue
  if ($openssl) {
    $OpenSslDirectory = Split-Path $openssl.Source -Parent
  } else {
    $candidates = @(
      'C:\Program Files\Git\usr\bin',
      'C:\Program Files\OpenSSL-Win64\bin'
    )
    $OpenSslDirectory = $candidates |
      Where-Object { Test-Path -LiteralPath (Join-Path $_ 'openssl.exe') } |
      Select-Object -First 1
  }
}
if (-not $OpenSslDirectory -or -not (Test-Path -LiteralPath (Join-Path $OpenSslDirectory 'openssl.exe'))) {
  throw 'openssl.exe를 찾지 못했습니다.'
}
$env:PATH = "$OpenSslDirectory;$env:PATH"

$signTool = Join-Path $workspace 'windows\flutter\ephemeral\.plugin_symlinks\auto_updater_windows\windows\WinSparkle-0.8.1\bin\sign_update.bat'
if (-not (Test-Path -LiteralPath $signTool)) {
  throw 'WinSparkle sign_update.bat을 찾지 못했습니다. flutter pub get을 먼저 실행하세요.'
}
$commandPaths = @($signTool, $installer, $privateKey)
if ($commandPaths | Where-Object { $_ -match '[%!&|<>^]' }) {
  throw '업데이트 서명 경로에 허용하지 않는 shell 문자가 있습니다.'
}
$signCommand = '"' + $signTool + '" "' + $installer + '" "' + $privateKey + '"'
$signatureOutput = & cmd.exe /D /S /C $signCommand
if ($LASTEXITCODE -ne 0) { throw "업데이트 서명 실패: $LASTEXITCODE" }
$signature = (($signatureOutput -join '') -replace '\s', '')
try {
  [void][Convert]::FromBase64String($signature)
} catch {
  throw 'WinSparkle 서명 출력이 유효한 Base64가 아닙니다.'
}

$arguments = @(
  'run', 'tool/generate_appcast.dart',
  "--version=$Version",
  "--url=$DownloadUrl",
  "--signature=$signature",
  "--length=$((Get-Item $installer).Length)",
  "--output=$output"
)
if ($ReleaseNotesUrl) { $arguments += "--release-notes=$ReleaseNotesUrl" }
$dart = Get-Command dart.exe -ErrorAction SilentlyContinue
if (-not $dart) {
  $flutter = Get-Command flutter.bat -ErrorAction SilentlyContinue
  if ($flutter) {
    $dartPath = Join-Path (Split-Path $flutter.Source -Parent) 'cache\dart-sdk\bin\dart.exe'
    if (Test-Path -LiteralPath $dartPath) { $dart = Get-Item -LiteralPath $dartPath }
  }
}
if (-not $dart) { throw 'dart.exe를 찾지 못했습니다.' }
& $dart.FullName @arguments
if ($LASTEXITCODE -ne 0) { throw "appcast 생성 실패: $LASTEXITCODE" }

[pscustomobject]@{
  installer = $installer
  appcast = $output
  version = $Version
}
