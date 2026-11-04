@echo off
rem Double-click this file to let a PHONE or ANOTHER COMPUTER on the same Wi-Fi use TikTok Saver.
rem
rem What it does:
rem   1. Makes a random 6-digit code. Any other device must type this code.
rem   2. Starts the helper (the videos are made on THIS computer and saved here).
rem   3. Starts the website so that other devices on your Wi-Fi can open it.
rem
rem Only use this on a Wi-Fi you trust (your home). Close the two black windows to stop sharing.
rem The first time, Windows may ask to allow Node.js on the network. Choose PRIVATE networks only.
cd /d "%~dp0"

if not exist node_modules (
  echo First time: installing the website parts. Please wait...
  call npm.cmd install
)

rem A random 6-digit code.
for /f %%i in ('powershell -NoProfile -Command "Get-Random -Minimum 100000 -Maximum 999999"') do set SAVER_PIN=%%i

rem The address of this computer on your home network (not a VPN or a virtual adapter).
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' -and $_.InterfaceAlias -notmatch 'VPN|WireGuard|Surfshark|Virtual|vEthernet|Loopback|Bluetooth' } | Select-Object -First 1).IPAddress"`) do set LAN_IP=%%i

start "TikTok Saver - helper (do not close)" cmd /k npm.cmd run helper
start "TikTok Saver - website (do not close)" cmd /k npm.cmd run dev -- --host --port 4323

echo.
echo ==============================================================
echo   TikTok Saver is shared on your Wi-Fi
echo.
echo   On the phone or the other computer, open this address:
echo       http://%LAN_IP%:4323
echo.
echo   When it asks, type this code:
echo       %SAVER_PIN%
echo.
echo   Close the two other black windows to stop sharing.
echo ==============================================================
echo.
pause
