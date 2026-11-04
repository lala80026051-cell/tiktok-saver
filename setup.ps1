# SETUP for TikTok Saver. Double-click setup.bat to run this (do not run this file by hand).
#
# What it does, once, on a new computer:
#   1. Checks that Node.js is installed.
#   2. Installs the website parts (npm install).
#   3. Downloads two free helper programs into the "tools" folder of this project:
#        - yt-dlp.exe  (saves the videos)        from github.com/yt-dlp/yt-dlp
#        - ffmpeg.exe  (writes captions on them) from github.com/yt-dlp/FFmpeg-Builds
#      Each download is checked against the official checksum. A file that does not match is deleted.
# It asks before it downloads anything.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # much faster downloads in Windows PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = $PSScriptRoot
$toolsDir = Join-Path $root 'tools'
$ytdlpDir = Join-Path $toolsDir 'yt-dlp'
$ffmpegDir = Join-Path $toolsDir 'ffmpeg'
$ytdlpExe = Join-Path $ytdlpDir 'yt-dlp.exe'
$ffmpegExe = Join-Path $ffmpegDir 'ffmpeg.exe'

function Step($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Yellow }
function Fail($text) { Write-Host ''; Write-Host "PROBLEM: $text" -ForegroundColor Red; exit 1 }

# Downloads a file and checks it against the official checksum list. Deletes it if it does not match.
function Get-CheckedFile([string]$FileUrl, [string]$SumsUrl, [string]$NameInSums, [string]$OutFile) {
  $sumsFile = Join-Path ([IO.Path]::GetTempPath()) ('tiktok-saver-sums-' + [guid]::NewGuid().ToString('N') + '.txt')
  try {
    Invoke-WebRequest -Uri $SumsUrl -OutFile $sumsFile -UseBasicParsing
    $line = Get-Content $sumsFile | Where-Object { $_ -match ([regex]::Escape($NameInSums) + '\s*$') } | Select-Object -First 1
    if (-not $line) { throw "The official checksum list has no entry for $NameInSums." }
    $wanted = ($line.Trim() -split '\s+')[0].ToLower()

    Invoke-WebRequest -Uri $FileUrl -OutFile $OutFile -UseBasicParsing
    $got = (Get-FileHash -Path $OutFile -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $wanted) {
      Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
      throw "The downloaded $NameInSums does NOT match the official checksum, so it was deleted."
    }
    Write-Host "   checked: the file matches the official checksum" -ForegroundColor Green
  }
  finally {
    Remove-Item -LiteralPath $sumsFile -Force -ErrorAction SilentlyContinue
  }
}

Write-Host ''
Write-Host '====================  TikTok Saver setup  ====================' -ForegroundColor Yellow
Write-Host 'This runs once on a new computer. It will:'
Write-Host '  1. check that Node.js is installed,'
Write-Host '  2. install the website parts (npm install),'
Write-Host '  3. download two free helper programs into the "tools" folder of this project:'
Write-Host '       - yt-dlp.exe   about 22 MB   from https://github.com/yt-dlp/yt-dlp'
Write-Host '       - ffmpeg       about 193 MB  from https://github.com/yt-dlp/FFmpeg-Builds'
Write-Host '     (ffmpeg is skipped if this computer already has it.)'
Write-Host '  4. put a "TikTok Saver" icon on your Desktop, so you can open the app with a double-click.'
Write-Host 'Each download is checked against the official checksum.'
Write-Host ''
$answer = Read-Host 'Type Y and press Enter to continue. Anything else stops, and nothing is downloaded'
if ($answer -notmatch '^[Yy]') { Write-Host 'Stopped. Nothing was downloaded.'; exit 0 }

# ---- 1. Node.js ----
Step '1/3  Checking Node.js'
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  Write-Host 'Node.js is not installed. It is free. Install the "LTS" version, then double-click setup.bat again:'
  Write-Host '   https://nodejs.org'
  Write-Host '   (or in PowerShell: winget install OpenJS.NodeJS.LTS)'
  Start-Process 'https://nodejs.org'
  Fail 'Node.js is missing.'
}
$nodeVersion = (& node --version).Trim()
$major = [int](($nodeVersion -replace '^v', '') -split '\.')[0]
Write-Host "   Node.js $nodeVersion found"
if ($major -lt 22) { Write-Host '   Warning: this version is old. If the website does not start, install the newest LTS from https://nodejs.org' -ForegroundColor Yellow }

# ---- 2. Website parts ----
Step '2/3  Installing the website parts'
if (Test-Path (Join-Path $root 'node_modules')) {
  Write-Host '   already installed'
} else {
  Push-Location $root
  try { & npm.cmd install } finally { Pop-Location }
  if ($LASTEXITCODE -ne 0) { Fail 'npm install did not work. Check your internet and try again.' }
}

# ---- 3. Helper programs ----
Step '3/3  Downloading the helper programs'
New-Item -ItemType Directory -Force -Path $ytdlpDir, $ffmpegDir | Out-Null

# yt-dlp
if (Test-Path $ytdlpExe) {
  Write-Host '   yt-dlp is already there'
} else {
  Write-Host '   downloading yt-dlp.exe (about 22 MB) ...'
  try {
    Get-CheckedFile 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' `
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS' 'yt-dlp.exe' $ytdlpExe
  } catch { Fail $_.Exception.Message }
}

# ffmpeg
$ffmpegOnPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (Test-Path $ffmpegExe) {
  Write-Host '   ffmpeg is already there'
} elseif ($ffmpegOnPath) {
  Write-Host "   ffmpeg is already on this computer ($($ffmpegOnPath.Source)). It will be used, so nothing is downloaded."
} else {
  Write-Host '   downloading ffmpeg (about 193 MB). This can take a few minutes ...'
  $zip = Join-Path ([IO.Path]::GetTempPath()) ('tiktok-saver-ffmpeg-' + [guid]::NewGuid().ToString('N') + '.zip')
  $unzipped = Join-Path ([IO.Path]::GetTempPath()) ('tiktok-saver-ffmpeg-' + [guid]::NewGuid().ToString('N'))
  try {
    Get-CheckedFile 'https://github.com/yt-dlp/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip' `
      'https://github.com/yt-dlp/FFmpeg-Builds/releases/latest/download/checksums.sha256' 'ffmpeg-master-latest-win64-gpl.zip' $zip
    Write-Host '   unpacking ...'
    Expand-Archive -LiteralPath $zip -DestinationPath $unzipped -Force
    $found = Get-ChildItem -Path $unzipped -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
    if (-not $found) { throw 'ffmpeg.exe was not found inside the download.' }
    Copy-Item -LiteralPath $found.FullName -Destination $ffmpegExe -Force
  } catch { Fail $_.Exception.Message }
  finally {
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $unzipped -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# Check that the helper programs really start, and that ffmpeg can write captions.
Step 'Checking the helper programs'
try {
  $ytVersion = (& $ytdlpExe --version).Trim()
  Write-Host "   yt-dlp works (version $ytVersion)" -ForegroundColor Green
} catch { Fail 'yt-dlp was downloaded but does not start.' }

$ff = if (Test-Path $ffmpegExe) { $ffmpegExe } elseif ($ffmpegOnPath) { $ffmpegOnPath.Source } else { $null }
if ($ff) {
  try {
    $filters = (& $ff -hide_banner -filters 2>&1 | Out-String)
    $build = (& $ff -hide_banner -buildconf 2>&1 | Out-String)
    if ($filters -match ' subtitles ') { Write-Host '   ffmpeg works, and it can write captions' -ForegroundColor Green }
    else { Write-Host '   ffmpeg works, but it cannot write captions. Videos will still be saved.' -ForegroundColor Yellow }
    if ($build -notmatch 'libharfbuzz') { Write-Host '   Note: this ffmpeg may draw Khmer letters badly in captions.' -ForegroundColor Yellow }
  } catch { Write-Host '   ffmpeg did not start. Videos will be saved, but without captions.' -ForegroundColor Yellow }
}

# ---- The Desktop icon ----
Step 'Putting a TikTok Saver icon on your Desktop'
$iconMade = $false
try {
  & (Join-Path $root 'make-shortcut.ps1')
  $iconMade = $true
} catch {
  Write-Host "   The icon could not be made ($($_.Exception.Message)). You can still double-click start.bat." -ForegroundColor Yellow
}

Write-Host ''
Write-Host '====================  All done!  ====================' -ForegroundColor Green
if ($iconMade) {
  Write-Host 'Now double-click the  TikTok Saver  icon on your Desktop to open the app.'
  Write-Host '(If you move this folder, run setup.bat again to make a new icon.)'
} else {
  Write-Host 'Now double-click  start.bat  to open TikTok Saver.'
}
Write-Host ''
