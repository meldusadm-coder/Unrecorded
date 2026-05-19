#Requires -Version 5.1
<#
.SYNOPSIS
  Kill stale adb processes and start a fresh adb server on Windows.

.EXAMPLE
  .\Reset-Adb.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-Step([string] $Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string] $Message) {
  Write-Host "    $Message" -ForegroundColor Green
}

function Resolve-AndroidSdk {
  foreach ($name in @('ANDROID_HOME', 'ANDROID_SDK_ROOT')) {
    foreach ($scope in @('Process', 'User', 'Machine')) {
      $v = [Environment]::GetEnvironmentVariable($name, $scope)
      if ($v -and (Test-Path $v)) { return $v.TrimEnd('\') }
    }
  }

  $defaults = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk'),
    (Join-Path $env:USERPROFILE 'AppData\Local\Android\Sdk')
  )
  foreach ($path in $defaults) {
    if (Test-Path $path) { return $path }
  }

  throw @"
Android SDK not found.
  - Open Android Studio once and finish SDK setup, or
  - Set ANDROID_HOME to your SDK folder (usually %LOCALAPPDATA%\Android\Sdk).
"@
}

function Reset-AdbServer {
  param([string] $Adb)

  Write-Step 'Resetting adb on host'

  & $Adb kill-server 2>$null | Out-Null

  $procs = @(Get-Process -Name adb -ErrorAction SilentlyContinue)
  foreach ($proc in $procs) {
    Write-Host "    stopping adb process (PID $($proc.Id))" -ForegroundColor DarkGray
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  }

  if ($procs.Count -gt 0) {
    Start-Sleep -Seconds 1
  }

  Write-Host '    starting adb server' -ForegroundColor DarkGray
  $startOutput = & $Adb start-server 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "adb start-server failed: $($startOutput.Trim())"
  }

  $versionOutput = & $Adb version 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "adb is not responding after reset: $($versionOutput.Trim())"
  }

  Write-Ok 'adb server ready.'
}

if ($MyInvocation.InvocationName -ne '.') {
  try {
    $sdk = Resolve-AndroidSdk
    Write-Ok "Android SDK: $sdk"

    $adb = Join-Path $sdk 'platform-tools\adb.exe'
    if (-not (Test-Path $adb)) {
      throw "adb.exe not found. In Android Studio: SDK Manager -> install Android SDK Platform-Tools."
    }

    Reset-AdbServer -Adb $adb
    & $adb devices -l
  }
  catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
}
