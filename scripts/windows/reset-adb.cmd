@echo off
setlocal
title Unrecorded adb reset

REM Kill stale adb processes and start a fresh server (Android Studio SDK required).
REM Double-click this file or run from cmd: scripts\windows\reset-adb.cmd

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Reset-Adb.ps1" %*
set EXITCODE=%ERRORLEVEL%

if %EXITCODE% neq 0 (
  echo.
  echo adb reset failed with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)

exit /b 0
