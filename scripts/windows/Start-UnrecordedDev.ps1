#Requires -Version 5.1
<#
.SYNOPSIS
  Start Docker Desktop, Android emulator, and adb on Windows for Unrecorded development.

.DESCRIPTION
  Assumes Android Studio is installed (SDK + at least one AVD).
  For dev containers, Docker Desktop is also started unless -SkipDocker is set.

.EXAMPLE
  .\Start-UnrecordedDev.ps1

.EXAMPLE
  .\Start-UnrecordedDev.ps1 -AvdName Pixel_6_API_34 -OpenCursor
#>
[CmdletBinding()]
param(
  [string] $AvdName,
  [switch] $SkipDocker,
  [switch] $SkipEmulator,
  [switch] $RestartEmulator,
  [switch] $OpenCursor,
  [switch] $ListAvds,
  [switch] $NoPause
)

$ErrorActionPreference = 'Stop'

function Write-Step([string] $Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string] $Message) {
  Write-Host "    $Message" -ForegroundColor Green
}

function Write-Warn([string] $Message) {
  Write-Host "    WARNING: $Message" -ForegroundColor Yellow
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

function Get-RepoRoot {
  $here = $PSScriptRoot
  if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
  return (Resolve-Path (Join-Path $here '..\..')).Path
}

function Test-DockerRunning {
  $null = docker info 2>&1
  return $LASTEXITCODE -eq 0
}

function Start-DockerDesktop {
  if (Test-DockerRunning) {
    Write-Ok 'Docker is already running.'
    return
  }

  $candidates = @(
    "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe",
    "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
    "$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop.exe",
    "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
  )

  $exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $exe) {
    throw 'Docker Desktop not found. Install it for dev containers, or pass -SkipDocker.'
  }

  Write-Step 'Starting Docker Desktop'
  Start-Process -FilePath $exe | Out-Null

  $timeoutSec = 180
  $elapsed = 0
  while ($elapsed -lt $timeoutSec) {
    if (Test-DockerRunning) {
      Write-Ok "Docker ready (${elapsed}s)."
      return
    }
    Start-Sleep -Seconds 3
    $elapsed += 3
    Write-Host "    waiting for Docker ... ${elapsed}s" -ForegroundColor DarkGray
  }

  throw "Docker did not become ready within ${timeoutSec}s. Start Docker Desktop manually."
}

function Get-AvdList {
  param([string] $EmulatorExe)
  $raw = & $EmulatorExe -list-avds 2>&1
  if ($LASTEXITCODE -ne 0) { throw "emulator -list-avds failed: $raw" }
  return @($raw | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
}

function Get-RunningEmulatorSerials {
  param([string] $Adb)
  $serials = @()
  $lines = & $Adb devices 2>&1 | Where-Object { $_ -match '^\S+\s+device' }
  foreach ($line in $lines) {
    $serial = ($line -split '\s+', 2)[0]
    if ($serial -match '^emulator-\d+$') { $serials += $serial }
  }
  return $serials
}

function Stop-AllEmulators {
  param([string] $Adb)
  foreach ($serial in (Get-RunningEmulatorSerials -Adb $Adb)) {
    Write-Host "    stopping $serial" -ForegroundColor DarkGray
    & $Adb -s $serial emu kill 2>$null
  }
  Start-Sleep -Seconds 3
}

function Wait-EmulatorBoot {
  param(
    [string] $Adb,
    [string] $ExpectedSerial = '',
    [int] $TimeoutSec = 300
  )

  Write-Step 'Waiting for emulator to boot'
  & $Adb wait-for-device | Out-Null

  $elapsed = 0
  while ($elapsed -lt $TimeoutSec) {
    if ($ExpectedSerial) {
      $state = (& $Adb -s $ExpectedSerial get-state 2>$null)
      if ($state -ne 'device') {
        Start-Sleep -Seconds 2
        $elapsed += 2
        continue
      }
      $boot = & $Adb -s $ExpectedSerial shell getprop sys.boot_completed 2>$null
    } else {
      $boot = & $Adb shell getprop sys.boot_completed 2>$null
    }

    if (($boot | Out-String).Trim() -match '1') {
      Write-Ok "Emulator booted (${elapsed}s)."
      return
    }

    Start-Sleep -Seconds 2
    $elapsed += 2
    if ($elapsed % 10 -eq 0) {
      Write-Host "    booting ... ${elapsed}s" -ForegroundColor DarkGray
    }
  }

  throw "Emulator did not finish booting within ${TimeoutSec}s."
}

function Start-HostEmulator {
  param(
    [string] $SdkRoot,
    [string] $SelectedAvd
  )

  $emulator = Join-Path $SdkRoot 'emulator\emulator.exe'
  $adb = Join-Path $SdkRoot 'platform-tools\adb.exe'

  if (-not (Test-Path $emulator)) {
    throw "emulator.exe not found. In Android Studio: SDK Manager -> install Android Emulator."
  }
  if (-not (Test-Path $adb)) {
    throw "adb.exe not found. In Android Studio: SDK Manager -> install Android SDK Platform-Tools."
  }

  Write-Step 'Starting adb on host'
  & $adb start-server | Out-Null

  if ($RestartEmulator) {
    Write-Step 'Stopping existing emulators'
    Stop-AllEmulators -Adb $adb
  }

  $running = Get-RunningEmulatorSerials -Adb $adb
  if ($running.Count -gt 0 -and -not $RestartEmulator) {
    $serial = $running[0]
    Write-Ok "Reusing running emulator: $serial"
    Wait-EmulatorBoot -Adb $adb -ExpectedSerial $serial
    return @{ Adb = $adb; Serial = $serial; Port = 5555 }
  }

  Write-Step "Launching AVD: $SelectedAvd"
  $emuArgs = @('-avd', $SelectedAvd, '-no-snapshot-load')
  Start-Process -FilePath $emulator -ArgumentList $emuArgs -WindowStyle Minimized | Out-Null

  Wait-EmulatorBoot -Adb $adb

  $serials = Get-RunningEmulatorSerials -Adb $adb
  if ($serials.Count -eq 0) {
    throw 'Emulator started but adb does not list an emulator device.'
  }

  $serial = $serials[0]
  Write-Ok "Emulator serial: $serial"
  Write-Ok 'adb devices:'
  & $adb devices -l

  return @{ Adb = $adb; Serial = $serial; Port = 5555 }
}

# --- main ---
try {
  $repoRoot = Get-RepoRoot
  Set-Location $repoRoot
  Write-Step "Unrecorded dev host bootstrap"
  Write-Ok "Repo: $repoRoot"

  $sdk = Resolve-AndroidSdk
  Write-Ok "Android SDK: $sdk"

  $emulatorExe = Join-Path $sdk 'emulator\emulator.exe'
  $avds = Get-AvdList -EmulatorExe $emulatorExe

  if ($ListAvds) {
    Write-Step 'Available AVDs'
    if ($avds.Count -eq 0) {
      Write-Warn 'No AVDs. Create one in Android Studio -> Device Manager (API 30+, x86_64).'
    } else {
      $avds | ForEach-Object { Write-Host "    $_" }
    }
    exit 0
  }

  if ($avds.Count -eq 0) {
    throw 'No AVDs found. Create one in Android Studio -> Device Manager (API 30+, x86_64).'
  }

  if ($AvdName) {
    if ($avds -notcontains $AvdName) {
      throw "AVD '$AvdName' not found. Available: $($avds -join ', '). Use -ListAvds."
    }
  } else {
    $AvdName = $avds[0]
    Write-Ok "Using AVD: $AvdName (first available; use -AvdName to pick another)"
  }

  if (-not $SkipDocker) {
    Start-DockerDesktop
  } else {
    Write-Warn 'Skipping Docker (-SkipDocker).'
  }

  $emulatorInfo = $null
  if (-not $SkipEmulator) {
    $emulatorInfo = Start-HostEmulator -SdkRoot $sdk -SelectedAvd $AvdName
  } else {
    Write-Warn 'Skipping emulator (-SkipEmulator).'
    $adb = Join-Path $sdk 'platform-tools\adb.exe'
    if (Test-Path $adb) { & $adb start-server | Out-Null }
  }

  if ($OpenCursor) {
    $cursor = Get-Command cursor -ErrorAction SilentlyContinue
    if ($cursor) {
      Write-Step 'Opening Cursor'
      Start-Process -FilePath $cursor.Source -ArgumentList @($repoRoot) | Out-Null
    } else {
      Write-Warn 'cursor CLI not on PATH; open the repo manually in Cursor.'
    }
  }

  Write-Step 'Next steps'
  $bridgePort = if ($emulatorInfo) { $emulatorInfo.Port } else { 5555 }
  Write-Host @"

  Dev container:
    1. Open this folder in Cursor / VS Code
    2. Command Palette -> Dev Containers: Reopen in Container
    3. In the container terminal:
         .devcontainer/scripts/connect-host-emulator.sh
         cd apps/mobile && flutter run

  Local Flutter (if installed on Windows):
    cd apps/mobile
    flutter pub get
    flutter run

  Container adb bridge port: $bridgePort (host.docker.internal)

"@ -ForegroundColor White

  Write-Ok 'Host bootstrap complete.'
}
catch {
  Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
finally {
  if (-not $NoPause -and $Host.Name -eq 'ConsoleHost' -and $env:TERM -ne 'dumb') {
    $caller = (Get-PSCallStack)[1].Command
    if ($caller -match '\.cmd$|cmd\.exe') {
      Write-Host "`nPress Enter to close ..."
      [void][System.Console]::ReadLine()
    }
  }
}
