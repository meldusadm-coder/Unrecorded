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

function Invoke-AdbQuiet {
  param(
    [string] $Adb,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $AdbArgs
  )

  $prevEap = $ErrorActionPreference
  $prevNative = $null
  if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $prevNative = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
  }

  $ErrorActionPreference = 'Continue'
  try {
    $output = & $Adb @AdbArgs 2>&1 | Out-String
    return @{
      ExitCode = $LASTEXITCODE
      Output   = $output.Trim()
    }
  }
  finally {
    $ErrorActionPreference = $prevEap
    if ($null -ne $prevNative) {
      $PSNativeCommandUseErrorActionPreference = $prevNative
    }
  }
}

function Stop-AdbProcesses {
  $procs = @(Get-Process -Name adb -ErrorAction SilentlyContinue)
  foreach ($proc in $procs) {
    Write-Host "    stopping adb process (PID $($proc.Id))" -ForegroundColor DarkGray
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  }
  return $procs.Count
}

function Stop-PortListener {
  param([int] $Port)

  $lines = netstat -ano | Select-String ":${Port}\s"
  foreach ($line in $lines) {
    if ($line.Line -notmatch '\sLISTENING\s+(\d+)\s*$') { continue }

    $processId = [int]$Matches[1]
    if ($processId -le 0) { continue }

    $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
    $name = if ($proc) { $proc.ProcessName } else { 'unknown' }
    Write-Host "    stopping ${name} on port ${Port} (PID ${processId})" -ForegroundColor DarkGray
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
  }
}

function Reset-AdbServer {
  param([string] $Adb)

  Write-Step 'Resetting adb on host'

  # Kill processes first — kill-server often fails when the server is wedged.
  $killed = Stop-AdbProcesses
  if ($killed -gt 0) {
    Start-Sleep -Seconds 1
  }

  $killResult = Invoke-AdbQuiet -Adb $Adb kill-server
  if ($killResult.ExitCode -ne 0 -and $killResult.Output) {
    Write-Host "    kill-server: $($killResult.Output)" -ForegroundColor DarkGray
  }

  Stop-AdbProcesses | Out-Null
  Stop-PortListener -Port 5037
  Start-Sleep -Seconds 1

  $maxAttempts = 3
  $lastOutput = ''

  for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    Write-Host "    starting adb server (attempt ${attempt}/${maxAttempts})" -ForegroundColor DarkGray

    $startResult = Invoke-AdbQuiet -Adb $Adb start-server
    $lastOutput = $startResult.Output

    if ($startResult.ExitCode -eq 0) {
      $versionResult = Invoke-AdbQuiet -Adb $Adb version
      if ($versionResult.ExitCode -eq 0) {
        Write-Ok 'adb server ready.'
        return
      }
      $lastOutput = $versionResult.Output
    }

    if ($lastOutput) {
      Write-Host "    $lastOutput" -ForegroundColor DarkGray
    }

    Stop-AdbProcesses | Out-Null
    Stop-PortListener -Port 5037
    Start-Sleep -Seconds 2
  }

  throw @"
adb could not be restarted after ${maxAttempts} attempts.
  Last output: $lastOutput
  Try closing Android Studio, run scripts\windows\reset-adb.cmd again, or reboot Windows.
"@
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

    $devices = Invoke-AdbQuiet -Adb $adb devices -l
    if ($devices.Output) {
      Write-Host $devices.Output
    }
    if ($devices.ExitCode -ne 0) {
      throw "adb devices failed: $($devices.Output)"
    }
  }
  catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
}
