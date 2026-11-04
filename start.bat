@echo off
rem Double-click this file to start TikTok Saver.
rem It opens two windows: the helper (saves the videos) and the website.
rem Keep both windows open while you use the page. Close them when you are done.
cd /d "%~dp0"

rem The helper programs (yt-dlp) come from setup.bat. Run that first on a new computer.
if not exist "tools\yt-dlp\yt-dlp.exe" if not exist "..\tools\yt-dlp\yt-dlp.exe" (
  echo The helper programs are not installed yet.
  echo Please double-click setup.bat first. Then double-click start.bat again.
  echo.
  pause
  exit /b 1
)

if not exist node_modules (
  echo First time: installing the website parts. Please wait...
  call npm.cmd install
)

start "TikTok Saver - helper" cmd /k npm.cmd run helper
start "TikTok Saver - website" cmd /k npm.cmd run dev -- --open
