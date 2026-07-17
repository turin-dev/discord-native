[CmdletBinding()]
param(
  [string]$ReleaseDirectory = 'build\windows\x64\runner\Release'
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspacePrefix = $workspace.TrimEnd('\') + '\'
$release = if ([IO.Path]::IsPathRooted($ReleaseDirectory)) {
  (Resolve-Path -LiteralPath $ReleaseDirectory).Path
} else {
  (Resolve-Path -LiteralPath (Join-Path $workspace $ReleaseDirectory)).Path
}
if (-not $release.StartsWith($workspacePrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw "ReleaseDirectory가 workspace 밖에 있습니다: $release"
}

$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$flutterRoot = Split-Path (Split-Path $flutterCommand -Parent) -Parent
$dart = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$engineArtifacts = Join-Path $flutterRoot 'bin\cache\artifacts\engine\windows-x64'
$constFinder = Join-Path $engineArtifacts 'const_finder.dart.snapshot'
$fontSubset = Join-Path $engineArtifacts 'font-subset.exe'
$font = Join-Path $release 'data\flutter_assets\fonts\MaterialIcons-Regular.otf'
$appDill = Get-ChildItem (Join-Path $workspace '.dart_tool\flutter_build') -Recurse -File -Filter app.dill |
  Sort-Object LastWriteTimeUtc -Descending |
  Select-Object -First 1

foreach ($required in @($dart, $constFinder, $fontSubset, $font)) {
  if (-not (Test-Path -LiteralPath $required)) { throw "필수 파일 누락: $required" }
}
if ($null -eq $appDill) { throw 'Release app.dill을 찾지 못했습니다.' }

$finderOutput = & $dart $constFinder `
  --kernel-file $appDill.FullName `
  --class-library-uri package:flutter/src/widgets/icon_data.dart `
  --class-name IconData `
  --annotation-class-name _StaticIconProvider `
  --annotation-class-library-uri package:flutter/src/widgets/icon_data.dart
if ($LASTEXITCODE -ne 0) { throw "Icon const finder 실패: $LASTEXITCODE" }
$iconData = $finderOutput | ConvertFrom-Json
if ($iconData.nonConstantLocations.Count -gt 0) {
  throw 'non-constant IconData 때문에 font subset을 만들 수 없습니다.'
}
$codePoints = @(
  $iconData.constantInstances |
    Where-Object fontFamily -eq 'MaterialIcons' |
    Select-Object -ExpandProperty codePoint -Unique |
    Sort-Object
)
if ($codePoints.Count -eq 0) { throw '사용 중인 Material icon codepoint가 없습니다.' }

$temporaryFont = "$font.subset"
$codePointFile = "$font.codepoints"
$before = (Get-Item $font).Length
try {
  $inputBytes = [Text.Encoding]::UTF8.GetBytes(($codePoints -join ' ') + "`n")
  [IO.File]::WriteAllBytes($codePointFile, $inputBytes)
  $paths = @($fontSubset, $temporaryFont, $font, $codePointFile)
  if ($paths | Where-Object { $_ -match '[&|<>^]' }) {
    throw 'font subset 경로에 허용하지 않는 shell 문자가 있습니다.'
  }
  $commandLine = "`"$fontSubset`" `"$temporaryFont`" `"$font`" < `"$codePointFile`""
  $subsetOutput = & $env:ComSpec /d /s /c $commandLine
  if ($LASTEXITCODE -ne 0) { throw "font-subset 실패: $LASTEXITCODE $subsetOutput" }
  Copy-Item -LiteralPath $temporaryFont -Destination $font -Force
} finally {
  foreach ($temporaryFile in @($temporaryFont, $codePointFile)) {
    if (Test-Path -LiteralPath $temporaryFile) {
      Remove-Item -LiteralPath $temporaryFile -Force
    }
  }
}
$after = (Get-Item $font).Length
[pscustomobject]@{
  glyphs = $codePoints.Count
  beforeKB = [Math]::Round($before / 1KB, 2)
  afterKB = [Math]::Round($after / 1KB, 2)
}
