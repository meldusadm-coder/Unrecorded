@echo off
REM Convenience launcher from repo root -> scripts\windows\start-unrecorded-dev.cmd
cd /d "%~dp0"
call "%~dp0scripts\windows\start-unrecorded-dev.cmd" %*
