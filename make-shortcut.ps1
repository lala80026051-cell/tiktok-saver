# Makes a "TikTok Saver" icon on the Desktop. Double-clicking it opens the app (it runs start.bat).
# setup.ps1 runs this at the end. You can also run it by hand if you moved the folder:
#   powershell -ExecutionPolicy Bypass -File make-shortcut.ps1
#
# It draws a small gold-on-red icon (an original shape, no file is downloaded), saves it in the
# "tools" folder, and creates the shortcut. The Desktop folder is found from Windows itself, so it
# also works when the Desktop is kept in OneDrive.
param(
  # The Desktop folder. (TIKTOK_SAVER_DESKTOP is only for testing: it lets a test use another folder.)
  [string]$DesktopDir = $(if ($env:TIKTOK_SAVER_DESKTOP) { $env:TIKTOK_SAVER_DESKTOP } else { [Environment]::GetFolderPath('Desktop') }),
  [string]$ProjectDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$startBat = Join-Path $ProjectDir 'start.bat'
if (-not (Test-Path $startBat)) { throw "start.bat was not found in $ProjectDir" }
if (-not (Test-Path $DesktopDir)) { throw "The Desktop folder was not found: $DesktopDir" }

# ---- 1. The icon (256 x 256, saved inside an .ico file) ----
$toolsDir = Join-Path $ProjectDir 'tools'
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
$icoPath = Join-Path $toolsDir 'tiktok-saver.ico'

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# A rounded dark-red square.
$r = 52; $d = $r * 2
$square = New-Object System.Drawing.Drawing2D.GraphicsPath
$square.AddArc(0, 0, $d, $d, 180, 90)
$square.AddArc($size - $d, 0, $d, $d, 270, 90)
$square.AddArc($size - $d, $size - $d, $d, $d, 0, 90)
$square.AddArc(0, $size - $d, $d, $d, 90, 90)
$square.CloseFigure()
$red = New-Object System.Drawing.Drawing2D.LinearGradientBrush ([System.Drawing.Point]::new(0, 0)), ([System.Drawing.Point]::new($size, $size)), ([System.Drawing.Color]::FromArgb(122, 24, 40)), ([System.Drawing.Color]::FromArgb(37, 7, 12))
$g.FillPath($red, $square)

# The logo: the gold flame emblem. It is drawn with the same curves as public/favicon.svg
# (a 120 x 150 drawing), scaled to fit inside the square.
$k = 1.32                       # how much bigger than the 120 x 150 drawing
$ox = 128 - 60 * $k             # moves the drawing so its middle is in the middle of the icon
$oy = 128 - 74 * $k
function P([double]$x, [double]$y) { [System.Drawing.PointF]::new([single]($x * $k + $ox), [single]($y * $k + $oy)) }

# A closed shape made of curves. Each curve is 4 points: start, two guides, end.
function New-CurveShape($curves) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  foreach ($c in $curves) { $path.AddBezier((P $c[0] $c[1]), (P $c[2] $c[3]), (P $c[4] $c[5]), (P $c[6] $c[7])) }
  $path.CloseFigure()
  return $path
}

$gold = New-Object System.Drawing.Drawing2D.LinearGradientBrush ([System.Drawing.PointF]::new(0, [single](6 * $k + $oy))), ([System.Drawing.PointF]::new(0, [single](142 * $k + $oy))), ([System.Drawing.Color]::FromArgb(255, 241, 184)), ([System.Drawing.Color]::FromArgb(185, 130, 42))
$dark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(58, 11, 18))

# The two curls on the sides.
$g.FillPath($gold, (New-CurveShape @(@(24,98, 6,94, -2,72, 8,50), @(8,50, 11,66, 19,75, 31,79))))
$g.FillPath($gold, (New-CurveShape @(@(96,98, 114,94, 122,72, 112,50), @(112,50, 109,66, 101,75, 89,79))))
# The big pointed teardrop, a dark teardrop inside it, and a gold one inside that.
$g.FillPath($gold, (New-CurveShape @(@(60,6, 74,36, 96,54, 96,88), @(96,88, 96,118, 80,142, 60,142), @(60,142, 40,142, 24,118, 24,88), @(24,88, 24,54, 46,36, 60,6))))
$g.FillPath($dark, (New-CurveShape @(@(60,30, 70,52, 84,64, 84,88), @(84,88, 84,108, 74,124, 60,124), @(60,124, 46,124, 36,108, 36,88), @(36,88, 36,64, 50,52, 60,30))))
$g.FillPath($gold, (New-CurveShape @(@(60,54, 66,68, 74,76, 74,90), @(74,90, 74,102, 68,112, 60,112), @(60,112, 52,112, 46,102, 46,90), @(46,90, 46,76, 54,68, 60,54))))
# The small dark dot in the middle.
$g.FillEllipse($dark, [single](55 * $k + $ox), [single](87 * $k + $oy), [single](10 * $k), [single](10 * $k))
$g.Dispose()

# An .ico file can hold a PNG picture: a small header, one entry, then the PNG itself.
$png = New-Object System.IO.MemoryStream
$bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$pngBytes = $png.ToArray()
$ico = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter($ico)
$w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]1)               # header: 1 picture
$w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0)   # 256 x 256 (written as 0), no palette
$w.Write([UInt16]1); $w.Write([UInt16]32)                                    # 1 plane, 32 bits
$w.Write([UInt32]$pngBytes.Length); $w.Write([UInt32]22)                     # size and position of the PNG
$w.Write($pngBytes)
$w.Flush()
[System.IO.File]::WriteAllBytes($icoPath, $ico.ToArray())

# ---- 2. The shortcut on the Desktop ----
$shell = New-Object -ComObject WScript.Shell
$linkPath = Join-Path $DesktopDir 'TikTok Saver.lnk'
$link = $shell.CreateShortcut($linkPath)
$link.TargetPath = $startBat
$link.WorkingDirectory = $ProjectDir
$link.IconLocation = "$icoPath,0"
$link.Description = 'Open TikTok Saver'
$link.Save()

Write-Host "   shortcut made: $linkPath" -ForegroundColor Green
