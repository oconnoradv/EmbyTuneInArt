<#
Builds the bundled 1280x720 JPEG music genre artwork: original neon genre cards whose typography,
palette, and line art depend on the TuneIn parent genre. Run on Windows PowerShell (needs the
Bahnschrift, Segoe UI Variable, Cascadia, and Impact fonts that ship with Windows 11). Copy the output into the
Emby TuneIn plugin's MediaBrowser.Plugins.TuneIn\Images\genres folder; the plugin never builds or downloads it.
#>
param(
    [string]$Output = (Join-Path $PSScriptRoot 'output\genres'),
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Argb([int]$al, $col) { [Drawing.Color]::FromArgb($al, $col) }
function Rgb([int]$r, [int]$gr, [int]$bl) { [Drawing.Color]::FromArgb($r, $gr, $bl) }
function P([float]$x, [float]$y) { New-Object Drawing.PointF $x, $y }
function Pts([float[]]$v) {
    $a = New-Object 'Drawing.PointF[]' ($v.Count / 2)
    for ($i = 0; $i -lt $a.Count; $i++) { $a[$i] = New-Object Drawing.PointF $v[2 * $i], $v[2 * $i + 1] }
    , $a
}
function Pn($col, [float]$w, [float]$k) {
    $pen = New-Object Drawing.Pen $col, ($w * $k * $script:Weight)
    $pen.LineJoin = 'Round'; $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen
}
function Br($col) { New-Object Drawing.SolidBrush $col }
function L($gr, $pen, [float]$x1, [float]$y1, [float]$x2, [float]$y2) { $gr.DrawLine($pen, $x1, $y1, $x2, $y2) }
function E($gr, $pen, [float]$cx, [float]$cy, [float]$rx, [float]$ry) { $gr.DrawEllipse($pen, $cx - $rx, $cy - $ry, 2 * $rx, 2 * $ry) }
function FE($gr, $brush, [float]$cx, [float]$cy, [float]$rx, [float]$ry) { $gr.FillEllipse($brush, $cx - $rx, $cy - $ry, 2 * $rx, 2 * $ry) }
function Rc($gr, $pen, [float]$x, [float]$y, [float]$w, [float]$h) { $gr.DrawRectangle($pen, $x, $y, $w, $h) }
function Arc($gr, $pen, [float]$cx, [float]$cy, [float]$r, [float]$start, [float]$sweep) { $gr.DrawArc($pen, $cx - $r, $cy - $r, 2 * $r, 2 * $r, $start, $sweep) }
function Poly($gr, $pen, [float[]]$v, [switch]$Open) { if ($Open) { $gr.DrawLines($pen, (Pts $v)) } else { $gr.DrawPolygon($pen, (Pts $v)) } }
function Bez($path, [float[]]$v) { $path.AddBezier($v[0], $v[1], $v[2], $v[3], $v[4], $v[5], $v[6], $v[7]) }
function StarPts([float]$cx, [float]$cy, [float]$ro, [float]$ri, [int]$n = 5) {
    $v = for ($i = 0; $i -lt 2 * $n; $i++) {
        $r = if ($i % 2) { $ri } else { $ro }; $t = -[Math]::PI / 2 + $i * [Math]::PI / $n
        $cx + $r * [Math]::Cos($t); $cy + $r * [Math]::Sin($t)
    }
    Pts $v
}
function Sparkle($gr, $pen, [float]$cx, [float]$cy, [float]$r) { $gr.DrawPolygon($pen, (StarPts $cx $cy $r ($r * 0.25) 4)) }
function Note($gr, $pen, $brush, [float]$x, [float]$y, [bool]$flag) {
    $gr.FillEllipse($brush, $x, $y, 30, 22); L $gr $pen ($x + 28) ($y + 10) ($x + 28) ($y - 70)
    if ($flag) { $gr.DrawBezier($pen, (P ($x + 28) ($y - 70)), (P ($x + 50) ($y - 55)), (P ($x + 55) ($y - 35)), (P ($x + 45) ($y - 20))) }
}
function Rounded([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object Drawing.Drawing2D.GraphicsPath; $d = 2 * $r
    $path.AddArc($x, $y, $d, $d, 180, 90); $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure(); $path
}
# Outline of circle 1 (radius r1 at the origin) minus circle 2 (radius r2 at dx,dy).
function CrescentPts([float]$r1, [float]$dx, [float]$dy, [float]$r2) {
    $outer = New-Object 'System.Collections.Generic.List[Drawing.PointF]'
    $inner = New-Object 'System.Collections.Generic.List[Drawing.PointF]'
    $away = [Math]::Atan2(-$dy, -$dx)
    for ($i = -180; $i -le 180; $i += 2) {
        $t = $away + $i * [Math]::PI / 180
        $x = $r1 * [Math]::Cos($t); $y = $r1 * [Math]::Sin($t)
        if ([Math]::Sqrt(($x - $dx) * ($x - $dx) + ($y - $dy) * ($y - $dy)) -ge $r2) { $outer.Add((P $x $y)) }
        $x = $dx + $r2 * [Math]::Cos($t); $y = $dy + $r2 * [Math]::Sin($t)
        if ([Math]::Sqrt($x * $x + $y * $y) -le $r1) { $inner.Add((P $x $y)) }
    }
    $last = $outer[$outer.Count - 1]; $f = $inner[0]; $l = $inner[$inner.Count - 1]
    if ((($last.X - $f.X) * ($last.X - $f.X) + ($last.Y - $f.Y) * ($last.Y - $f.Y)) -gt (($last.X - $l.X) * ($last.X - $l.X) + ($last.Y - $l.Y) * ($last.Y - $l.Y))) { $inner.Reverse() }
    $outer.AddRange($inner); , $outer.ToArray()
}

$script:G = $null; $script:OX = 1000; $script:OY = 360; $script:Weight = 0.7
# Glow layers are composited at reduced opacity so line art stays crisp rather than blurry.
$script:GlowAttr = New-Object Drawing.Imaging.ImageAttributes
$__cm = New-Object Drawing.Imaging.ColorMatrix; $__cm.Matrix33 = 0.65; $script:GlowAttr.SetColorMatrix($__cm)
$script:Mask = New-Object Drawing.Bitmap 1280, 720
$script:Smalls = foreach ($sc in 0.08, 0.04, 0.02) { New-Object Drawing.Bitmap ([int](1280 * $sc)), ([int](720 * $sc)) }
$script:Full = New-Object Drawing.Rectangle 0, 0, 1280, 720

# Draws scriptblock $draw (Graphics, Color, width multiplier) as neon: blurred glow, crisp core, hot white center.
# Motif coordinates are relative to ($script:OX, $script:OY), the centre of the artwork area.
function Neon($__col, [scriptblock]$__draw, [float]$__ox = $script:OX, [float]$__oy = $script:OY) {
    $__mg = [Drawing.Graphics]::FromImage($script:Mask); $__mg.Clear([Drawing.Color]::Transparent)
    $__mg.SmoothingMode = 'AntiAlias'; $__mg.TranslateTransform($__ox, $__oy)
    & $__draw $__mg $__col 3; $__mg.Dispose()
    foreach ($__sm in $script:Smalls) {
        $__sg = [Drawing.Graphics]::FromImage($__sm); $__sg.Clear([Drawing.Color]::Transparent); $__sg.InterpolationMode = 'HighQualityBilinear'
        $__sg.DrawImage($script:Mask, 0, 0, $__sm.Width, $__sm.Height); $__sg.Dispose()
        $script:G.DrawImage($__sm, $script:Full, 0, 0, $__sm.Width, $__sm.Height, 'Pixel', $script:GlowAttr)
    }
    $__st = $script:G.Save(); $script:G.TranslateTransform($__ox, $__oy)
    & $__draw $script:G $__col 1
    & $__draw $script:G ([Drawing.Color]::FromArgb(150, 255, 255, 255)) 0.4
    $script:G.Restore($__st)
}

# ---- Motifs: line art drawn around (0,0), roughly within x -240..240 and y -290..290 ----
# Each takes the three card colours ($cl) and the genre ($info).

function GuitarBody([float]$waist) {
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    Bez $path @(0, -150, 60, -150, 95, -120, 90, -75); Bez $path @(90, -75, 85, -35, ($waist - 7), -25, $waist, 0)
    Bez $path @($waist, 0, ($waist + 8), 25, 125, 45, 120, 95); Bez $path @(120, 95, 115, 150, 60, 160, 0, 160)
    Bez $path @(0, 160, -60, 160, -115, 150, -120, 95); Bez $path @(-120, 95, -125, 45, (-$waist - 8), 25, (-$waist), 0)
    Bez $path @((-$waist), 0, (7 - $waist), -25, -85, -35, -90, -75); Bez $path @(-90, -75, -95, -120, -60, -150, 0, -150)
    $path.CloseFigure(); $path
}

function Motif-guitarV($cl, $info) {
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 5 $k; $pn.LineJoin = 'Miter'
        Poly $g $pn @(150, -300, 75, -130, 130, -130, 60, 40, 225, -180, 165, -180, 225, -300)
        L $g $pn -240 280 -140 200; L $g $pn -200 310 -80 220; L $g $pn 150 290 230 210
    }
    Neon $cl[0] { param($g, $c, $k)
        $s = $g.Save(); $g.TranslateTransform(20, 70); $g.RotateTransform(-38)
        $pn = Pn $c 6 $k; $pn.LineJoin = 'Miter'
        Poly $g $pn @(-40, -70, 150, -170, 70, 0, 150, 170, -40, 70, -110, 0)
        Rc $g $pn -20 -40 22 80; Rc $g $pn 30 -40 22 80; Rc $g $pn -360 -14 340 28
        Poly $g $pn @(-360, -14, -440, -40, -460, 30, -360, 14)
        $th = Pn $c 1.5 $k; foreach ($sy in -9, -3, 3, 9) { L $g $th -440 $sy 80 $sy }
        $g.Restore($s)
    }
}

function Motif-acoustic($cl, $info) {
    Neon $cl[2] { param($g, $c, $k)
        $pn = Pn $c 3 $k; $br = Br $c
        Note $g $pn $br -230 -150 $true; Note $g $pn $br 190 140 $false; Sparkle $g $pn -170 230 22; Sparkle $g $pn 200 -250 18
    }
    Neon $cl[0] { param($g, $c, $k)
        $s = $g.Save(); $g.TranslateTransform(0, 120); $g.RotateTransform(28); $g.ScaleTransform(0.75, 0.75)
        $pn = Pn $c 6 $k
        $g.DrawPath($pn, (GuitarBody 62)); E $g $pn 0 10 40 40
        Rc $g $pn -16 -420 32 270; Poly $g $pn @(-16, -420, -28, -500, 28, -500, 16, -420)
        Rc $g $pn -45 115 90 16
        $g.Restore($s)
    }
    Neon $cl[1] { param($g, $c, $k)
        $s = $g.Save(); $g.TranslateTransform(0, 120); $g.RotateTransform(28); $g.ScaleTransform(0.75, 0.75)
        $th = Pn $c 1.5 $k; foreach ($sx in -9, -3, 3, 9) { L $g $th $sx 122 $sx -490 }
        $g.Restore($s)
    }
}

function Motif-violin($cl, $info) {
    Neon $cl[2] { param($g, $c, $k)
        $pn = Pn $c 3 $k; L $g $pn -200 -230 210 200; L $g $pn -185 -245 225 185; L $g $pn -200 -230 -185 -245
    }
    Neon $cl[0] { param($g, $c, $k)
        $s = $g.Save(); $g.TranslateTransform(-10, 110); $g.RotateTransform(-24); $g.ScaleTransform(0.62, 0.72)
        $pn = Pn $c 7 $k
        $g.DrawPath($pn, (GuitarBody 45))
        Rc $g $pn -14 -470 28 400; E $g $pn 0 -495 26 26; E $g $pn 6 -497 10 10
        $g.Restore($s)
    }
    Neon $cl[1] { param($g, $c, $k)
        $s = $g.Save(); $g.TranslateTransform(-10, 110); $g.RotateTransform(-24); $g.ScaleTransform(0.62, 0.72)
        $pn = Pn $c 4 $k
        foreach ($sx in -1, 1) { $g.DrawBezier($pn, (P (55 * $sx) -40), (P (80 * $sx) -10), (P (30 * $sx) 40), (P (55 * $sx) 70)) }
        Rc $g $pn -40 105 80 12
        $g.Restore($s)
    }
}

function Motif-banjo($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $s = $g.Save(); $g.TranslateTransform(10, 140); $g.RotateTransform(24); $g.ScaleTransform(0.85, 0.85)
        $pn = Pn $c 6 $k
        E $g $pn 0 0 150 150; E $g $pn 0 0 122 122
        Rc $g $pn -18 -470 36 320; Poly $g $pn @(-18, -470, -34, -540, 34, -540, 18, -470)
        $g.Restore($s)
    }
    Neon $cl[1] { param($g, $c, $k)
        $s = $g.Save(); $g.TranslateTransform(10, 140); $g.RotateTransform(24); $g.ScaleTransform(0.85, 0.85)
        $pn = Pn $c 3 $k
        for ($i = 0; $i -lt 16; $i++) { $t = $i * [Math]::PI / 8; FE $g (Br $c) (136 * [Math]::Cos($t)) (136 * [Math]::Sin($t)) 5 5 }
        foreach ($sx in -9, -3, 3, 9) { L $g (Pn $c 1.5 $k) $sx 100 $sx -530 }
        Rc $g $pn -30 90 60 22
        $g.Restore($s)
    }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 3 $k; Sparkle $g $pn -190 -200 26; Sparkle $g $pn 200 -60 20; Sparkle $g $pn 190 250 16 }
}

function Motif-sax($cl, $info) {
    Neon $cl[2] { param($g, $c, $k)
        for ($n = 0; $n -lt 4; $n++) {
            $pn = New-Object Drawing.Pen (Argb (200 - $n * 40) $c), (2.5 * $k)
            $g.DrawCurve($pn, (Pts $(for ($x = -360; $x -le 300; $x += 20) { $x; 260 + $n * 18 + 26 * [Math]::Sin(($x + 1000) / 70 + $n) })))
        }
    }
    Neon $cl[0] { param($g, $c, $k)
        $center = New-Object Drawing.Drawing2D.GraphicsPath
        Bez $center @(-130, -280, -70, -290, -40, -240, -40, -190); $center.AddLine(-40, -190, -25, 70)
        Bez $center @(-25, 70, -15, 200, 110, 210, 125, 90); $center.AddLine(125, 90, 135, 20)
        $center.Widen((New-Object Drawing.Pen ([Drawing.Color]::Black), 46))
        $pn = Pn $c 5 $k
        $g.DrawPath($pn, $center); E $g $pn 135 -10 50 20; L $g $pn -150 -288 -122 -272
        foreach ($ky in -140, -90, -40, 10, 60) { E $g (Pn $c 3 $k) -60 ($ky + 10) 10 10 }
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 4 $k; $br = Br $c
        Note $g $pn $br 180 -190 $true; Note $g $pn $br 230 -100 $false; Note $g $pn $br -200 -160 $false; Note $g $pn $br 190 160 $true
    }
}

function Motif-trumpet($cl, $info) {
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 4 $k; $br = Br $c
        Note $g $pn $br 150 -230 $true; Note $g $pn $br 205 -150 $false; Note $g $pn $br -190 -210 $true
        foreach ($i in 0..2) { Arc $g (Pn $c 3 $k) 150 30 (130 + 40 * $i) -30 60 }
    }
    Neon $cl[0] { param($g, $c, $k)
        $s = $g.Save(); $g.TranslateTransform(-20, 40); $g.RotateTransform(-14); $g.ScaleTransform(0.95, 0.95)
        $pn = Pn $c 6 $k
        L $g $pn -240 -20 110 -20; Rc $g $pn -250 -32 18 24
        $g.DrawPath($pn, (Rounded -150 -20 230 90 40))
        foreach ($vx in -60, -15, 30) { Rc $g $pn $vx -80 24 130; E $g $pn ($vx + 12) -96 18 12 }
        $bell = New-Object Drawing.Drawing2D.GraphicsPath
        Bez $bell @(110, -20, 170, -24, 210, -50, 240, -105); $bell.StartFigure(); Bez $bell @(110, 70, 170, 74, 210, 100, 240, 155)
        $g.DrawPath($pn, $bell); L $g $pn 110 -20 110 70; E $g $pn 240 25 22 130
        $g.Restore($s)
    }
}

function Motif-mic($cl, $info) {
    Neon $cl[2] { param($g, $c, $k)
        $pn = Pn $c 4 $k
        foreach ($i in 0..2) { Arc $g $pn 0 -140 (140 + 45 * $i) -40 80; Arc $g $pn 0 -140 (140 + 45 * $i) 140 80 }
    }
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k
        $g.DrawPath($pn, (Rounded -80 -270 160 250 80))
        Arc $g $pn 0 -100 115 0 180; L $g $pn 0 15 0 230; E $g $pn 0 240 110 20
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 2.5 $k
        for ($y = -230; $y -le -60; $y += 22) { $hw = if ($y -lt -190 -or $y -gt -100) { 50 } else { 66 }; L $g $pn (-$hw) $y $hw $y }
        L $g (Pn $c 4 $k) -80 -150 80 -150
    }
}

function Motif-keyboard($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $s = $g.Save(); $g.RotateTransform(-10)
        $pn = Pn $c 6 $k
        $g.DrawPath($pn, (Rounded -240 -110 480 260 18)); Rc $g $pn -210 20 420 110
        $g.Restore($s)
    }
    Neon $cl[1] { param($g, $c, $k)
        $s = $g.Save(); $g.RotateTransform(-10)
        $pn = Pn $c 2.5 $k; $br = Br $c
        for ($i = 1; $i -lt 14; $i++) { $x = -210 + $i * 30; L $g $pn $x 20 $x 130 }
        foreach ($i in 0, 1, 3, 4, 5, 7, 8, 10, 11, 12) { $g.FillRectangle($br, [float](-210 + $i * 30 + 20), [float]20, [float]20, [float]62) }
        $g.Restore($s)
    }
    Neon $cl[2] { param($g, $c, $k)
        $s = $g.Save(); $g.RotateTransform(-10)
        $pn = Pn $c 3.5 $k
        foreach ($i in 0..4) { E $g $pn (-185 + $i * 52) -55 17 17 }
        Rc $g $pn 80 -85 120 60
        $g.DrawCurve($pn, (Pts $(for ($x = 90; $x -le 190; $x += 10) { $x; -55 + 18 * [Math]::Sin($x / 8) })))
        $g.Restore($s)
        Sparkle $g $pn -170 -230 26; Sparkle $g $pn 190 230 20
    }
}

function Motif-amp($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k
        $g.DrawPath($pn, (Rounded -190 -260 380 70 12)); $g.DrawPath($pn, (Rounded -190 -170 380 430 12))
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 4 $k
        foreach ($sp in @(@(-90, -50), @(90, -50), @(-90, 140), @(90, 140))) { E $g $pn $sp[0] $sp[1] 78 78; E $g $pn $sp[0] $sp[1] 26 26 }
    }
    Neon $cl[2] { param($g, $c, $k)
        $pn = Pn $c 3.5 $k
        foreach ($i in 0..5) { E $g $pn (-140 + $i * 56) -225 13 13 }
        if ($info.Name -eq 'Grunge') { Poly $g (Pn $c 4 $k) @(-240, -290, -200, -320, -160, -280, -120, -330, -80, -285, -40, -320) -Open }
    }
}

function Motif-drum($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k
        E $g $pn 0 0 180 50; L $g $pn -180 0 -180 170; L $g $pn 180 0 180 170
        $g.DrawArc($pn, -180, 120, 360, 100, 0, 180)
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 3 $k
        foreach ($x in -120, -60, 0, 60, 120) { L $g $pn $x ([Math]::Sqrt(1 - ($x / 180) * ($x / 180)) * 50) $x (170 + [Math]::Sqrt(1 - ($x / 180) * ($x / 180)) * 50) }
    }
    Neon $cl[2] { param($g, $c, $k)
        $pn = Pn $c 7 $k
        L $g $pn -200 -280 30 -40; L $g $pn 200 -280 -30 -40; E $g $pn 30 -40 9 9; E $g $pn -30 -40 9 9
        Sparkle $g (Pn $c 3 $k) -40 -150 30; Sparkle $g (Pn $c 3 $k) 40 -230 18
    }
}

function Motif-vinyl($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k
        $g.DrawPath($pn, (Rounded -235 -220 470 440 26)); E $g $pn -35 0 175 175
        E $g $pn 180 -165 20 20; Poly $g $pn @(180, -165, 175, 50, 110, 105) -Open; Rc $g $pn 92 95 34 26
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 2 $k; foreach ($r in 150, 128, 106, 84) { E $g $pn -35 0 $r $r }
        L $g (Pn $c 4 $k) 205 80 205 190
    }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 5 $k; E $g $pn -35 0 50 50; FE $g (Br $c) -35 0 7 7; Rc $g $pn 193 120 24 18 }
}

function Motif-headphones($cl, $info) {
    Neon $cl[2] { param($g, $c, $k)
        $pn = Pn $c 4 $k
        foreach ($i in 0..2) { Arc $g $pn 170 90 (110 + 40 * $i) -40 80 }
        Sparkle $g $pn -200 -250 24; Sparkle $g $pn 180 -230 18
    }
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 7 $k
        $g.DrawArc($pn, -170, -250, 340, 380, 180, 180); L $g $pn -170 -60 -170 20; L $g $pn 170 -60 170 20
        $g.DrawPath($pn, (Rounded -215 10 90 190 36)); $g.DrawPath($pn, (Rounded 125 10 90 190 36))
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 4 $k
        $g.DrawPath($pn, (Rounded -190 40 40 130 18)); $g.DrawPath($pn, (Rounded 150 40 40 130 18))
        $g.DrawArc($pn, -140, -215, 280, 320, 200, 140)
    }
}

function Motif-cassette($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $s = $g.Save(); $g.RotateTransform(-10); $pn = Pn $c 6 $k
        $g.DrawPath($pn, (Rounded -235 -150 470 300 22)); Poly $g $pn @(-150, 150, -120, 95, 120, 95, 150, 150) -Open
        $g.Restore($s)
    }
    Neon $cl[1] { param($g, $c, $k)
        $s = $g.Save(); $g.RotateTransform(-10); $pn = Pn $c 4 $k
        $g.DrawPath($pn, (Rounded -195 -120 390 190 14)); Rc $g $pn -110 -20 220 70
        foreach ($sx in -1, 1) { E $g $pn (65 * $sx) 15 30 30; for ($i = 0; $i -lt 6; $i++) { $t = $i * [Math]::PI / 3; L $g (Pn $c 2.5 $k) (65 * $sx + 12 * [Math]::Cos($t)) (15 + 12 * [Math]::Sin($t)) (65 * $sx + 24 * [Math]::Cos($t)) (15 + 24 * [Math]::Sin($t)) } }
        $g.Restore($s)
    }
    Neon $cl[2] { param($g, $c, $k)
        $s = $g.Save(); $g.RotateTransform(-10); $pn = Pn $c 3.5 $k
        L $g $pn -170 -95 170 -95; L $g $pn -170 -70 60 -70
        $g.Restore($s)
        Note $g $pn (Br $c) 170 -230 $true; Sparkle $g $pn -190 240 22
    }
}

function Motif-boombox($cl, $info) {
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 4 $k; L $g $pn 170 -120 235 -285; E $g $pn 235 -290 8 8; foreach ($i in 0..1) { Arc $g $pn 235 -290 (30 + 26 * $i) 200 100 } }
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k
        $g.DrawPath($pn, (Rounded -235 -120 470 280 26)); Poly $g $pn @(-150, -120, -150, -190, 150, -190, 150, -120) -Open
        E $g $pn -135 40 85 85; E $g $pn 135 40 85 85
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 4 $k
        E $g $pn -135 40 38 38; E $g $pn 135 40 38 38; Rc $g $pn -42 -10 84 64
        foreach ($i in 0..4) { Rc $g $pn (-80 + $i * 34) -95 22 14 }
        $g.FillEllipse((Br $c), [float]-140, [float]35, [float]10, [float]10); $g.FillEllipse((Br $c), [float]130, [float]35, [float]10, [float]10)
    }
}

function Motif-radio($cl, $info) {
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 4 $k; L $g $pn 150 -140 225 -275; E $g $pn 228 -282 9 9; foreach ($i in 0..2) { Arc $g $pn 228 -282 (32 + 28 * $i) -70 80 } }
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 6 $k; $g.DrawPath($pn, (Rounded -235 -140 470 300 40)); E $g $pn -95 10 105 105 }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 2.5 $k
        for ($y = -80; $y -le 100; $y += 20) { $hw = [Math]::Sqrt([Math]::Max(0, 92 * 92 - ($y - 10) * ($y - 10))); L $g $pn (-95 - $hw) $y (-95 + $hw) $y }
        $p4 = Pn $c 4 $k
        Rc $g $p4 40 -90 160 70; foreach ($i in 0..7) { L $g $pn (55 + $i * 19) -90 (55 + $i * 19) -75 }
        L $g $p4 115 -88 105 -25; E $g $p4 75 75 24 24; E $g $p4 165 75 24 24
    }
}

function Motif-tower($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k; L $g $pn 0 -200 -120 250; L $g $pn 0 -200 120 250; L $g $pn -150 250 150 250
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 3 $k
        $lv = @(-140, -60, 30, 130, 250); for ($i = 0; $i -lt 4; $i++) {
            $y1 = $lv[$i]; $y2 = $lv[$i + 1]; $w1 = 120 * ($y1 + 200) / 450; $w2 = 120 * ($y2 + 200) / 450
            L $g $pn (-$w1) $y1 $w1 $y1; L $g $pn (-$w1) $y1 $w2 $y2; L $g $pn $w1 $y1 (-$w2) $y2
        }
    }
    Neon $cl[2] { param($g, $c, $k)
        $pn = Pn $c 4.5 $k; FE $g (Br $c) 0 -215 14 14
        foreach ($i in 0..2) { Arc $g $pn 0 -215 (60 + 52 * $i) -55 110; Arc $g $pn 0 -215 (60 + 52 * $i) 125 110 }
    }
}

function Motif-eq($cl, $info) {
    $rng = New-Object Random $info.Seed
    $bars = foreach ($i in 0..8) { $rng.Next(4, 15) }
    $gaps = foreach ($i in 0..8) { if ($info.Name -eq 'Breakbeats') { $rng.Next(1, 4) } else { 0 } }
    foreach ($layer in 0, 1, 2) {
        Neon $cl[$layer] { param($g, $c, $k)
            $br = Br $c
            for ($i = 0; $i -lt 9; $i++) {
                $x = -225 + $i * 52
                for ($j = 0; $j -lt $bars[$i]; $j++) {
                    if ($gaps[$i] -and $j -eq $gaps[$i] + 2) { continue }
                    $tier = if ($j -lt 6) { 0 } elseif ($j -lt 11) { 1 } else { 2 }
                    if ($tier -eq $layer) { $g.FillRectangle($br, [float]$x, [float](230 - $j * 34), [float]36, [float]24) }
                }
            }
            if ($layer -eq 2) { for ($i = 0; $i -lt 9; $i++) { $g.FillRectangle($br, [float](-225 + $i * 52), [float](230 - ($bars[$i] + 1) * 34 - 6), [float]36, [float]6) } }
        }
    }
}

function Motif-wave($cl, $info) {
    $kind = switch ($info.Name) { 'Dubstep' { 'wobble' } 'Chill' { 'calm' } default { 'sine' } }
    foreach ($layer in 0, 1, 2) {
        Neon $cl[$layer] { param($g, $c, $k)
            $pn = Pn $c (6 - 1.5 * $layer) $k
            $pts = for ($x = -240; $x -le 240; $x += 4) {
                $env = [Math]::Cos($x / 240 * [Math]::PI / 2); $ph = $x / 22 + $layer * 1.7
                $y = switch ($kind) {
                    'wobble' { 150 * $env * [Math]::Sign([Math]::Sin($x / 30 + $layer)) * [Math]::Abs([Math]::Sin($x / 9)) }
                    'calm' { 70 * $env * [Math]::Sin($x / 45 + $layer) }
                    default { 160 * $env * [Math]::Sin($ph) * (1 - 0.3 * $layer) }
                }
                $x; ($y + ($layer - 1) * 40)
            }
            $g.DrawLines($pn, (Pts $pts))
        }
    }
    if ($kind -eq 'calm') { Neon $cl[2] { param($g, $c, $k) $g.DrawPolygon((Pn $c 4 $k), (CrescentPts 60 25 -20 52)) } 180 -220 }
}

function Motif-seqGrid($cl, $info) {
    $rng = New-Object Random $info.Seed
    $lit = foreach ($i in 0..15) { $rng.Next(0, 3) -eq 0 }
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 4 $k; for ($i = 0; $i -lt 16; $i++) { $g.DrawPath($pn, (Rounded (-214 + ($i % 4) * 112) (-214 + [Math]::Floor($i / 4) * 112) 90 90 12)) } }
    Neon $cl[1] { param($g, $c, $k) $br = Br (Argb 200 $c); for ($i = 0; $i -lt 16; $i++) { if ($lit[$i]) { $g.FillPath($br, (Rounded (-204 + ($i % 4) * 112) (-204 + [Math]::Floor($i / 4) * 112) 70 70 10)) } } }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 4 $k; L $g $pn (-214 + ($info.Seed % 4) * 112 - 10) -240 (-214 + ($info.Seed % 4) * 112 - 10) 240 }
}

function Motif-rings($cl, $info) {
    foreach ($layer in 0, 1, 2) {
        Neon $cl[$layer] { param($g, $c, $k)
            $pn = Pn $c (5 - $layer) $k
            foreach ($i in 0..4) { if ($i % 3 -eq $layer) { $r = 40 + 50 * $i; for ($q = 0; $q -lt 4; $q++) { Arc $g $pn 0 0 $r ($q * 90 + $i * 25) 70 } } }
        }
    }
    Neon $cl[0] { param($g, $c, $k) FE $g (Br $c) 0 0 16 16 }
}

function Motif-house($cl, $info) {
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 7 $k; Poly $g $pn @(-230, 20, 0, -230, 230, 20) -Open; Poly $g $pn @(-170, -20, -170, 240, 170, 240, 170, -20) -Open }
    Neon $cl[1] { param($g, $c, $k)
        $br = Br $c; $hs = 4, 7, 10, 6, 8
        for ($i = 0; $i -lt 5; $i++) { for ($j = 0; $j -lt $hs[$i]; $j++) { $g.FillRectangle($br, [float](-130 + $i * 56), [float](205 - $j * 26), [float]38, [float]18) } }
    }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 3.5 $k; Sparkle $g $pn 150 -200 26; Sparkle $g $pn -170 -170 18 }
}

function Motif-discoBall($cl, $info) {
    Neon $cl[2] { param($g, $c, $k)
        $pn = Pn $c 3 $k
        foreach ($a in 200, 225, 250, 290, 315, 340) { $t = $a * [Math]::PI / 180; L $g $pn (200 * [Math]::Cos($t)) (-30 - 200 * [Math]::Sin($t)) (290 * [Math]::Cos($t)) (-30 - 290 * [Math]::Sin($t)) }
        Sparkle $g $pn -200 -230 22; Sparkle $g $pn 205 -200 28
    }
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k; E $g $pn 0 -30 170 170; L $g $pn 0 -200 0 -300
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 2.5 $k
        foreach ($t in -60, -35, -12, 12, 35, 60) { $y = 170 * [Math]::Sin($t * [Math]::PI / 180); $hw = 170 * [Math]::Cos($t * [Math]::PI / 180); L $g $pn (-$hw) (-30 + $y) $hw (-30 + $y) }
        foreach ($w in 45, 100, 145) { E $g $pn 0 -30 $w 170 }
    }
}

function Motif-tree($cl, $info) {
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 6 $k
        Poly $g $pn @(0, -230, -100, -90, -50, -90, -150, 50, -90, 50, -210, 210, 210, 210, 90, 50, 150, 50, 50, -90, 100, -90)
        Rc $g $pn -25 210 50 55
    }
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 3.5 $k
        $g.DrawBezier($pn, (P -80 -60), (P -20 -30), (P 40 -50), (P 75 -80)); $g.DrawBezier($pn, (P -130 90), (P -40 130), (P 60 110), (P 130 70))
        foreach ($o in @(@(-60, -20), @(50, 10), @(-110, 130), @(20, 160), @(140, 170), @(-30, 60))) { FE $g (Br $c) $o[0] $o[1] 12 12 }
    }
    Neon $cl[2] { param($g, $c, $k) $g.DrawPolygon((Pn $c 5 $k), (StarPts 0 -255 48 20)); Sparkle $g (Pn $c 3 $k) -190 -200 20; Sparkle $g (Pn $c 3 $k) 190 -120 16 }
}

function Motif-candles($cl, $info) {
    $hs = 260, 330, 230
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 6 $k; for ($i = 0; $i -lt 3; $i++) { Rc $g $pn (-170 + $i * 120) (260 - $hs[$i]) 70 $hs[$i] }; L $g $pn -220 262 220 262 }
    Neon $cl[2] { param($g, $c, $k)
        $pn = Pn $c 4 $k
        for ($i = 0; $i -lt 3; $i++) {
            $x = -135 + $i * 120; $y = 260 - $hs[$i]
            $fl = New-Object Drawing.Drawing2D.GraphicsPath; Bez $fl @($x, ($y - 12), ($x - 28), ($y - 40), $x, ($y - 70), $x, ($y - 95)); Bez $fl @($x, ($y - 95), ($x + 10), ($y - 60), ($x + 30), ($y - 40), $x, ($y - 12))
            $g.DrawPath($pn, $fl); Arc $g (Pn $c 2.5 $k) $x ($y - 50) 70 200 140
        }
    }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 3 $k; for ($i = 0; $i -lt 3; $i++) { L $g $pn (-135 + $i * 120) (260 - $hs[$i]) (-135 + $i * 120) (248 - $hs[$i]) }; Sparkle $g $pn 200 -230 20 }
}

function Motif-ornament($cl, $info) {
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 4 $k; L $g $pn 0 -300 0 -195; Rc $g $pn -28 -195 56 34; Arc $g $pn 0 -205 18 180 180 }
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 6 $k; E $g $pn 0 20 180 180 }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 4 $k
        Poly $g $pn @(-170, -30, -110, -70, -55, -30, 0, -70, 55, -30, 110, -70, 170, -30) -Open
        Poly $g $pn @(-170, 70, -110, 110, -55, 70, 0, 110, 55, 70, 110, 110, 170, 70) -Open
        $g.DrawPolygon($pn, (StarPts 0 20 34 14)); Sparkle $g $pn -190 -230 22; Sparkle $g $pn 200 200 18
    }
}

function Motif-wreath($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 4 $k
        for ($i = 0; $i -lt 18; $i++) {
            $t = $i * [Math]::PI / 9; $cx = 160 * [Math]::Cos($t); $cy = 160 * [Math]::Sin($t)
            $s = $g.Save(); $g.TranslateTransform($cx, $cy); $g.RotateTransform($i * 20 + 45); E $g $pn 0 0 40 16; $g.Restore($s)
        }
    }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 5 $k; Poly $g $pn @(0, 160, -70, 110, -90, 160, 0, 160, 90, 110, 70, 160) ; L $g $pn 0 160 -50 270; L $g $pn 0 160 50 270 }
    Neon $cl[1] { param($g, $c, $k) $br = Br $c; foreach ($i in 1, 4, 7, 10, 13, 16) { $t = $i * [Math]::PI / 9; FE $g $br (190 * [Math]::Cos($t)) (190 * [Math]::Sin($t)) 11 11 } }
}

function Motif-bells($cl, $info) {
    foreach ($b in @(@(-75, 0, -14), @(85, 20, 16))) {
        Neon $cl[$(if ($b[0] -lt 0) { 0 } else { 2 })] { param($g, $c, $k)
            $s = $g.Save(); $g.TranslateTransform($b[0], $b[1]); $g.RotateTransform($b[2]); $pn = Pn $c 6 $k
            $bl = New-Object Drawing.Drawing2D.GraphicsPath
            Bez $bl @(0, -130, -70, -130, -70, -40, -80, 40); Bez $bl @(-80, 40, -90, 90, -120, 100, -120, 120); $bl.AddLine(-120, 120, 120, 120)
            Bez $bl @(120, 120, 120, 100, 90, 90, 80, 40); Bez $bl @(80, 40, 70, -40, 70, -130, 0, -130); $bl.CloseFigure()
            $g.DrawPath($pn, $bl); E $g $pn 0 145 22 22; Arc $g $pn 0 -140 20 180 180
            $g.Restore($s)
        }
    }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 5 $k; Poly $g $pn @(-75, -150, 0, -230, 85, -130) -Open; Poly $g $pn @(-40, -220, 0, -230, 40, -220, 0, -190); foreach ($i in 0..1) { Arc $g (Pn $c 3 $k) 0 200 (60 + 40 * $i) 40 100 } }
}

function Motif-starRays($cl, $info) {
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 3 $k
        for ($i = 0; $i -lt 16; $i++) { $t = $i * [Math]::PI / 8; $r1 = 90; $r2 = if ($i % 2) { 200 } else { 270 }; L $g $pn ($r1 * [Math]::Cos($t)) (-60 + $r1 * [Math]::Sin($t)) ($r2 * [Math]::Cos($t)) (-60 + $r2 * [Math]::Sin($t)) }
    }
    Neon $cl[2] { param($g, $c, $k) $g.DrawPolygon((Pn $c 6 $k), (StarPts 0 -60 80 22 8)) }
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 5 $k; Poly $g $pn @(-200, 270, -200, 180, 0, 90, 200, 180, 200, 270) -Open; Rc $g $pn -40 190 80 80 }
}

function Motif-gift($cl, $info) {
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 6 $k; Rc $g $pn -180 -40 360 280; Rc $g $pn -205 -110 410 70 }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 5 $k; L $g $pn -30 -110 -30 240; L $g $pn 30 -110 30 240
        $g.DrawBezier($pn, (P 0 -110), (P -60 -240), (P -180 -200), (P 0 -110)); $g.DrawBezier($pn, (P 0 -110), (P 60 -240), (P 180 -200), (P 0 -110))
    }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 3.5 $k; Sparkle $g $pn -200 -230 24; Sparkle $g $pn 210 -180 18; Sparkle $g $pn 215 250 16 }
}

function Motif-globe($cl, $info) {
    $marks = if ($info.Lat -ne $null) { , (, @($info.Lat, $info.Lon)) } else { @(@(40, -4), @(36, 138), @(-10, -52), @(5, 20), @(21, 78)) }
    $lat0 = [Math]::Max(-30, [Math]::Min(40, $marks[0][0] * 0.6)) * [Math]::PI / 180
    $lon0 = if ($info.Lat -ne $null) { $marks[0][1] } else { 20 }
    $R = 200
    $proj = { param($la, $lo)
        $p = $la * [Math]::PI / 180; $l = ($lo - $lon0) * [Math]::PI / 180
        $cs = [Math]::Sin($lat0) * [Math]::Sin($p) + [Math]::Cos($lat0) * [Math]::Cos($p) * [Math]::Cos($l)
        @(($R * [Math]::Cos($p) * [Math]::Sin($l)), (-$R * ([Math]::Cos($lat0) * [Math]::Sin($p) - [Math]::Sin($lat0) * [Math]::Cos($p) * [Math]::Cos($l))), $cs)
    }
    $segs = New-Object System.Collections.ArrayList
    $trace = { param($list)
        $cur = New-Object System.Collections.ArrayList
        foreach ($q in $list) { if ($q[2] -gt 0) { [void]$cur.Add($q[0]); [void]$cur.Add($q[1]) } elseif ($cur.Count -ge 4) { [void]$segs.Add($cur.ToArray()); $cur = New-Object System.Collections.ArrayList } else { $cur.Clear() } }
        if ($cur.Count -ge 4) { [void]$segs.Add($cur.ToArray()) }
    }
    foreach ($la in -60, -30, 0, 30, 60) { & $trace $(for ($lo = -180; $lo -le 180; $lo += 4) { , (& $proj $la $lo) }) }
    foreach ($lo in -180, -150, -120, -90, -60, -30, 0, 30, 60, 90, 120, 150) { & $trace $(for ($la = -90; $la -le 90; $la += 4) { , (& $proj $la $lo) }) }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 2.5 $k; foreach ($sg in $segs) { $g.DrawLines($pn, (Pts $sg)) } }
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k; E $g $pn 0 0 $R $R
        $s = $g.Save(); $g.RotateTransform(-18); E $g (Pn $c 3.5 $k) 0 0 280 70; $g.Restore($s)
    }
    Neon $cl[2] { param($g, $c, $k)
        foreach ($m in $marks) { $q = & $proj $m[0] $m[1]; if ($q[2] -gt 0) { FE $g (Br $c) $q[0] $q[1] 12 12; E $g (Pn $c 3.5 $k) $q[0] $q[1] 30 30; E $g (Pn $c 2 $k) $q[0] $q[1] 50 50 } }
    }
}

function Motif-cross($cl, $info) {
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 3 $k; for ($i = 0; $i -lt 12; $i++) { $t = $i * [Math]::PI / 6; L $g $pn (130 * [Math]::Cos($t)) (-80 + 130 * [Math]::Sin($t)) (230 * [Math]::Cos($t)) (-80 + 230 * [Math]::Sin($t)) } }
    Neon $cl[0] { param($g, $c, $k) Poly $g (Pn $c 7 $k) @(-30, -270, 30, -270, 30, -140, 120, -140, 120, -80, 30, -80, 30, 270, -30, 270, -30, -80, -120, -80, -120, -140, -30, -140) }
    Neon $cl[2] { param($g, $c, $k) E $g (Pn $c 4 $k) 0 -110 105 105 }
}

function Motif-book($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k
        $g.DrawBezier($pn, (P 0 -60), (P -80 -100), (P -170 -90), (P -230 -60)); L $g $pn -230 -60 -230 220; $g.DrawBezier($pn, (P -230 220), (P -170 190), (P -80 180), (P 0 220))
        $g.DrawBezier($pn, (P 0 -60), (P 80 -100), (P 170 -90), (P 230 -60)); L $g $pn 230 -60 230 220; $g.DrawBezier($pn, (P 230 220), (P 170 190), (P 80 180), (P 0 220)); L $g $pn 0 -60 0 220
    }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 2.5 $k; foreach ($y in 0, 40, 80, 120) { L $g $pn -190 $y -40 ($y + 10); L $g $pn 40 ($y + 10) 190 $y } }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 4 $k; L $g $pn 0 -250 0 -130; L $g $pn -45 -205 45 -205; for ($i = 0; $i -lt 8; $i++) { $t = $i * [Math]::PI / 4; L $g (Pn $c 2.5 $k) (70 * [Math]::Cos($t)) (-190 + 70 * [Math]::Sin($t)) (100 * [Math]::Cos($t)) (-190 + 100 * [Math]::Sin($t)) } }
}

function Motif-crescent($cl, $info) {
    Neon $cl[0] { param($g, $c, $k) $s = $g.Save(); $g.TranslateTransform(-40, 0); $g.DrawPolygon((Pn $c 7 $k), (CrescentPts 200 70 -30 170)); $g.Restore($s) }
    Neon $cl[2] { param($g, $c, $k) $g.DrawPolygon((Pn $c 5 $k), (StarPts 120 -10 60 25)) }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 3 $k; Sparkle $g $pn 170 -220 20; Sparkle $g $pn -200 240 16; Sparkle $g $pn 200 200 14 }
}

function Motif-starDavid($cl, $info) {
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 7 $k; Poly $g $pn @(0, -220, 190, 110, -190, 110) }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 7 $k; Poly $g $pn @(0, 220, 190, -110, -190, -110) }
    Neon $cl[2] { param($g, $c, $k) E $g (Pn $c 3 $k) 0 0 260 260; Sparkle $g (Pn $c 3 $k) 0 0 30 }
}

function Motif-palm($cl, $info) {
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 4 $k; E $g $pn 150 -150 70 70; foreach ($y in 220, 250, 280) { L $g (Pn $c 3 $k) -240 $y 240 $y } }
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k
        $g.DrawBezier($pn, (P -40 280), (P -30 120), (P -60 -20), (P -10 -150)); $g.DrawBezier($pn, (P 10 280), (P 20 120), (P -10 -20), (P 25 -150))
        foreach ($y in 220, 160, 100, 40, -30, -90) { L $g (Pn $c 3 $k) (-35 + [int]($y -lt 0) * 10) $y (15 + [int]($y -lt 0) * 10) ($y - 12) }
    }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 5 $k
        foreach ($f in @(@(-230, -120, -150, -260), @(-220, 20, -140, -120), @(220, -90, 120, -250), @(240, 40, 150, -110), @(-60, -290, 60, -300))) {
            $g.DrawBezier($pn, (P 8 -150), (P $f[2] $f[3]), (P $f[2] $f[3]), (P $f[0] $f[1]))
        }
        FE $g (Br $c) -10 -130 14 14; FE $g (Br $c) 22 -125 14 14
    }
}

function Motif-maracas($cl, $info) {
    foreach ($m in @(@(-70, -20, 0), @(80, 10, 2))) {
        Neon $cl[$m[2]] { param($g, $c, $k)
            $s = $g.Save(); $g.TranslateTransform($m[0], $m[1]); $g.RotateTransform($(if ($m[0] -lt 0) { -25 } else { 25 })); $pn = Pn $c 6 $k
            E $g $pn 0 -120 90 120; $g.DrawPath($pn, (Rounded -16 0 32 250 14))
            $g.Restore($s)
        }
    }
    Neon $cl[1] { param($g, $c, $k)
        foreach ($m in @(@(-70, -20, -25), @(80, 10, 25))) { $s = $g.Save(); $g.TranslateTransform($m[0], $m[1]); $g.RotateTransform($m[2]); $pn = Pn $c 3.5 $k; Poly $g $pn @(-80, -150, -40, -125, 0, -150, 40, -125, 80, -150) -Open; Poly $g $pn @(-85, -90, -40, -65, 0, -90, 40, -65, 85, -90) -Open; $g.Restore($s) }
        foreach ($i in 0..1) { Arc $g (Pn $c 3 $k) 0 -150 (220 + 35 * $i) 240 60 }
    }
}

function HeartPath([float]$s) {
    $h = New-Object Drawing.Drawing2D.GraphicsPath
    Bez $h @(0, (-80 * $s), (-30 * $s), (-170 * $s), (-200 * $s), (-150 * $s), (-190 * $s), (-30 * $s)); Bez $h @((-190 * $s), (-30 * $s), (-180 * $s), (60 * $s), (-60 * $s), (120 * $s), 0, (190 * $s))
    Bez $h @(0, (190 * $s), (60 * $s), (120 * $s), (180 * $s), (60 * $s), (190 * $s), (-30 * $s)); Bez $h @((190 * $s), (-30 * $s), (200 * $s), (-150 * $s), (30 * $s), (-170 * $s), 0, (-80 * $s))
    $h.CloseFigure(); $h
}

function Motif-heart($cl, $info) {
    Neon $cl[0] { param($g, $c, $k) $g.DrawPath((Pn $c 7 $k), (HeartPath 1.1)) }
    if ($info.Name -eq 'Mental Health') {
        Neon $cl[2] { param($g, $c, $k) Poly $g (Pn $c 5 $k) @(-240, 10, -110, 10, -80, -70, -40, 100, 0, -120, 40, 60, 70, 10, 240, 10) -Open }
    } else {
        Neon $cl[1] { param($g, $c, $k) $g.DrawPath((Pn $c 4 $k), (HeartPath 0.72)) }
        Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 4 $k; Note $g $pn (Br $c) 170 -170 $true; Sparkle $g $pn -200 -220 22 }
    }
}

function Motif-moonStars($cl, $info) {
    Neon $cl[0] { param($g, $c, $k) $s = $g.Save(); $g.TranslateTransform(-20, -20); $g.DrawPolygon((Pn $c 7 $k), (CrescentPts 190 80 -60 165)); $g.Restore($s) }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 3.5 $k; Sparkle $g $pn 150 -200 30; Sparkle $g $pn 200 -40 18; Sparkle $g $pn 120 220 22; Sparkle $g $pn -220 230 14 }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 3 $k; foreach ($y in 250, 275) { $g.DrawCurve($pn, (Pts $(for ($x = -240; $x -le 240; $x += 20) { $x; $y + 8 * [Math]::Sin($x / 25 + $y) }))) } }
}

function Motif-cocktail($cl, $info) {
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 6 $k; Poly $g $pn @(-170, -170, 170, -170, 0, 30); L $g $pn 0 30 0 230; E $g $pn 0 240 100 18 }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 4 $k; L $g $pn -120 -130 120 -130; L $g $pn 70 -260 -10 -70; FE $g (Br $c) 30 -110 22 22 }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 3.5 $k; foreach ($b in @(@(-20, -100, 10), @(40, -150, 7), @(-60, -190, 6))) { E $g $pn $b[0] $b[1] $b[2] $b[2] }; Sparkle $g $pn 190 -230 22; Sparkle $g $pn -200 120 16 }
}

function Motif-lotus($cl, $info) {
    $petal = { param($g, $pn, $ang, $len, $wid) $s = $g.Save(); $g.TranslateTransform(0, 100); $g.RotateTransform($ang); $g.DrawBezier($pn, (P 0 0), (P (-$wid) (-$len * 0.5)), (P (-$wid * 0.3) (-$len * 0.9)), (P 0 (-$len))); $g.DrawBezier($pn, (P 0 0), (P $wid (-$len * 0.5)), (P ($wid * 0.3) (-$len * 0.9)), (P 0 (-$len))); $g.Restore($s) }
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 6 $k; & $petal $g $pn 0 270 85; & $petal $g $pn -35 230 70; & $petal $g $pn 35 230 70 }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 4 $k; & $petal $g $pn -70 190 55; & $petal $g $pn 70 190 55 }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 3.5 $k; foreach ($i in 0..2) { $g.DrawArc($pn, [float](-200 - 25 * $i), [float](130 + 20 * $i), [float](400 + 50 * $i), [float](60), 0, 180) }; E $g $pn 0 -230 32 32 }
}

function Motif-notes($cl, $info) {
    Neon $cl[0] { param($g, $c, $k) $pn = Pn $c 5 $k; for ($i = 0; $i -lt 5; $i++) { $y = -60 + $i * 36; $g.DrawBezier($pn, (P -240 ($y + 30)), (P -80 ($y - 30)), (P 80 ($y + 50)), (P 240 ($y - 10))) } }
    Neon $cl[1] { param($g, $c, $k)
        $pn = Pn $c 6 $k; $br = Br $c
        $s = $g.Save(); $g.ScaleTransform(1.6, 1.6); Note $g (Pn $c 4 $k) $br -110 -20 $true; Note $g (Pn $c 4 $k) $br 50 -50 $false; L $g (Pn $c 4 $k) 78 -120 140 -140; Note $g (Pn $c 4 $k) $br 112 -70 $false; $g.Restore($s)
    }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 3.5 $k; Sparkle $g $pn -190 -230 24; Sparkle $g $pn 200 230 18 }
}

function Motif-staff($cl, $info) {
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 3 $k; for ($i = 0; $i -lt 5; $i++) { L $g $pn -240 (40 + $i * 34) 240 (40 + $i * 34) } }
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 5 $k
        $cf = New-Object Drawing.Drawing2D.GraphicsPath
        Bez $cf @(-170, 260, -230, 250, -210, 180, -170, 200); Bez $cf @(-170, 200, -140, 230, -150, 120, -190, 80); Bez $cf @(-190, 80, -230, 30, -190, -40, -175, -60)
        Bez $cf @(-175, -60, -150, -20, -230, 100, -210, 140); Bez $cf @(-210, 140, -180, 190, -110, 170, -120, 120); Bez $cf @(-120, 120, -130, 80, -200, 90, -180, 140)
        $g.DrawPath($pn, $cf); L $g $pn -175 -60 -170 260
        $br = Br $c; foreach ($n in @(@(-60, 100), @(30, 66), @(120, 134), @(200, 32))) { $g.FillEllipse($br, [float]$n[0], [float]$n[1], 34, 26); L $g $pn ($n[0] + 32) ($n[1] + 12) ($n[0] + 32) ($n[1] - 110) }
    }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 4 $k; foreach ($i in 0..2) { Arc $g $pn 0 -40 (120 + 50 * $i) 215 110 } }
}

function Motif-curtain($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pn = Pn $c 6 $k; L $g $pn -240 -260 240 -260
        foreach ($sx in -1, 1) { $g.DrawBezier($pn, (P (240 * $sx) -260), (P (120 * $sx) -100), (P (200 * $sx) 60), (P (90 * $sx) 140)); L $g $pn (90 * $sx) 140 (240 * $sx) 260 }
        Poly $g $pn @(-240, -260, -240, -200, -160, -230, -80, -200, 0, -230, 80, -200, 160, -230, 240, -200, 240, -260) -Open
    }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 3 $k; foreach ($sx in -1, 1) { $g.DrawBezier($pn, (P (200 * $sx) -200), (P (140 * $sx) -80), (P (190 * $sx) 40), (P (120 * $sx) 140)) } }
    Neon $cl[2] { param($g, $c, $k) $pn = Pn $c 4 $k; L $g $pn 0 -200 -110 200; L $g $pn 0 -200 110 200; E $g (Pn $c 5 $k) 0 210 130 28; FE $g (Br $c) 0 -200 12 12; Sparkle $g $pn 0 60 34; L $g (Pn $c 3 $k) -240 262 240 262 }
}

function Motif-mountains($cl, $info) {
    Neon $cl[2] { param($g, $c, $k) E $g (Pn $c 4 $k) 120 -170 60 60; foreach ($i in 0..5) { $t = (200 + $i * 28) * [Math]::PI / 180; L $g (Pn $c 3 $k) (120 + 80 * [Math]::Cos($t)) (-170 + 80 * [Math]::Sin($t)) (120 + 115 * [Math]::Cos($t)) (-170 + 115 * [Math]::Sin($t)) } }
    Neon $cl[0] { param($g, $c, $k) Poly $g (Pn $c 6 $k) @(-240, 200, -110, -80, -40, 40, 40, -150, 240, 200) -Open; L $g (Pn $c 6 $k) -240 200 240 200 }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 3.5 $k; Poly $g $pn @(-140, -15, -110, -80, -80, -20) -Open; Poly $g $pn @(5, -85, 40, -150, 80, -80) -Open; $g.DrawBezier($pn, (P -60 280), (P 0 240), (P -20 220), (P 40 200)) }
}

function Motif-blocks($cl, $info) {
    $bk = @(@(-200, 70, 0, 'A', -6), @(0, 70, 1, 'B', 4), @(-100, -100, 2, 'C', 8))
    foreach ($b in $bk) {
        Neon $cl[$b[2]] { param($g, $c, $k)
            $s = $g.Save(); $g.TranslateTransform($b[0] + 85, $b[1] + 85); $g.RotateTransform($b[4]); $pn = Pn $c 6 $k
            $g.DrawPath($pn, (Rounded -85 -85 170 170 16))
            $tp = New-Object Drawing.Drawing2D.GraphicsPath; $tp.AddString($b[3], (New-Object Drawing.FontFamily 'Segoe UI Black'), 0, 120, (P -40 -82), [Drawing.StringFormat]::GenericTypographic)
            $bb = $tp.GetBounds(); $mx = New-Object Drawing.Drawing2D.Matrix; $mx.Translate(-$bb.X - $bb.Width / 2, -$bb.Y - $bb.Height / 2); $tp.Transform($mx)
            $g.DrawPath((Pn $c 3.5 $k), $tp); $g.Restore($s)
        }
    }
    Neon $cl[1] { param($g, $c, $k) $pn = Pn $c 3.5 $k; Sparkle $g $pn 170 -200 26; Sparkle $g $pn -200 -230 18 }
}

# ---- Typography and palettes per parent genre ----
$Styles = @{
    Rock       = @{ Font = 'Bahnschrift SemiBold Condensed'; Bold = $true; Case = 'Upper'; Shear = -0.22; Mode = 'Fill'; Max = 230; Pal = @(@(10, 6, 14), @(40, 6, 30), @(255, 40, 140), @(255, 225, 0), @(0, 230, 255)) }
    Holiday    = @{ Font = 'Bahnschrift Light'; Case = 'Upper'; Shear = 0; Mode = 'Tube'; Max = 150; Pal = @(@(4, 14, 18), @(30, 6, 16), @(255, 50, 80), @(40, 255, 150), @(255, 210, 80)) }
    Jazz       = @{ Font = 'Segoe UI Variable Display Light'; Case = 'Title'; Shear = -0.16; Mode = 'Fill'; Max = 170; Pal = @(@(6, 8, 24), @(26, 10, 40), @(255, 170, 60), @(80, 200, 255), @(190, 120, 255)) }
    Blues      = @{ Font = 'Segoe UI Variable Display Light'; Case = 'Title'; Shear = -0.16; Mode = 'Fill'; Max = 170; Pal = @(@(2, 8, 30), @(10, 20, 60), @(60, 140, 255), @(0, 230, 255), @(200, 240, 255)) }
    Soul       = @{ Font = 'Segoe UI Variable Display Semil'; Case = 'Title'; Shear = -0.12; Mode = 'Fill'; Max = 180; Pal = @(@(16, 4, 14), @(40, 8, 30), @(255, 80, 120), @(255, 190, 70), @(180, 100, 255)) }
    Country    = @{ Font = 'Bahnschrift SemiBold SemiConden'; Case = 'Upper'; Shear = 0; Mode = 'Fill'; Max = 190; Pal = @(@(18, 8, 4), @(10, 16, 34), @(255, 140, 40), @(120, 220, 255), @(255, 210, 80)) }
    Folk       = @{ Font = 'Bahnschrift SemiBold SemiConden'; Case = 'Upper'; Shear = 0; Mode = 'Fill'; Max = 190; Pal = @(@(8, 14, 6), @(16, 22, 30), @(170, 255, 100), @(255, 180, 60), @(120, 220, 255)) }
    World      = @{ Font = 'Segoe UI Variable Display Semil'; Case = 'Title'; Shear = 0; Mode = 'Fill'; Max = 180; Pal = @(@(2, 14, 18), @(6, 14, 40), @(0, 255, 200), @(80, 160, 255), @(180, 255, 80)) }
    Pop        = @{ Font = 'Segoe UI Variable Display Semib'; Case = 'Upper'; Shear = 0; Mode = 'Fill'; Max = 190; Pal = @(@(14, 4, 24), @(30, 6, 44), @(255, 60, 220), @(0, 230, 255), @(255, 225, 0)) }
    Religious  = @{ Font = 'Segoe UI Variable Display Light'; Case = 'Upper'; Shear = 0; Mode = 'Fill'; Max = 170; Pal = @(@(8, 8, 22), @(24, 16, 40), @(255, 215, 120), @(170, 210, 255), @(200, 150, 255)) }
    Reggae     = @{ Font = 'Bahnschrift SemiBold'; Case = 'Title'; Shear = -0.18; Mode = 'Fill'; Max = 190; Pal = @(@(4, 14, 6), @(26, 18, 4), @(60, 255, 100), @(255, 230, 40), @(255, 60, 60)) }
    Latin      = @{ Font = 'Bahnschrift SemiBold'; Case = 'Title'; Shear = -0.18; Mode = 'Fill'; Max = 190; Pal = @(@(20, 6, 6), @(40, 6, 30), @(255, 120, 40), @(255, 60, 160), @(255, 225, 0)) }
    Indie      = @{ Font = 'Cascadia Mono'; Case = 'Lower'; Shear = 0; Mode = 'Fill'; Max = 170; Pal = @(@(6, 14, 14), @(24, 10, 26), @(120, 255, 200), @(255, 120, 100), @(200, 160, 255)) }
    HipHop     = @{ Font = 'Impact'; Case = 'Upper'; Shear = -0.08; Mode = 'Fill'; Max = 210; Pal = @(@(14, 10, 2), @(30, 6, 10), @(255, 200, 40), @(255, 60, 60), @(0, 230, 255)) }
    Easy       = @{ Font = 'Segoe UI Variable Display Light'; Case = 'Title'; Shear = 0; Mode = 'Fill'; Max = 170; Pal = @(@(4, 12, 22), @(20, 12, 36), @(100, 230, 255), @(190, 160, 255), @(255, 180, 140)) }
    Decades    = @{ Font = 'Bahnschrift Condensed'; Case = 'Upper'; Shear = 0; Mode = 'Tube'; Max = 200; Pal = @(@(18, 8, 4), @(6, 18, 26), @(255, 150, 50), @(0, 230, 210), @(255, 80, 160)) }
    Electronic = @{ Font = 'Bahnschrift SemiBold'; Case = 'Upper'; Shear = 0; Mode = 'Tube'; Max = 190; Pal = @(@(2, 6, 18), @(20, 2, 30), @(0, 240, 255), @(255, 0, 200), @(160, 255, 0)) }
    Classical  = @{ Font = 'Segoe UI Variable Display Light'; Case = 'Upper'; Shear = 0; Mode = 'Fill'; Max = 160; Pal = @(@(12, 8, 6), @(14, 12, 34), @(255, 210, 140), @(255, 140, 160), @(140, 180, 255)) }
    Children   = @{ Font = 'Segoe UI Black'; Case = 'Title'; Shear = 0; Mode = 'Fill'; Max = 190; Pal = @(@(6, 10, 30), @(30, 6, 30), @(255, 225, 0), @(0, 230, 255), @(255, 80, 180)) }
}

# Parent genre name -> style group and default motif.
$Parents = @{
    'Rock Music' = 'Rock', 'guitarV'; 'Holiday Music' = 'Holiday', 'gift'; 'Jazz' = 'Jazz', 'sax'; 'Blues' = 'Blues', 'acoustic'
    'Soul & R&B' = 'Soul', 'mic'; 'Country' = 'Country', 'acoustic'; 'Folk' = 'Folk', 'acoustic'; 'World Music' = 'World', 'globe'
    'Top 40 & Pop Music' = 'Pop', 'mic'; 'Powerhitz' = 'Pop', 'eq'; 'Adult Hits' = 'Pop', 'vinyl'; 'Religious Music' = 'Religious', 'cross'
    'Reggae & Dancehall' = 'Reggae', 'palm'; 'Latin Music' = 'Latin', 'maracas'; 'Indie Music' = 'Indie', 'headphones'; 'College Radio' = 'Indie', 'tower'
    'Hip Hop' = 'HipHop', 'boombox'; 'Easy Listening' = 'Easy', 'headphones'; 'Mental Health' = 'Easy', 'heart'; 'Decades Music' = 'Decades', 'cassette'
    'Classic Hits' = 'Decades', 'vinyl'; 'Boss Radio' = 'Decades', 'radio'; 'Variety' = 'Decades', 'notes'; 'Dance & Electronic' = 'Electronic', 'eq'
    'Classical Music' = 'Classical', 'violin'; "Children's Music" = 'Children', 'blocks'
}

# Subgenre name pattern -> motif override.
$Overrides = [ordered]@{
    '^(Classic Rock|AOR|Grunge)$' = 'amp'; '^Soft Rock$' = 'acoustic'; '^New Wave$' = 'keyboard'; '^Alternative Rock$' = 'headphones'; '^Indie Rock$' = 'cassette'; '^AAA$' = 'vinyl'
    '^Christmas Music$' = 'tree'; '^Classical Holiday$' = 'candles'; '^(Contemporary|R&B) Holiday$' = 'ornament'; '^(Country|Traditional) Holiday$' = 'wreath'; '^New Holiday Hits$' = 'bells'; '^Religious Christmas' = 'starRays'
    '^Latin Jazz$' = 'trumpet'; '^Funk$' = 'discoBall'; '^R&B' = 'vinyl'
    '^Americana' = 'mountains'; '^Bluegrass' = 'banjo'; '^Classic Country$' = 'radio'; '^Pop Country$' = 'mic'
    '^Hot AC' = 'mic'; '^Rhythmic AC' = 'eq'
    '^Christian Rock$' = 'guitarV'; '^Evang' = 'book'; '^Gospel$' = 'mic'; '^Islamic' = 'crescent'; '^Jewish' = 'starDavid'
    '^Baladas$' = 'heart'; '^Pop Latino$' = 'mic'; '^Reggaeton$' = 'eq'; '^Regional Mexican' = 'trumpet'; '^Rock en Espa' = 'guitarV'; '^Tropical' = 'palm'; '^Urbano' = 'boombox'
    '^Classic Hip Hop$' = 'vinyl'; '^Ambient' = 'moonStars'; '^Lounge$' = 'cocktail'; '^New Age' = 'lotus'
    '^(Breakbeats|Chill|Dubstep)$' = 'wave'; '^Dance$' = 'discoBall'; '^DJ$' = 'vinyl'; '^Drum' = 'drum'; '^Electronic$' = 'keyboard'; '(Garage|Techno)$' = 'seqGrid'; '^House$' = 'house'; '^Trance$' = 'rings'
    '^Modern Classical$' = 'keyboard'; '^Opera$' = 'curtain'; '^Symphony$' = 'staff'
}
# Breakbeats keeps the eq motif (with gaps) rather than a wave.
$Overrides.Insert(0, '^Breakbeats$', 'eq')

$Places = @{
    African = 5, 20; Arabic = 25, 45; Asian = 35, 100; Austrian = 47.5, 14; Bollywood = 19, 73; Brazilian = -10, -52; Bulgarian = 42.7, 25
    Caribbean = 18, -72; Celtic = 53, -8; Chinese = 35, 105; Dutch = 52.3, 5; 'Euro Hits' = 50, 10; European = 50, 10; French = 46, 2
    German = 51, 10; Greek = 39, 22; Hawaiian = 20, -157; Indian = 21, 78; Irish = 53, -8; Italian = 42, 12.5; Japanese = 36, 138
    'K-Pop' = 36.5, 128; Korean = 36.5, 128; Lithuanian = 55, 24; 'Middle Eastern' = 29, 45; Pakistani = 30, 70; Polish = 52, 19
    Polka = 50, 15; Portuguese = 39.5, -8; Romanian = 46, 25; Russian = 56, 38; Spanish = 40, -4; Swedish = 62, 15; Tamil = 11, 78.5
    Turkish = 39, 35; Vietnamese = 16, 107
}

function Title-Path([string]$text, $st) {
    $text = switch ($st.Case) { 'Upper' { $text.ToUpperInvariant() } 'Lower' { $text.ToLowerInvariant() } default { $text } }
    $words = @([regex]::Matches($text, '[^ /]+/?') | ForEach-Object Value)
    $family = New-Object Drawing.FontFamily $st.Font
    $fs = if ($st.Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $shear = New-Object Drawing.Drawing2D.Matrix 1, 0, $st.Shear, 1, 0, 0
    $best = $null; $bestSize = 0; $bestLines = 9
    $n = $words.Count
    for ($mask = 0; $mask -lt [Math]::Pow(2, [Math]::Max(0, $n - 1)); $mask++) {
        $lines = @(); $cur = $words[0]
        for ($i = 1; $i -lt $n; $i++) {
            if ($mask -band (1 -shl ($i - 1))) { $lines += $cur; $cur = $words[$i] }
            elseif ($cur.EndsWith('/')) { $cur += $words[$i] } else { $cur += ' ' + $words[$i] }
        }
        $lines += $cur
        if ($lines.Count -gt 3) { continue }
        for ($size = $st.Max; $size -ge 40; $size -= 6) {
            $path = New-Object Drawing.Drawing2D.GraphicsPath; $path.FillMode = 'Winding'
            for ($i = 0; $i -lt $lines.Count; $i++) { $path.AddString($lines[$i], $family, [int]$fs, $size, (P 0 ($i * $size * 1.02)), [Drawing.StringFormat]::GenericTypographic) }
            $path.Transform($shear); $b = $path.GetBounds()
            if ($b.Width -le 640 -and $b.Height -le 380) {
                if ($size -gt $bestSize -or ($size -eq $bestSize -and $lines.Count -lt $bestLines)) { $best = $path; $bestSize = $size; $bestLines = $lines.Count }
                break
            }
        }
    }
    $b = $best.GetBounds(); $mx = New-Object Drawing.Drawing2D.Matrix
    $mx.Translate(95 - $b.X, 330 - $b.Height / 2 - $b.Y); $best.Transform($mx); $best
}

function New-Card($info, [string]$file) {
    $st = $Styles[$info.Style]
    $pal = foreach ($p in $st.Pal) { Rgb $p[0] $p[1] $p[2] }
    $cl = @($pal[2], $pal[3], $pal[4])
    if ($info.Sub) { $r = $info.Seed % 3; $cl = @($cl[$r], $cl[($r + 1) % 3], $cl[($r + 2) % 3]) }
    $bmp = New-Object Drawing.Bitmap 1280, 720
    $script:G = [Drawing.Graphics]::FromImage($bmp); $g0 = $script:G
    $g0.SmoothingMode = 'AntiAlias'; $g0.CompositingQuality = 'HighQuality'; $g0.InterpolationMode = 'HighQualityBicubic'
    $g0.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush (P 0 0), (P 0 720), $pal[0], $pal[1]), 0, 0, 1280, 720)
    $glow = New-Object Drawing.Drawing2D.GraphicsPath; $glow.AddEllipse(680, 40, 640, 640)
    $rb = New-Object Drawing.Drawing2D.PathGradientBrush $glow; $rb.CenterColor = Argb 35 $cl[0]; $rb.SurroundColors = @([Drawing.Color]::Transparent)
    $g0.FillPath($rb, $glow)

    $sub = $pal[3]
    $hud = New-Object Drawing.Pen (Argb 170 $sub), 4
    foreach ($cn in @(@(40, 40, 1, 1), @(1240, 40, -1, 1), @(40, 680, 1, -1), @(1240, 680, -1, -1))) {
        $g0.DrawLine($hud, $cn[0], $cn[1], $cn[0] + 60 * $cn[2], $cn[1]); $g0.DrawLine($hud, $cn[0], $cn[1], $cn[0], $cn[1] + 60 * $cn[3])
    }

    & "Motif-$($info.Motif)" $cl $info

    $title = Title-Path $info.Name $st
    if ($st.Mode -eq 'Tube') {
        Neon $cl[0] { param($g, $c, $k) $g.DrawPath((Pn $c 5.7 $k), $title) } 0 0
    } else {
        Neon $cl[0] { param($g, $c, $k) $g.FillPath((Br $c), $title) } 0 0
        $g0.FillPath((Br (Rgb 250 248 255)), $title)
    }
    $label = if ($info.Sub) { $info.Parent } else { 'Music' }
    $spaced = '//  ' + (($label.ToUpperInvariant().ToCharArray() | ForEach-Object { [string]$_ }) -join ' ')
    $subFont = if ($info.Style -eq 'Indie') { 'Cascadia Mono' } else { 'Bahnschrift' }
    $g0.DrawString($spaced, (New-Object Drawing.Font $subFont, 28, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)), (Br (Argb 235 $sub)), 96, 560)

    $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
    $ep = New-Object Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), ([long]80)
    $g0.Dispose(); $bmp.Save($file, $codec, $ep); $bmp.Dispose()
}

function Get-Opml([string]$url) {
    [xml][Text.Encoding]::UTF8.GetString((Invoke-WebRequest -UseBasicParsing $url).RawContentStream.ToArray())
}

$genres = [ordered]@{}
foreach ($top in (Get-Opml 'http://opml.radiotime.com/Browse.ashx?c=music').opml.body.outline | Where-Object { $_.type -eq 'link' -and $_.guide_id -match '^[cg]\d+$' }) {
    $parent = $top.text
    if (-not $Parents.ContainsKey($parent)) { Write-Warning "Unknown parent genre '$parent'; using the Pop style."; $Parents[$parent] = 'Pop', 'notes' }
    $genres[$top.guide_id] = @{ Id = $top.guide_id; Name = $parent; Parent = $parent; Sub = $false }
    foreach ($o in (Get-Opml "http://opml.radiotime.com/Browse.ashx?id=$($top.guide_id)").SelectNodes('//outline[@guide_id]')) {
        if ($o.guide_id -match '^g\d+$' -and -not $genres.Contains($o.guide_id)) { $genres[$o.guide_id] = @{ Id = $o.guide_id; Name = $o.text; Parent = $parent; Sub = $true } }
    }
}

New-Item -ItemType Directory -Force $Output | Out-Null
foreach ($info in $genres.Values) {
    if ($Only -and -not ($Only | Where-Object { $info.Id -eq $_ -or $info.Name -like $_ })) { continue }
    $seed = 0; foreach ($ch in $info.Id.ToCharArray()) { $seed = ($seed * 31 + [int]$ch) % 2147483647 }
    $info.Seed = [int]$seed
    $info.Style = $Parents[$info.Parent][0]
    $info.Motif = $Parents[$info.Parent][1]
    if ($info.Sub) { foreach ($rx in $Overrides.Keys) { if ($info.Name -match $rx) { $info.Motif = $Overrides[$rx]; break } } }
    if ($info.Style -eq 'World' -and $Places.ContainsKey(($place = $info.Name -replace ' Music$'))) { $info.Lat = $Places[$place][0]; $info.Lon = $Places[$place][1] }
    New-Card $info (Join-Path $Output "$($info.Id).jpg")
    Write-Host "$($info.Id)  $($info.Name)  [$($info.Style)/$($info.Motif)]"
}
