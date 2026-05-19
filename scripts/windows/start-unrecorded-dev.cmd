@echo off
setlocal
title Unrecorded dev bootstrap

REM Start Docker Desktop, Android emulator, and adb (Android Studio required).
REM Double-click this file or run from cmd: scripts\windows\start-unrecorded-dev.cmd

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-UnrecordedDev.ps1" %*
set EXITCODE=%ERRORLEVEL%

if %EXITCODE% neq 0 (
  echo.
  echo Bootstrap failed with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)

exit /b 0
