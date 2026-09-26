@echo off
rem Double-click to live-sync this folder into Roblox Studio.
rem Keep this window open while you work, then press Connect in the Rojo plugin.
title Rojo - Survive the Wolverine
cd /d "%~dp0"
if exist "%~dp0rojo.exe" (
  "%~dp0rojo.exe" serve
) else (
  where rojo >/dev/null 2>nul
  if errorlevel 1 (
    echo Rojo is not installed on this PC.
    echo.
    echo 1. Go to https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0
    echo 2. Download rojo-7.7.0-windows-x86_64.zip
    echo 3. Unzip it and put rojo.exe in this folder, next to this file
    echo 4. Double-click this file again
  ) else (
    rojo serve
  )
)
echo.
echo Rojo stopped. Read the message above, then press any key to close.
pause >nul
