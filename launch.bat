@echo off
setlocal

REM ==================================================================
REM Portable AI USB - launcher
REM
REM Requests Administrator rights ONCE, right at startup (a single UAC
REM prompt), then runs setup.ps1 fully elevated. This means every step
REM inside setup.ps1 - including trusting Caddy's local HTTPS
REM certificate - already has admin rights and won't prompt again.
REM ==================================================================

REM Check whether we're already elevated.
net session >nul 2>&1
if %errorLevel% == 0 goto :run

echo Requesting administrator privileges...
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b

:run
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"

echo.
echo (Window stays open - press any key to close.)
pause >nul
