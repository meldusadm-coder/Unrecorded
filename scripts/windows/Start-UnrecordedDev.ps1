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
  [switch] $ColdBoot,
  [switch] $OpenCursor,
  [switch] $ListAvds,
  [switch] $NoPause
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Reset-Adb.ps1"

function Write-Step([string] $Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string] $Message) {
  Write-Host "    $Message" -ForegroundColor Green
}

function Write-Warn([string] $Message) {
  Write-Host "    WARNING: $Message" -ForegroundColor Yellow
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

function Get-EmulatorAdbPort {
  param([string] $Serial)

  if ($Serial -match '^emulator-(\d+)$') {
    return [int]$Matches[1] + 1
  }
  return 5555
}

function Setup-ContainerAdbBridge {
  param(
    [string] $Adb,
    [string] $Serial,
    [int] $ListenPort = 5555
  )

  $adbPort = Get-EmulatorAdbPort -Serial $Serial
  Write-Step "Exposing emulator to dev container (port ${ListenPort})"

  # adb -a is also applied in Reset-Adb; ensure server accepts remote clients.
  $null = Invoke-AdbQuiet -Adb $Adb -a start-server

  # Forward 0.0.0.0:ListenPort -> 127.0.0.1:adbPort for adb connect host.docker.internal:ListenPort
  $delete = netsh interface portproxy delete v4tov4 listenport=$ListenPort listenaddress=0.0.0.0 2>&1
  $add = netsh interface portproxy add v4tov4 listenport=$ListenPort listenaddress=0.0.0.0 connectport=$adbPort connectaddress=127.0.0.1 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Warn "portproxy failed (run PowerShell as Administrator?). Container may still work via ADB_SERVER_SOCKET on port 5037."
    if ($add) { Write-Host "    $add" -ForegroundColor DarkGray }
    return
  }
  Write-Ok "portproxy 0.0.0.0:${ListenPort} -> 127.0.0.1:${adbPort}"
}

function Get-RunningEmulatorSerials {
  param([string] $Adb)

  $result = Invoke-AdbQuiet -Adb $Adb devices
  if ($result.ExitCode -ne 0) { return @() }

  $serials = @()
  foreach ($line in ($result.Output -split "`n")) {
    if ($line -match '^(\S+)\s+device') {
      $serial = $Matches[1]
      if ($serial -match '^emulator-\d+$') { $serials += $serial }
    }
  }
  return $serials
}

function Test-EmulatorProcessRunning {
  foreach ($name in @('emulator', 'qemu-system-x86_64-headless', 'qemu-system-x86_64')) {
    if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
      return $true
    }
  }
  return $false
}

function Wait-EmulatorBoot {
  param(
    [string] $Adb,
    [string] $ExpectedSerial = '',
    [int] $TimeoutSec = 300,
    [switch] $RequireEmulatorProcess
  )

  Write-Step 'Waiting for emulator to boot'

  $elapsed = 0
  $interval = 3
  $lastStatus = ''

  while ($elapsed -lt $TimeoutSec) {
    if ($RequireEmulatorProcess -and -not (Test-EmulatorProcessRunning)) {
      $devices = (Invoke-AdbQuiet -Adb $Adb devices).Output
      throw @"
Emulator process exited before adb connected.
  adb devices:
$devices
  Open Android Studio -> Device Manager and start the AVD manually to see the error.
  Or retry with: .\scripts\windows\Start-UnrecordedDev.ps1 -RestartEmulator
"@
    }

    $serials = Get-RunningEmulatorSerials -Adb $Adb
    $serial = ''

    if ($ExpectedSerial -and ($serials -contains $ExpectedSerial)) {
      $serial = $ExpectedSerial
    }
    elseif (-not $ExpectedSerial -and $serials.Count -gt 0) {
      $serial = $serials[0]
    }

    if ($serial) {
      $state = (Invoke-AdbQuiet -Adb $Adb -s $serial get-state).Output
      if ($state -eq 'device') {
        $boot = (Invoke-AdbQuiet -Adb $Adb -s $serial shell getprop sys.boot_completed).Output
        if ($boot -match '1') {
          Write-Ok "Emulator booted (${elapsed}s)."
          return $serial
        }
        $status = 'android starting'
      }
      else {
        $status = "adb state: $state"
      }
    }
    else {
      $status = if (Test-EmulatorProcessRunning) { 'emulator running, waiting for adb' } else { 'waiting for emulator' }
    }

    if ($status -ne $lastStatus -or ($elapsed -gt 0 -and $elapsed % 15 -eq 0)) {
      Write-Host "    ${status} ... ${elapsed}s" -ForegroundColor DarkGray
      $lastStatus = $status
    }

    Start-Sleep -Seconds $interval
    $elapsed += $interval
  }

  $devices = (Invoke-AdbQuiet -Adb $Adb devices).Output
  throw @"
Emulator did not finish booting within ${TimeoutSec}s.
  adb devices:
$devices
  Try starting the AVD from Android Studio -> Device Manager.
  First boot can take several minutes; retry or use -RestartEmulator if it stays stuck.
"@
}

function Stop-AllEmulators {
  param([string] $Adb)
  foreach ($serial in (Get-RunningEmulatorSerials -Adb $Adb)) {
    Write-Host "    stopping $serial" -ForegroundColor DarkGray
    & $Adb -s $serial emu kill 2>$null
  }
  Start-Sleep -Seconds 3
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

  Reset-AdbServer -Adb $adb

  if ($RestartEmulator) {
    Write-Step 'Stopping existing emulators'
    Stop-AllEmulators -Adb $adb
  }

  $running = Get-RunningEmulatorSerials -Adb $adb
  if ($running.Count -gt 0 -and -not $RestartEmulator) {
    $serial = $running[0]
    Write-Ok "Reusing running emulator: $serial"
    Wait-EmulatorBoot -Adb $adb -ExpectedSerial $serial
    Setup-ContainerAdbBridge -Adb $adb -Serial $serial
    return @{ Adb = $adb; Serial = $serial; Port = 5555 }
  }

  Write-Step "Launching AVD: $SelectedAvd"
  $emuArgs = @('-avd', $SelectedAvd)
  if ($ColdBoot -or $RestartEmulator) {
    $emuArgs += '-no-snapshot-load'
    Write-Host '    cold boot (no snapshot)' -ForegroundColor DarkGray
  }

  Start-Process -FilePath $emulator -ArgumentList $emuArgs -WindowStyle Normal | Out-Null
  Write-Ok 'Emulator window opened (first boot can take a few minutes)'

  $serial = Wait-EmulatorBoot -Adb $adb -RequireEmulatorProcess
  Write-Ok "Emulator serial: $serial"
  Write-Ok 'adb devices:'
  & $adb devices -l

  Setup-ContainerAdbBridge -Adb $adb -Serial $serial
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
    if (Test-Path $adb) { Reset-AdbServer -Adb $adb }
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
         ./scripts/dev-run.sh

    Or press F5 -> Unrecorded (mobile)

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
