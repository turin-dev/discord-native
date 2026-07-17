[CmdletBinding()]
param(
  [string]$ExecutablePath = 'build\windows\x64\runner\Release\discord_native.exe',
  [string]$OutputPath = 'benchmark-results\windows-release.json',
  [int]$StartupTimeoutSeconds = 15,
  [int]$SettleSeconds = 5,
  [int]$CpuSampleSeconds = 5,
  [double]$MaxStartupSeconds = 1.5,
  [double]$MaxMemoryMB = 200,
  [double]$MaxIdleCpuPercent = 0.5,
  [double]$MaxInstallSizeMB = 60,
  [switch]$Enforce
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspacePrefix = $workspace.TrimEnd('\') + '\'

function Test-WorkspacePath([string]$Path) {
  return $Path.Equals($workspace, [StringComparison]::OrdinalIgnoreCase) -or
    $Path.StartsWith($workspacePrefix, [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-WorkspaceFile([string]$Path) {
  $candidate = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $workspace $Path }
  $resolved = (Resolve-Path -LiteralPath $candidate).Path
  if (-not (Test-WorkspacePath $resolved)) {
    throw "경로가 workspace 밖에 있습니다: $resolved"
  }
  return $resolved
}

function Resolve-OutputFile([string]$Path) {
  $candidate = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $workspace $Path }
  $fullPath = [IO.Path]::GetFullPath($candidate)
  if (-not (Test-WorkspacePath $fullPath)) {
    throw "출력 경로가 workspace 밖에 있습니다: $fullPath"
  }
  return $fullPath
}

if ($StartupTimeoutSeconds -le 0 -or $SettleSeconds -lt 0 -or $CpuSampleSeconds -le 0) {
  throw '측정 시간은 0보다 커야 합니다.'
}

$executable = Resolve-WorkspaceFile $ExecutablePath
$artifactDirectory = Split-Path $executable -Parent
$output = Resolve-OutputFile $OutputPath
$logicalProcessors = [Environment]::ProcessorCount
$process = $null
$stopwatch = [Diagnostics.Stopwatch]::StartNew()

try {
  $process = Start-Process -FilePath $executable -PassThru -WindowStyle Hidden
  $ready = $process.WaitForInputIdle($StartupTimeoutSeconds * 1000)
  $process.Refresh()
  if ($process.HasExited) {
    throw "앱이 시작 중 종료되었습니다. exitCode=$($process.ExitCode)"
  }
  if (-not $ready) {
    throw "${StartupTimeoutSeconds}초 안에 UI message loop가 준비되지 않았습니다."
  }
  $stopwatch.Stop()
  $startupSeconds = $stopwatch.Elapsed.TotalSeconds

  if ($SettleSeconds -gt 0) {
    Start-Sleep -Seconds $SettleSeconds
  }
  $process.Refresh()
  $memoryMB = $process.WorkingSet64 / 1MB
  $cpuBefore = $process.TotalProcessorTime.TotalSeconds
  Start-Sleep -Seconds $CpuSampleSeconds
  $process.Refresh()
  $cpuSeconds = $process.TotalProcessorTime.TotalSeconds - $cpuBefore
  $idleCpuPercent = $cpuSeconds * 100 / $CpuSampleSeconds / $logicalProcessors
  $installBytes = (Get-ChildItem $artifactDirectory -Recurse -File | Measure-Object Length -Sum).Sum
  $installSizeMB = $installBytes / 1MB

  $violations = @()
  if ($startupSeconds -gt $MaxStartupSeconds) { $violations += 'startupSeconds' }
  if ($memoryMB -gt $MaxMemoryMB) { $violations += 'memoryMB' }
  if ($idleCpuPercent -gt $MaxIdleCpuPercent) { $violations += 'idleCpuPercent' }
  if ($installSizeMB -gt $MaxInstallSizeMB) { $violations += 'installSizeMB' }

  $result = [ordered]@{
    measuredAt = [DateTime]::UtcNow.ToString('o')
    executable = $executable.Substring($workspace.Length + 1)
    startupSeconds = [Math]::Round($startupSeconds, 3)
    memoryMB = [Math]::Round($memoryMB, 2)
    idleCpuPercent = [Math]::Round($idleCpuPercent, 3)
    installSizeMB = [Math]::Round($installSizeMB, 2)
    logicalProcessors = $logicalProcessors
    thresholds = [ordered]@{
      maxStartupSeconds = $MaxStartupSeconds
      maxMemoryMB = $MaxMemoryMB
      maxIdleCpuPercent = $MaxIdleCpuPercent
      maxInstallSizeMB = $MaxInstallSizeMB
    }
    passed = $violations.Count -eq 0
    violations = $violations
  }
  New-Item -ItemType Directory -Force -Path (Split-Path $output -Parent) | Out-Null
  $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $output -Encoding utf8
  $result
  if ($Enforce -and $violations.Count -gt 0) {
    throw "성능 목표 미달: $($violations -join ', ')"
  }
} finally {
  if ($null -ne $process -and -not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  }
}
