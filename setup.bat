@echo off
rem Double-click this file ONCE on a new computer.
rem It checks Node.js, installs the website parts, and downloads the two helper programs
rem (yt-dlp and ffmpeg) into the "tools" folder. It asks before it downloads anything.
rem
rem "-ExecutionPolicy Bypass" applies only to this one run of setup.ps1. It does not change any
rem setting of your computer.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
pause
