[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [int]$BuildNumber = 1,
  [string]$UpdateFeedUrl = '',
  [string]$DsaPublicKeyPath = '',
  [string]$OutputDirectory = 'dist',
  [string]$InnoCompiler = '',
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspacePrefix = $workspace.TrimEnd('\') + '\'
$releaseDirectory = Join-Path $workspace 'build\windows\x64\runner\Release'
$embeddedPublicKey = Join-Path $workspace 'windows\runner\dsa_pub.pem'
$createdPublicKey = $false

if ($Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
  throw "유효하지 않은 version입니다: $Version"
}
if ($BuildNumber -le 0) {
  throw 'BuildNumber는 1 이상이어야 합니다.'
}
if ($UpdateFeedUrl) {
  $feed = $null
  if (-not [Uri]::TryCreate($UpdateFeedUrl, [UriKind]::Absolute, [ref]$feed) -or $feed.Scheme -ne 'https') {
    throw 'UpdateFeedUrl은 유효한 HTTPS URL이어야 합니다.'
  }
}
if ($SkipBuild -and $DsaPublicKeyPath) {
  throw 'SkipBuild와 DsaPublicKeyPath는 함께 사용할 수 없습니다.'
}

function Find-InnoCompiler {
  if ($InnoCompiler) {
    return (Resolve-Path -LiteralPath $InnoCompiler).Path
  }
  $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  $candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }
  throw 'Inno Setup 6 ISCC.exe를 찾지 못했습니다.'
}

try {
  if (-not $SkipBuild) {
    if ($DsaPublicKeyPath) {
      if (Test-Path -LiteralPath $embeddedPublicKey) {
        throw 'windows/runner/dsa_pub.pem이 이미 존재합니다.'
      }
      $publicKey = (Resolve-Path -LiteralPath $DsaPublicKeyPath).Path
      Copy-Item -LiteralPath $publicKey -Destination $embeddedPublicKey
      $createdPublicKey = $true
    }
    $buildArguments = @(
      'build', 'windows', '--release',
      "--build-name=$Version", "--build-number=$BuildNumber",
      "--split-debug-info=$(Join-Path $workspace 'build\symbols\windows')"
    )
    if ($UpdateFeedUrl) {
      $buildArguments += "--dart-define=DISCORD_NATIVE_UPDATE_FEED=$UpdateFeedUrl"
    }
    & flutter @buildArguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter release build 실패: $LASTEXITCODE" }
  }

  & (Join-Path $PSScriptRoot 'subset_material_icons.ps1') -ReleaseDirectory $releaseDirectory

  $requiredFiles = @('discord_native.exe', 'libdave.dll', 'opus.dll')
  foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $releaseDirectory $file))) {
      throw "Release 산출물 누락: $file"
    }
  }

  $output = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    [IO.Path]::GetFullPath($OutputDirectory)
  } else {
    [IO.Path]::GetFullPath((Join-Path $workspace $OutputDirectory))
  }
  if (-not $output.Equals($workspace, [StringComparison]::OrdinalIgnoreCase) -and
      -not $output.StartsWith($workspacePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory가 workspace 밖에 있습니다: $output"
  }
  New-Item -ItemType Directory -Force -Path $output | Out-Null
  $compiler = Find-InnoCompiler
  $script = Join-Path $workspace 'packaging\discord_native.iss'
  & $compiler "/DSourceDir=$releaseDirectory" "/DAppVersion=$Version" "/DOutputDir=$output" $script
  if ($LASTEXITCODE -ne 0) { throw "Inno Setup 실패: $LASTEXITCODE" }

  $installer = Join-Path $output "discord-native-$Version-windows-x64-setup.exe"
  if (-not (Test-Path -LiteralPath $installer)) {
    throw "설치 파일이 생성되지 않았습니다: $installer"
  }
  $hash = Get-FileHash -LiteralPath $installer -Algorithm SHA256
  "$($hash.Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($installer))" |
    Set-Content -LiteralPath "$installer.sha256" -Encoding ascii
  [pscustomobject]@{
    installer = $installer
    sizeMB = [Math]::Round((Get-Item $installer).Length / 1MB, 2)
    sha256 = $hash.Hash.ToLowerInvariant()
  }
} finally {
  if ($createdPublicKey -and (Test-Path -LiteralPath $embeddedPublicKey)) {
    Remove-Item -LiteralPath $embeddedPublicKey -Force
  }
}
