using namespace System.Drawing
using namespace System.Drawing.Drawing2D

# Makes the how-to video for the Start here page:
#   public\how-to-setup.mp4         a silent, step-by-step video (540 x 960, about one minute)
#   public\how-to-setup-poster.jpg  the picture shown before the video plays
#
# Everything is drawn by this program from simple shapes (nothing is copied), and the captions come
# from video\captions.json (English + Khmer). It needs ffmpeg. Run it by hand when you change a caption:
#   powershell -ExecutionPolicy Bypass -File video\make-video.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$here = $PSScriptRoot
$root = Split-Path $here -Parent
$build = Join-Path $here 'build'
$publicDir = Join-Path $root 'public'
$W = 540; $H = 960; $FPS = 24
New-Item -ItemType Directory -Force -Path $build | Out-Null

# ---- find ffmpeg ----
$ffmpeg = $null
foreach ($c in @($env:FFMPEG_PATH, (Join-Path $root 'tools\ffmpeg\ffmpeg.exe'), (Join-Path (Split-Path $root -Parent) 'tools\ffmpeg\ffmpeg.exe'))) {
  if ($c -and (Test-Path $c)) { $ffmpeg = $c; break }
}
if (-not $ffmpeg) { $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue; if ($cmd) { $ffmpeg = $cmd.Source } }
if (-not $ffmpeg) { throw 'ffmpeg was not found. Run setup.bat first.' }

# ---- small drawing helpers ----
function Col([int]$r, [int]$g, [int]$b, [int]$a = 255) { [Color]::FromArgb($a, $r, $g, $b) }
function Brush($c) { New-Object SolidBrush($c) }

function Rounded([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
  $p = New-Object GraphicsPath; $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure(); return $p
}
function FillR($g, $brush, $x, $y, $w, $h, $r) { $p = Rounded $x $y $w $h $r; $g.FillPath($brush, $p) }
function StrokeR($g, $pen, $x, $y, $w, $h, $r) { $p = Rounded $x $y $w $h $r; $g.DrawPath($pen, $p) }

function Txt($g, [string]$s, [string]$font, [single]$size, $style, $color, [single]$x, [single]$y, [single]$w, [single]$h, [string]$align = 'Center') {
  $f = New-Object Font($font, $size, $style, [GraphicsUnit]::Pixel)
  $sf = New-Object StringFormat; $sf.Alignment = [StringAlignment]$align; $sf.LineAlignment = [StringAlignment]::Center
  $g.DrawString($s, $f, (Brush $color), [RectangleF]::new($x, $y, $w, $h), $sf)
}

# The flame emblem (the same curves as public\favicon.svg), centred at ($cx, $cy), $height pixels tall.
function Emblem($g, [single]$cx, [single]$cy, [single]$height) {
  $k = $height / 136; $ox = $cx - 60 * $k; $oy = $cy - 74 * $k
  function Pt([double]$x, [double]$y) { [PointF]::new([single]($x * $k + $ox), [single]($y * $k + $oy)) }
  function Shape($curves) {
    $p = New-Object GraphicsPath
    foreach ($c in $curves) { $p.AddBezier((Pt $c[0] $c[1]), (Pt $c[2] $c[3]), (Pt $c[4] $c[5]), (Pt $c[6] $c[7])) }
    $p.CloseFigure(); return $p
  }
  $gold = New-Object LinearGradientBrush ([PointF]::new(0, [single](6 * $k + $oy))), ([PointF]::new(0, [single](142 * $k + $oy))), (Col 255 241 184), (Col 185 130 42)
  $dark = Brush (Col 90 18 32)
  $g.FillPath($gold, (Shape @(@(24,98, 6,94, -2,72, 8,50), @(8,50, 11,66, 19,75, 31,79))))
  $g.FillPath($gold, (Shape @(@(96,98, 114,94, 122,72, 112,50), @(112,50, 109,66, 101,75, 89,79))))
  $g.FillPath($gold, (Shape @(@(60,6, 74,36, 96,54, 96,88), @(96,88, 96,118, 80,142, 60,142), @(60,142, 40,142, 24,118, 24,88), @(24,88, 24,54, 46,36, 60,6))))
  $g.FillPath($dark, (Shape @(@(60,30, 70,52, 84,64, 84,88), @(84,88, 84,108, 74,124, 60,124), @(60,124, 46,124, 36,108, 36,88), @(36,88, 36,64, 50,52, 60,30))))
  $g.FillPath($gold, (Shape @(@(60,54, 66,68, 74,76, 74,90), @(74,90, 74,102, 68,112, 60,112), @(60,112, 52,112, 46,102, 46,90), @(46,90, 46,76, 54,68, 60,54))))
  $g.FillEllipse($dark, [single](55 * $k + $ox), [single](87 * $k + $oy), [single](10 * $k), [single](10 * $k))
}

function DiamondPoints([double]$cx, [double]$cy, [double]$half) {
  [PointF[]]@([PointF]::new($cx, $cy - $half), [PointF]::new($cx + $half, $cy), [PointF]::new($cx, $cy + $half), [PointF]::new($cx - $half, $cy))
}

# A scene: dark red background with a soft gold diamond lattice, and the brand at the top.
function New-Scene([bool]$withBrand = $true) {
  $bmp = New-Object Bitmap $W, $H
  $g = [Graphics]::FromImage($bmp)
  $g.SmoothingMode = [SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [Text.TextRenderingHint]::AntiAliasGridFit
  $bg = New-Object LinearGradientBrush ([Point]::new(0, 0)), ([Point]::new(0, $H)), (Col 74 15 24), (Col 37 7 12)
  $g.FillRectangle($bg, 0, 0, $W, $H)
  $pen = New-Object Pen((Col 224 169 59 36), 1.4)
  for ($x = -36; $x -lt $W + 72; $x += 72) { for ($y = -36; $y -lt $H + 72; $y += 72) { $g.DrawPolygon($pen, (DiamondPoints ($x + 36) ($y + 36) 33)) } }
  if ($withBrand) {
    Emblem $g 50 48 54
    Txt $g 'TikTok Saver' 'Segoe UI Semibold' 26 ([FontStyle]::Regular) (Col 246 221 145) 84 22 300 52 'Near'
    $gp = New-Object Pen((Col 224 169 59), 3); $g.DrawLine($gp, 0, 92, $W, 92)
  }
  return [pscustomobject]@{ Bmp = $bmp; G = $g }
}
function Save-Scene($scene, [string]$name) { $scene.G.Dispose(); $scene.Bmp.Save((Join-Path $build $name), [Imaging.ImageFormat]::Png); $scene.Bmp.Dispose() }

# A gold diamond with the step number, above the caption.
function Badge($g, [int]$n) {
  $gold = New-Object LinearGradientBrush ([Point]::new(230, 590)), ([Point]::new(310, 670)), (Col 255 241 184), (Col 185 130 42)
  $g.FillPolygon($gold, (DiamondPoints 270 628 40))
  Txt $g "$n" 'Segoe UI' 34 ([FontStyle]::Bold) (Col 58 11 18) 230 598 80 60 'Center'
}

function Window($g, [single]$x, [single]$y, [single]$w, [single]$h, [string]$title, [bool]$dark = $false) {
  FillR $g (Brush (Col 0 0 0 90)) ($x + 7) ($y + 9) $w $h 18
  $body = if ($dark) { Col 24 24 30 } else { Col 255 248 232 }
  $path = Rounded $x $y $w $h 18
  $g.FillPath((Brush $body), $path)
  $g.SetClip($path); $g.FillRectangle((Brush (Col 58 11 18)), $x, $y, $w, 38); $g.ResetClip()
  foreach ($i in 0..2) { $g.FillEllipse((Brush (Col 224 169 59)), $x + 16 + $i * 18, $y + 14, 10, 10) }
  Txt $g $title 'Segoe UI' 16 ([FontStyle]::Regular) (Col 246 221 145) ($x + 80) $y ($w - 100) 38 'Near'
  $g.DrawPath((New-Object Pen((Col 224 169 59), 3)), $path)
}

function Button($g, [string]$text, [single]$x, [single]$y, [single]$w, [single]$h, [single]$size = 22) {
  $red = New-Object LinearGradientBrush ([PointF]::new(0, $y)), ([PointF]::new(0, $y + $h)), (Col 179 38 58), (Col 111 18 32)
  $p = Rounded $x $y $w $h ($h / 2); $g.FillPath($red, $p); $g.DrawPath((New-Object Pen((Col 224 169 59), 2.5)), $p)
  Txt $g $text 'Segoe UI Semibold' $size ([FontStyle]::Regular) (Col 255 243 207) $x $y $w $h 'Center'
}

function Cursor($g, [single]$x, [single]$y) {
  $k = 1.9; $v = @(0,0, 0,19, 4.7,15, 8,22.5, 11,21, 7.8,14, 13.5,14); $pts = @()
  for ($i = 0; $i -lt $v.Count; $i += 2) { $pts += [PointF]::new([single]($x + $v[$i] * $k), [single]($y + $v[$i + 1] * $k)) }
  $g.FillPolygon((Brush (Col 255 255 255)), [PointF[]]$pts); $g.DrawPolygon((New-Object Pen((Col 30 30 30), 2)), [PointF[]]$pts)
}

function Arrow($g, [single]$x1, [single]$y, [single]$x2) {
  $pen = New-Object Pen((Col 224 169 59), 6); $pen.StartCap = [LineCap]::Round
  $g.DrawLine($pen, $x1, $y, $x2 - 12, $y)
  $g.FillPolygon((Brush (Col 224 169 59)), [PointF[]]@([PointF]::new($x2, $y), [PointF]::new($x2 - 26, $y - 16), [PointF]::new($x2 - 26, $y + 16)))
}

# ---------- the seven scenes ----------
function Scene-Title([string]$name) {
  $s = New-Scene $false; $g = $s.G
  $pen = New-Object Pen((Col 224 169 59), 6); $pen.LineJoin = [LineJoin]::Round
  $g.DrawPolygon($pen, (DiamondPoints 270 340 215))
  $g.DrawPolygon((New-Object Pen((Col 224 169 59 120), 2)), (DiamondPoints 270 340 235))
  Emblem $g 270 340 270
  Save-Scene $s $name
}

function Scene-Download {
  $s = New-Scene; $g = $s.G
  Window $g 50 130 440 330 'the website'
  foreach ($i in 0..2) { FillR $g (Brush (Col 58 11 18 55)) 82 (190 + $i * 26) (320 - $i * 70) 12 6 }
  Button $g 'Download the app' 110 300 320 64 24
  Cursor $g 360 345
  # a zip file  ->  a folder
  $zip = New-Object LinearGradientBrush ([PointF]::new(0, 500)), ([PointF]::new(0, 590)), (Col 255 241 184), (Col 201 146 47)
  FillR $g $zip 100 500 84 92 10
  foreach ($i in 0..8) { $g.FillRectangle((Brush (Col 90 18 32)), $(if ($i % 2) { 144 } else { 136 }), 500 + $i * 10, 8, 8) }
  Txt $g 'ZIP' 'Segoe UI' 20 ([FontStyle]::Bold) (Col 90 18 32) 100 560 84 30 'Center'
  Arrow $g 215 546 330
  $g.FillPath((Brush (Col 201 146 47)), (Rounded 352 512 112 82 10)); FillR $g (Brush (Col 201 146 47)) 352 498 48 24 6
  FillR $g (New-Object LinearGradientBrush ([PointF]::new(0, 524)), ([PointF]::new(0, 594)), (Col 255 241 184), (Col 214 160 60)) 352 524 112 70 10
  Badge $g 1
  Save-Scene $s 'scene1.png'
}

function Scene-Node {
  $s = New-Scene; $g = $s.G
  Window $g 70 130 400 400 'the Node.js website'
  FillR $g (Brush (Col 90 18 32)) 160 210 220 150 22
  StrokeR $g (New-Object Pen((Col 224 169 59), 4)) 160 210 220 150 22
  Txt $g 'Node.js' 'Segoe UI Semibold' 44 ([FontStyle]::Regular) (Col 246 221 145) 160 210 220 150 'Center'
  FillR $g (Brush (Col 224 169 59)) 336 192 66 32 16
  Txt $g 'LTS' 'Segoe UI' 20 ([FontStyle]::Bold) (Col 58 11 18) 336 192 66 32 'Center'
  Txt $g 'free' 'Segoe UI' 22 ([FontStyle]::Italic) (Col 90 18 32) 160 366 220 34 'Center'
  Button $g 'Install' 190 424 160 58 24
  Cursor $g 300 464
  Badge $g 2
  Save-Scene $s 'scene2.png'
}

function Scene-Setup {
  $s = New-Scene; $g = $s.G
  Window $g 50 120 440 240 'tiktok-saver'
  $rows = @(@('docs', $false), @('src', $false), @('setup.bat', $true), @('start.bat', $false))
  foreach ($i in 0..3) {
    $y = 168 + $i * 42
    if ($rows[$i][1]) { FillR $g (Brush (Col 224 169 59 120)) 62 $y 416 38 8 }
    FillR $g (Brush (Col 201 146 47)) 76 ($y + 8) 22 22 4
    Txt $g $rows[$i][0] 'Segoe UI Semibold' 22 ([FontStyle]::Regular) (Col 58 11 18) 110 $y 300 38 'Near'
  }
  Cursor $g 340 262
  Window $g 50 380 440 210 'setup' $true
  Txt $g 'Download 2 helper programs?' 'Consolas' 18 ([FontStyle]::Regular) (Col 220 220 220) 70 430 400 28 'Near'
  Txt $g 'Type Y and press Enter' 'Consolas' 18 ([FontStyle]::Regular) (Col 246 221 145) 70 462 400 28 'Near'
  Txt $g '> Y' 'Consolas' 24 ([FontStyle]::Bold) (Col 120 230 150) 70 510 120 36 'Near'
  Badge $g 3
  Save-Scene $s 'scene3.png'
}

function Scene-Desktop {
  $s = New-Scene; $g = $s.G
  $desk = New-Object LinearGradientBrush ([Point]::new(50, 120)), ([Point]::new(490, 580)), (Col 14 29 70), (Col 40 76 130)
  FillR $g $desk 50 120 440 460 18
  foreach ($i in 0..2) { FillR $g (Brush (Col 255 255 255 60)) 74 (150 + $i * 80) 52 52 10 }
  $g.FillRectangle((Brush (Col 12 12 20)), 50, 540, 440, 40)
  $g.FillEllipse((Brush (Col 246 221 145)), 66, 550, 20, 20)
  # the TikTok Saver icon, big, with a ring around it
  $ring = New-Object Pen((Col 246 221 145 160), 5); $g.DrawEllipse($ring, 195, 238, 170, 170)
  FillR $g (New-Object LinearGradientBrush ([Point]::new(210, 250)), ([Point]::new(350, 390)), (Col 122 24 40), (Col 37 7 12)) 210 250 140 140 30
  Emblem $g 280 320 106
  Txt $g 'TikTok Saver' 'Segoe UI Semibold' 24 ([FontStyle]::Regular) (Col 255 255 255) 190 408 180 36 'Center'
  Cursor $g 310 350
  Badge $g 4
  Save-Scene $s 'scene4.png'
}

function Scene-App {
  $s = New-Scene; $g = $s.G
  Window $g 40 120 460 470 'localhost:4323'
  $names = @('TikTok', 'YouTube', 'Facebook', 'Instagram'); $x = 58
  foreach ($i in 0..3) {
    $on = ($i -eq 0); $w = 98
    FillR $g (Brush $(if ($on) { Col 58 11 18 } else { Col 255 255 255 })) ($x + $i * 104) 168 $w 44 14
    StrokeR $g (New-Object Pen((Col 224 169 59), 2)) ($x + $i * 104) 168 $w 44 14
    Txt $g $names[$i] 'Segoe UI Semibold' 17 ([FontStyle]::Regular) $(if ($on) { Col 246 221 145 } else { Col 58 11 18 }) ($x + $i * 104) 168 $w 44 'Center'
  }
  FillR $g (Brush (Col 255 255 255)) 58 232 424 56 14
  StrokeR $g (New-Object Pen((Col 224 169 59), 2.5)) 58 232 424 56 14
  Txt $g 'https://www.tiktok.com/...' 'Segoe UI' 20 ([FontStyle]::Regular) (Col 130 110 100) 76 232 380 56 'Near'
  FillR $g (Brush (Col 58 11 18 40)) 58 308 424 40 10
  Txt $g 'Quality: Best available' 'Segoe UI' 18 ([FontStyle]::Regular) (Col 58 11 18) 74 308 380 40 'Near'
  Button $g 'Download 1 video' 110 372 320 62 24
  Cursor $g 380 414
  FillR $g (Brush (Col 228 243 234)) 58 462 424 64 14
  StrokeR $g (New-Object Pen((Col 31 95 74), 2.5)) 58 462 424 64 14
  $g.DrawLines((New-Object Pen((Col 31 95 74), 6)), [PointF[]]@([PointF]::new(84, 494), [PointF]::new(98, 508), [PointF]::new(122, 478)))
  Txt $g 'Finish download' 'Segoe UI Semibold' 24 ([FontStyle]::Regular) (Col 31 95 74) 134 462 320 64 'Near'
  Badge $g 5
  Save-Scene $s 'scene5.png'
}

function Scene-End {
  $s = New-Scene $false; $g = $s.G
  $pen = New-Object Pen((Col 224 169 59), 5); $pen.LineJoin = [LineJoin]::Round
  $g.DrawPolygon($pen, (DiamondPoints 270 320 190))
  Emblem $g 270 320 230
  Save-Scene $s 'scene6.png'
}

# ---------- draw the pictures ----------
Scene-Title 'scene0.png'; Scene-Download; Scene-Node; Scene-Setup; Scene-Desktop; Scene-App; Scene-End
Write-Host 'pictures drawn'

# ---------- the captions (ASS file: it draws Khmer and English correctly) ----------
$cap = Get-Content (Join-Path $here 'captions.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function AssTime([double]$t) { $ts = [TimeSpan]::FromSeconds($t); '{0}:{1:00}:{2:00}.{3:00}' -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds, [int]($ts.Milliseconds / 10) }
$lines = @(
  '[Script Info]', 'ScriptType: v4.00+', "PlayResX: $W", "PlayResY: $H", 'WrapStyle: 0', '',
  '[V4+ Styles]',
  'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
  'Style: Cap,Khmer UI,34,&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,3,1,8,28,28,672,1',
  'Style: Title,Khmer UI,40,&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,3,1,5,28,28,0,1',
  '', '[Events]', 'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text')
$t = 0.0
foreach ($scene in $cap.scenes) {
  $start = $t; $end = $t + [double]$scene.seconds; $t = $end
  $style = if ($scene.title) { 'Title' } else { 'Cap' }
  $pos = if ($scene.title) { '{\pos(270,700)}' } else { '' }
  $text = '{\fad(350,350)}' + $pos + '{\b1\fs36\c&H0091DDF6&}' + $scene.en + '\N{\fs14}\N{\b0\fs32\c&H00FFFFFF&}' + $scene.km
  $lines += ('Dialogue: 0,{0},{1},{2},,0,0,0,,{3}' -f (AssTime $start), (AssTime $end), $style, $text)
}
[IO.File]::WriteAllText((Join-Path $build 'captions.ass'), (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
foreach ($font in 'KhmerUI.ttf') { Copy-Item (Join-Path 'C:\Windows\Fonts' $font) $build -Force -ErrorAction SilentlyContinue }

# ---------- one clip per picture, then join them and burn the captions in ----------
function Run-Ffmpeg([string[]]$a) {
  & $ffmpeg @a 2>&1 | ForEach-Object { if ($_ -match 'rror') { Write-Host $_ } }
  if ($LASTEXITCODE -ne 0) { throw "ffmpeg stopped (code $LASTEXITCODE)" }
}
$list = @(); $i = 0
foreach ($scene in $cap.scenes) {
  $sec = [double]$scene.seconds; $clip = "clip$i.mp4"
  $vf = "scale=1080:1920,zoompan=z='min(1.0+0.0009*on,1.07)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${W}x${H}:fps=$FPS,fade=t=in:st=0:d=0.35,fade=t=out:st=$($sec - 0.35):d=0.35,format=yuv420p"
  Run-Ffmpeg @('-y', '-hide_banner', '-loglevel', 'error', '-loop', '1', '-framerate', "$FPS", '-t', "$sec", '-i', (Join-Path $build "scene$i.png"), '-vf', $vf, '-c:v', 'libx264', '-crf', '18', '-preset', 'fast', (Join-Path $build $clip))
  $list += "file '$clip'"; $i++
}
[IO.File]::WriteAllText((Join-Path $build 'list.txt'), (($list -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))

Push-Location $build
try {
  Run-Ffmpeg @('-y', '-hide_banner', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', 'list.txt', '-vf', 'subtitles=captions.ass:fontsdir=.', '-c:v', 'libx264', '-crf', '24', '-preset', 'slow', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', 'how-to-setup.mp4')
  Run-Ffmpeg @('-y', '-hide_banner', '-loglevel', 'error', '-ss', '2.0', '-i', 'how-to-setup.mp4', '-frames:v', '1', '-q:v', '3', 'how-to-setup-poster.jpg')
} finally { Pop-Location }

Copy-Item (Join-Path $build 'how-to-setup.mp4') $publicDir -Force
Copy-Item (Join-Path $build 'how-to-setup-poster.jpg') $publicDir -Force
$mb = [math]::Round((Get-Item (Join-Path $publicDir 'how-to-setup.mp4')).Length / 1MB, 2)
Write-Host "Done. public\how-to-setup.mp4 is $mb MB, $([math]::Round($t)) seconds."
