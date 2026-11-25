<#
Builds 1280x720 JPEG genre, language, location or root category artwork packs for the Emby TuneIn plugin. -Theme picks the overall look
(Neon, Retro, Futuristic, Cartoon, Cat, Dog, Nature, Blocky, Rebel, Imperial, Elegant, Tile, Classic, or a Spotlight
variant). Run on Windows PowerShell with the fonts that ship with Windows 11 (Bahnschrift,
Segoe UI Variable, Segoe UI, Segoe UI Black, Cascadia, Impact, Georgia and Franklin Gothic). It also writes tunein-artwork.json, a manifest the TuneIn plugin uses to identify the pack.
-Pack also writes a ZIP for the matching plugins\configurations\TuneInArtwork scope folder.
#>
param(
    [string]$Output,
    [string[]]$Only,
    [ValidateSet('genres', 'languages', 'locations', 'categories')]
    [string]$Scope = 'genres',
    [ValidatePattern('^r(?:0|[1-9][0-9]{0,9})$')]
    [string]$LocationRoot = 'r0',
    [ValidateRange(0, 3)]
    [int]$LocationRootLevel = 0,
    [ValidateRange(1, 4)]
    [int]$LocationDepth = 4,
    [ValidateRange(1, 10000)]
    [int]$MaxLocationRequests = 1000,
    [switch]$AllLocations,
    [string]$CatalogSnapshot,
    [switch]$NeutralLanguages,
    [switch]$RequireScopedScenery,
    [ValidateSet('Neon', 'Retro', 'Futuristic', 'Cartoon', 'Cat', 'Dog', 'Nature', 'Blocky', 'Rebel', 'Imperial', 'Elegant', 'Tile', 'Classic', 'FuturisticSpotlight', 'CartoonSpotlight', 'ClassicSpotlight')]
    [string]$Theme = 'Futuristic',
    # Writes a ZIP beside Output; explicit PackName overrides its default name and manifest identity.
    [switch]$Pack,
    [string]$PackName,
    # Pack version recorded in tunein-artwork.json.
    [string]$PackVersion = '1'
)
$ErrorActionPreference = 'Stop'
$Scope = $Scope.ToLowerInvariant()
$customPackName = [bool]$PackName
if (-not $PackName) { $PackName = 'artpack-' + $Theme.ToLowerInvariant(); if ($Scope -ne 'genres') { $PackName += "-$Scope" } }
if ($PackName -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') { throw 'PackName must be an ASCII pack ID of 1-128 letters, digits, dots, underscores or hyphens, beginning with a letter or digit.' }
if ($PackVersion -cnotmatch '^[0-9A-Za-z][0-9A-Za-z.+_-]{0,63}$') { throw 'PackVersion must be an ASCII version token of 1-64 letters, digits, dots, plus signs, underscores or hyphens, beginning with a letter or digit.' }
$zipName = if (-not $customPackName -and $Scope -eq 'genres') { "$PackName-genres" } else { $PackName }
if ($Pack -and $zipName -match '^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)') { throw 'PackName is reserved as a Windows ZIP file name.' }
if ($LocationRoot -cnotmatch '^r(?:0|[1-9][0-9]{0,9})$') { throw 'LocationRoot must be a lowercase TuneIn location ID.' }
if (-not $Output) { $Output = Join-Path $PSScriptRoot "output\$Scope" }
if (($LocationRoot -eq 'r0') -ne ($LocationRootLevel -eq 0)) { throw 'LocationRoot r0 requires level 0; other roots require a level from 1 to 3.' }
if ($LocationDepth -lt $LocationRootLevel) { throw 'LocationDepth cannot be less than LocationRootLevel.' }
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

$script:G = $null; $script:OX = 1000; $script:OY = 360; $script:Weight = 0.7; $script:ArtScale = 1
# Glow layers are composited at reduced opacity so line art stays crisp rather than blurry.
$script:GlowAttr = New-Object Drawing.Imaging.ImageAttributes
$script:Mask = New-Object Drawing.Bitmap 1280, 720
$script:Smalls = foreach ($sc in 0.08, 0.04, 0.02) { New-Object Drawing.Bitmap ([int](1280 * $sc)), ([int](720 * $sc)) }
$script:Full = New-Object Drawing.Rectangle 0, 0, 1280, 720
# Pixel art is drawn at 1/8 scale and enlarged without smoothing; ShadeAttr turns a layer into its shadow.
$script:Pix = New-Object Drawing.Bitmap 160, 90
$script:ShadeAttr = New-Object Drawing.Imaging.ImageAttributes
$__sm = New-Object Drawing.Imaging.ColorMatrix; $__sm.Matrix00 = 0; $__sm.Matrix11 = 0; $__sm.Matrix22 = 0; $__sm.Matrix33 = 0.45
$script:ShadeAttr.SetColorMatrix($__sm)

# Moves the origin to ($ox, $oy), scaled about the artwork centre by the theme's $script:ArtScale.
function Place($gr, [float]$ox, [float]$oy) {
    $gr.TranslateTransform($script:OX, $script:OY); $gr.ScaleTransform($script:ArtScale, $script:ArtScale)
    $gr.TranslateTransform($ox - $script:OX, $oy - $script:OY)
}

# Paints scriptblock $__paint (Graphics) at 1/8 scale, then enlarges it with hard pixel edges and a one-block shadow.
function Pixel-Layer([scriptblock]$__paint) {
    $__pg = [Drawing.Graphics]::FromImage($script:Pix); $__pg.Clear([Drawing.Color]::Transparent)
    $__pg.SmoothingMode = 'None'; $__pg.ScaleTransform(0.125, 0.125)
    & $__paint $__pg; $__pg.Dispose()
    $script:G.InterpolationMode = 'NearestNeighbor'; $script:G.PixelOffsetMode = 'Half'
    $script:G.DrawImage($script:Pix, (New-Object Drawing.Rectangle 8, 8, 1280, 720), 0, 0, 160, 90, 'Pixel', $script:ShadeAttr)
    $script:G.DrawImage($script:Pix, $script:Full, 0, 0, 160, 90, 'Pixel')
    $script:G.InterpolationMode = 'HighQualityBicubic'; $script:G.PixelOffsetMode = 'Default'
}

# Draws scriptblock $draw (Graphics, Color, width multiplier) in the theme's line-art style:
# Glow (blurred glow, crisp core, hot white centre), Flat (optional shadow and outline) or Pixel.
# Motif coordinates are relative to ($script:OX, $script:OY), the centre of the artwork area.
function Neon($__col, [scriptblock]$__draw, [float]$__ox = $script:OX, [float]$__oy = $script:OY) {
    $__art = $script:T.Art
    if ($__art.Mode -eq 'Pixel') {
        Pixel-Layer { param($__p) Place $__p $__ox $__oy; & $__draw $__p $__col $__art.K }
        return
    }
    if ($__art.Mode -eq 'Flat') {
        if ($__art.Shadow) {
            $__st = $script:G.Save(); $script:G.TranslateTransform($__art.Shadow, $__art.Shadow); Place $script:G $__ox $__oy
            & $__draw $script:G (Argb $__art.ShadowAlpha $__art.ShadowColor) $__art.K; $script:G.Restore($__st)
        }
        if ($__art.Outline) {
            $__st = $script:G.Save(); Place $script:G $__ox $__oy
            & $__draw $script:G $__art.Outline ($__art.K + $__art.OutlineK); $script:G.Restore($__st)
        }
        $__st = $script:G.Save(); Place $script:G $__ox $__oy
        & $__draw $script:G $__col $__art.K; $script:G.Restore($__st)
        return
    }
    $__mg = [Drawing.Graphics]::FromImage($script:Mask); $__mg.Clear([Drawing.Color]::Transparent)
    $__mg.SmoothingMode = 'AntiAlias'; Place $__mg $__ox $__oy
    & $__draw $__mg $__col 3; $__mg.Dispose()
    foreach ($__sm in $script:Smalls) {
        $__sg = [Drawing.Graphics]::FromImage($__sm); $__sg.Clear([Drawing.Color]::Transparent); $__sg.InterpolationMode = 'HighQualityBilinear'
        $__sg.DrawImage($script:Mask, 0, 0, $__sm.Width, $__sm.Height); $__sg.Dispose()
        $script:G.DrawImage($__sm, $script:Full, 0, 0, $__sm.Width, $__sm.Height, 'Pixel', $script:GlowAttr)
    }
    if ($__art.Ghost) {
        foreach ($__gh in @(@(-4, (Rgb 255 40 200)), @(4, (Rgb 40 220 255)))) {
            $__st = $script:G.Save(); $script:G.TranslateTransform($__gh[0], 0); Place $script:G $__ox $__oy
            & $__draw $script:G (Argb 90 $__gh[1]) 1; $script:G.Restore($__st)
        }
    }
    $__st = $script:G.Save(); Place $script:G $__ox $__oy
    & $__draw $script:G $__col 1
    if ($__art.Core) { & $__draw $script:G $__art.Core 0.4 }
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
    if ($kind -eq 'calm') { Neon $cl[2] { param($g, $c, $k) $g.DrawPolygon((Pn $c 4 $k), (CrescentPts 60 25 -20 52)) } ($script:OX + 180) ($script:OY - 220) }
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

function Motif-sports($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pen = Pn $c 6 $k
        E $g $pen 0 0 190 190
        L $g $pen -190 0 190 0; L $g $pen 0 -190 0 190
        $g.DrawArc($pen, -250, -190, 300, 380, -65, 130)
        $g.DrawArc($pen, -50, -190, 300, 380, 115, 130)
    }
}

function Motif-speech($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pen = Pn $c 6 $k
        $bubble = Rounded -220 -150 340 220 35
        try { $g.DrawPath($pen, $bubble) } finally { $bubble.Dispose() }
        Poly $g $pen @(-140, 70, -155, 125, -90, 70) -Open
        L $g $pen -165 -80 65 -80; L $g $pen -165 -25 20 -25
    }
    Neon $cl[1] { param($g, $c, $k)
        $pen = Pn $c 6 $k
        $bubble = Rounded -15 85 235 145 30
        try { $g.DrawPath($pen, $bubble) } finally { $bubble.Dispose() }
        Poly $g $pen @(145, 230, 160, 275, 105, 230) -Open
        L $g $pen 25 135 180 135; L $g $pen 25 175 145 175
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

function Get-TitleFamily([string]$name) {
    $files = @{ 'Noto Sans Khmer'='NotoSansKhmer-Regular.ttf'; 'Noto Serif KR'='NotoSerifKR-Regular.otf' }
    if ($files.ContainsKey($name)) {
        if (-not $script:PrivateFonts) { $script:PrivateFonts = @{} }
        if (-not $script:PrivateFonts.ContainsKey($name)) {
            $script:PrivateFonts[$name] = New-Object Drawing.Text.PrivateFontCollection
            $script:PrivateFonts[$name].AddFontFile((Join-Path $PSScriptRoot "data\$($files[$name])"))
        }
        $family = @($script:PrivateFonts[$name].Families | Where-Object { $_.Name -eq $name })
        if ($family.Count -ne 1) { throw "Bundled font '$name' could not be loaded." }
        return $family[0]
    }
    $family = New-Object Drawing.FontFamily $name
    if ($family.Name -ne $name) { throw "Required font '$name' is not installed." }
    return $family
}

function Title-Path([string]$text, $st, [switch]$BreakHyphen) {
    $text = switch ($st.Case) { 'Upper' { $text.ToUpperInvariant() } 'Lower' { $text.ToLowerInvariant() } default { $text } }
    $pattern = if ($BreakHyphen) { '[^ /-]+[-/]*|[-/]+' } else { '[^ /]+/?' }
    $words = @([regex]::Matches($text, $pattern) | ForEach-Object Value)
    if ($words.Count -eq 0 -or $words.Count -gt 12) { throw "Title has an unsupported number of words: $text" }
    $family = Get-TitleFamily $st.Font
    $fs = if ($st.Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $shear = New-Object Drawing.Drawing2D.Matrix 1, 0, $st.Shear, 1, 0, 0
    $best = $null; $bestSize = 0; $bestLines = 9
    $n = $words.Count
    for ($mask = 0; $mask -lt [Math]::Pow(2, [Math]::Max(0, $n - 1)); $mask++) {
        $lines = @(); $cur = $words[0]
        for ($i = 1; $i -lt $n; $i++) {
            if ($mask -band (1 -shl ($i - 1))) { $lines += $cur; $cur = $words[$i] }
            elseif ($cur.EndsWith('/') -or ($BreakHyphen -and $cur.EndsWith('-'))) { $cur += $words[$i] } else { $cur += ' ' + $words[$i] }
        }
        $lines += $cur
        if ($lines.Count -gt 3) { continue }
        for ($size = $st.Max; $size -ge 40; $size -= 6) {
            $path = New-Object Drawing.Drawing2D.GraphicsPath; $path.FillMode = 'Winding'
            $fmt = [Drawing.StringFormat]::GenericTypographic.Clone()
            $fmt.FormatFlags = $fmt.FormatFlags -band (-bnot [int][Drawing.StringFormatFlags]::DirectionRightToLeft)
            if ($script:CurrentRTL) { $fmt.FormatFlags = $fmt.FormatFlags -bor [Drawing.StringFormatFlags]::DirectionRightToLeft }
            for ($i = 0; $i -lt $lines.Count; $i++) { $path.AddString($lines[$i], $family, [int]$fs, $size, (P 0 ($i * $size * 1.02)), $fmt) }
            $fmt.Dispose()
            $path.Transform($shear); $b = $path.GetBounds()
            if ($b.Width -le 640 -and $b.Height -le 380) {
                if ($size -gt $bestSize -or ($size -eq $bestSize -and $lines.Count -lt $bestLines)) { $best = $path; $bestSize = $size; $bestLines = $lines.Count }
                break
            }
        }
    }
    if (-not $best -and -not $BreakHyphen -and $text.Contains('-')) { return Title-Path $text $st -BreakHyphen }
    if (-not $best) { throw "Title cannot fit: $text" }
    $b = $best.GetBounds(); $mx = New-Object Drawing.Drawing2D.Matrix
    $mx.Translate(95 - $b.X, 330 - $b.Height / 2 - $b.Y); $best.Transform($mx); $best
}

# ---- Themes: background, line-art mode, typography and optional character for every card ----
function RgbF([double]$r, [double]$gr, [double]$bl) { Rgb ([Math]::Max(0, [Math]::Min(255, $r))) ([Math]::Max(0, [Math]::Min(255, $gr))) ([Math]::Max(0, [Math]::Min(255, $bl))) }
# Blends colour $a toward $b by $t (0..1).
function Mix($a, $b, [double]$t) { RgbF ($a.R + ($b.R - $a.R) * $t) ($a.G + ($b.G - $a.G) * $t) ($a.B + ($b.B - $a.B) * $t) }
# Returns $v, or the entry for $style (falling back to Default) when $v is a hashtable.
function Pick($v, [string]$style) { if ($v -is [hashtable]) { if ($v.ContainsKey($style)) { $v[$style] } else { $v.Default } } else { $v } }
function Linear($c1, $c2, [float]$y1 = 0, [float]$y2 = 720) { New-Object Drawing.Drawing2D.LinearGradientBrush (P 0 $y1), (P 0 $y2), $c1, $c2 }
function Glow-Spot($gr, $col, [int]$alpha, [float]$cx, [float]$cy, [float]$r) {
    $path = New-Object Drawing.Drawing2D.GraphicsPath; $path.AddEllipse($cx - $r, $cy - $r, 2 * $r, 2 * $r)
    $rb = New-Object Drawing.Drawing2D.PathGradientBrush $path; $rb.CenterColor = Argb $alpha $col; $rb.SurroundColors = @([Drawing.Color]::Transparent)
    $gr.FillPath($rb, $path)
}
# Runs $paint (Graphics) with the origin moved to ($x, $y), rotated by $deg and scaled by $s.
function At($gr, [float]$x, [float]$y, [float]$deg, [float]$s, [scriptblock]$paint) {
    $state = $gr.Save(); $gr.TranslateTransform($x, $y); $gr.RotateTransform($deg); $gr.ScaleTransform($s, $s); & $paint $gr; $gr.Restore($state)
}
function Shifted($path, [float]$dx, [float]$dy) { $p = $path.Clone(); $p.Transform((New-Object Drawing.Drawing2D.Matrix 1, 0, 0, 1, $dx, $dy)); $p }
function Outline-Pen($col, [float]$w) { $pen = New-Object Drawing.Pen $col, $w; $pen.LineJoin = 'Round'; $pen }
# Scatters $paint over the card on a jittered grid, skipping the soft circle behind the artwork.
function Scatter($gr, $rnd, [float]$step, [scriptblock]$paint) {
    for ($y = 30; $y -lt 720; $y += $step) {
        for ($x = 30 + ($y / $step % 2) * $step / 2; $x -lt 1280; $x += $step) {
            $px = $x + $rnd.Next(-18, 19); $py = $y + $rnd.Next(-18, 19)
            if ([Math]::Pow($px - $script:OX, 2) + [Math]::Pow($py - $script:OY, 2) -lt 250 * 250) { continue }
            At $gr $px $py ($rnd.Next(-35, 36)) (0.7 + $rnd.NextDouble() * 0.5) $paint
        }
    }
}
function PawPrint($gr, $brush) { FE $gr $brush 0 8 17 14; foreach ($t in @(@(-17, -10), @(-6, -20), @(6, -20), @(17, -10))) { FE $gr $brush $t[0] $t[1] 6 8 } }
function Bone($gr, $brush) { $gr.FillRectangle($brush, -22, -5, 44, 10); foreach ($e in @(@(-22, -6), @(-22, 6), @(22, -6), @(22, 6))) { FE $gr $brush $e[0] $e[1] 8 8 } }
# Fills a seeded mountain ridge that rises $rise pixels from left to right; returns its outline points.
function Ridge($gr, $brush, [float]$base, [float]$rise, [float]$amp, $rnd) {
    $p1 = $rnd.NextDouble() * 6; $p2 = $rnd.NextDouble() * 6
    $v = @(0, 720); for ($x = 0; $x -le 1280; $x += 32) { $v += $x; $v += $base - $rise * $x / 1280 + $amp * ([Math]::Sin($x / 97 + $p1) + 0.5 * [Math]::Sin($x / 41 + $p2)) }
    $v += 1280; $v += 720; $pts = Pts $v; $gr.FillPolygon($brush, $pts); , $pts
}
function Pine($gr, $brush, [float]$x, [float]$y, [float]$h) {
    for ($i = 0; $i -lt 3; $i++) { $w = $h * (0.42 - 0.1 * $i); $top = $y - $h * (0.45 + 0.27 * $i); $gr.FillPolygon($brush, (Pts @(($x - $w), ($top + $h * 0.42), $x, $top, ($x + $w), ($top + $h * 0.42)))) }
    $gr.FillRectangle($brush, $x - $h * 0.04, $y - $h * 0.06, $h * 0.08, $h * 0.08)
}
function Spaced([string]$s) { ($s.ToUpperInvariant().ToCharArray() | ForEach-Object { [string]$_ }) -join ' ' }

# A cartoon cat in headphones, head centred at (1040, 560); fur colour and eye colour vary by genre.
function Draw-Cat($gr, $cl, $info) {
    $furs = @(@((Rgb 242 152 64), (Rgb 200 100 30)), @((Rgb 160 162 172), (Rgb 110 112 124)), @((Rgb 58 52 62), (Rgb 30 26 34)), @((Rgb 246 228 196), (Rgb 214 180 140)))
    $fur = $furs[$info.Seed % 4]; $ink = Rgb 58 36 52; $pink = Rgb 255 150 170; $ol = Outline-Pen $ink 6; $fb = Br $fur[0]
    FE $gr $fb 1040 740 175 125; E $gr $ol 1040 740 175 125
    foreach ($s in -1, 1) {
        $ear = Pts @((1040 + 112 * $s), 500, (1040 + 92 * $s), 382, (1040 + 30 * $s), 462)
        $gr.FillPolygon($fb, $ear); $gr.DrawPolygon($ol, $ear)
        $gr.FillPolygon((Br $pink), (Pts @((1040 + 96 * $s), 482, (1040 + 88 * $s), 412, (1040 + 50 * $s), 466)))
    }
    FE $gr $fb 1040 565 132 112; E $gr $ol 1040 565 132 112
    if ($info.Seed % 4 -eq 0) { $sp = Pn $fur[1] 9 1.6; L $gr $sp 1040 462 1040 500; L $gr $sp 1010 466 1016 498; L $gr $sp 1070 466 1064 498 }
    $eye = if ($info.Seed % 4 -eq 2) { Rgb 190 220 80 } else { $ink }
    foreach ($s in -1, 1) {
        FE $gr (Br $eye) (1040 + 46 * $s) 552 17 21
        if ($info.Seed % 4 -eq 2) { FE $gr (Br $ink) (1040 + 46 * $s) 552 6 17 }
        FE $gr (Br (Rgb 255 255 255)) (1046 + 46 * $s) 543 6 6
        FE $gr (Br (Argb 110 $pink)) (1040 + 82 * $s) 600 18 11
        $wp = Pn $ink 3 1; L $gr $wp (1040 + 70 * $s) 592 (1040 + 150 * $s) 578; L $gr $wp (1040 + 70 * $s) 604 (1040 + 150 * $s) 610
    }
    $gr.FillPolygon((Br $pink), (Pts @(1028, 584, 1052, 584, 1040, 597)))
    $mp = Pn $ink 4 1; Arc $gr $mp 1028 598 12 0 180; Arc $gr $mp 1052 598 12 0 180
    $band = New-Object Drawing.Pen $cl[0], 18; Arc $gr $band 1040 560 150 195 150
    foreach ($s in -1, 1) { $cup = Rounded (1040 + 152 * $s - 24) 512 48 100 20; $gr.FillPath((Br $cl[0]), $cup); $gr.DrawPath($ol, $cup) }
    foreach ($s in -1, 1) { FE $gr $fb (1040 + 62 * $s) 698 40 26; E $gr $ol (1040 + 62 * $s) 698 40 26 }
}

# A cartoon dog in a bandana, head centred at (1040, 560); fur, spot and tongue vary by genre.
function Draw-Dog($gr, $cl, $info) {
    $furs = @(@((Rgb 214 160 96), (Rgb 150 96 50)), @((Rgb 150 96 60), (Rgb 90 56 34)), @((Rgb 248 244 236), (Rgb 150 100 66)), @((Rgb 54 50 54), (Rgb 24 22 26)))
    $fur = $furs[$info.Seed % 4]; $ink = Rgb 44 32 30; $ol = Outline-Pen $ink 6; $fb = Br $fur[0]
    FE $gr $fb 1040 750 180 125; E $gr $ol 1040 750 180 125
    $bandana = Pts @(920, 640, 1160, 640, 1040, 735)
    $gr.FillPolygon((Br $cl[0]), $bandana); $gr.DrawPolygon($ol, $bandana)
    foreach ($d in @(@(990, 668), @(1040, 690), @(1090, 668), @(1040, 652))) { FE $gr (Br (Argb 200 (Rgb 255 255 255))) $d[0] $d[1] 7 7 }
    FE $gr $fb 1040 560 126 116; E $gr $ol 1040 560 126 116
    if ($info.Seed % 4 -eq 2) { FE $gr (Br $fur[1]) 1088 530 40 36 }
    foreach ($s in -1, 1) {
        At $gr (1040 + 122 * $s) 520 (-22 * $s) 1 { param($g) FE $g (Br $fur[1]) 0 52 40 92; E $g $ol 0 52 40 92 }
        FE $gr (Br $ink) (1040 + 44 * $s) 538 15 17; FE $gr (Br (Rgb 255 255 255)) (1046 + 44 * $s) 531 5 5
    }
    $snout = Mix $fur[0] (Rgb 255 250 240) 0.55
    FE $gr (Br $snout) 1040 612 64 46; E $gr (Outline-Pen $ink 4) 1040 612 64 46
    if ($info.Seed % 2) { FE $gr (Br (Rgb 240 110 120)) 1040 650 17 22; L $gr (Pn (Rgb 200 70 90) 3 1) 1040 640 1040 662 }
    FE $gr (Br $ink) 1040 590 23 16
    $mp = Pn $ink 4 1; L $gr $mp 1040 604 1040 622; Arc $gr $mp 1022 620 18 10 160; Arc $gr $mp 1058 620 18 10 160
    foreach ($s in -1, 1) { FE $gr $fb (1040 + 66 * $s) 702 42 26; E $gr $ol (1040 + 66 * $s) 702 42 26 }
}

$Ink = Rgb 62 36 22
function Center-Title($gr, [string]$text, [string]$font, $bold, [string]$case, [float]$shear, [float]$cy, [float]$maxW, [float]$maxH, [int]$size) {
    $text = switch ($case) { 'Upper' { $text.ToUpperInvariant() } 'Lower' { $text.ToLowerInvariant() } default { $text } }
    $fmt = New-Object Drawing.StringFormat; $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
    if ($script:CurrentRTL) { $fmt.FormatFlags = $fmt.FormatFlags -bor [Drawing.StringFormatFlags]::DirectionRightToLeft }
    $fs = if ($bold) { [int][Drawing.FontStyle]::Bold } else { 0 }
    do {
        $tp = New-Object Drawing.Drawing2D.GraphicsPath
        $tp.AddString($text, (Get-TitleFamily $font), $fs, $size, (New-Object Drawing.RectangleF 40, ($cy - 300), 1200, 600), $fmt)
        if ($shear) { $tp.Transform((New-Object Drawing.Drawing2D.Matrix 1, 0, $shear, 1, (-$shear * $cy), 0)) }
        $b = $tp.GetBounds(); $size -= 4
    } while (($b.Width -gt $maxW -or $b.Height -gt $maxH) -and $size -gt 30)
    $tp
}

function Centered-Sub($gr, [string]$text, [string]$font, [int]$size, $color, [float]$y) {
    $f = New-Object Drawing.Font $font, $size, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
    $w = $gr.MeasureString($text, $f).Width; $gr.DrawString($text, $f, (Br $color), (640 - $w / 2), $y)
}

$Themes = @{    Neon       = @{
        Description = 'Glowing neon line art on dark gradients (the original pack).'
        Art = @{ Mode = 'Glow'; Glow = 0.65; Core = (Argb 150 (Rgb 255 255 255)) }
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((Linear $pal[0] $pal[1]), 0, 0, 1280, 720)
            Glow-Spot $gr $cl[0] 35 1000 360 320
            $hud = New-Object Drawing.Pen (Argb 170 $pal[3]), 4
            foreach ($cn in @(@(40, 40, 1, 1), @(1240, 40, -1, 1), @(40, 680, 1, -1), @(1240, 680, -1, -1))) {
                L $gr $hud $cn[0] $cn[1] ($cn[0] + 60 * $cn[2]) $cn[1]; L $gr $hud $cn[0] $cn[1] $cn[0] ($cn[1] + 60 * $cn[3])
            }
        }
        Title = { param($gr, $title, $cl, $pal, $st)
            if ($st.Mode -eq 'Tube') { Neon $cl[0] { param($g, $c, $k) $g.DrawPath((Pn $c 5.7 $k), $title) } 0 0 }
            else { Neon $cl[0] { param($g, $c, $k) $g.FillPath((Br $c), $title) } 0 0; $gr.FillPath((Br (Rgb 250 248 255)), $title) }
        }
        SubFont = @{ Indie = 'Cascadia Mono'; Default = 'Bahnschrift' }; SubPrefix = '//  '; Sub = { param($cl, $pal) Argb 235 $pal[3] }
    }
    Retro      = @{
        Description = 'Cream paper, sunburst, stripes and offset print shadows in a muted 1970s palette.'
        Color = { param($p) RgbF ((0.65 * $p[0] + 52) * 0.85) ((0.65 * $p[1] + 31) * 0.85) ((0.65 * $p[2] + 17) * 0.85) }
        Art = @{ Mode = 'Flat'; K = 1.8; Shadow = 7; ShadowColor = $Ink; ShadowAlpha = 110 }
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((Linear (Rgb 246 235 210) (Rgb 234 214 176)), 0, 0, 1280, 720)
            $ray = Br (Argb 34 $cl[1])
            for ($a = 0; $a -lt 360; $a += 15) {
                $t1 = $a * [Math]::PI / 180; $t2 = ($a + 7.5) * [Math]::PI / 180
                $gr.FillPolygon($ray, (Pts @(1000, 360, (1000 + 1400 * [Math]::Cos($t1)), (360 + 1400 * [Math]::Sin($t1)), (1000 + 1400 * [Math]::Cos($t2)), (360 + 1400 * [Math]::Sin($t2)))))
            }
            FE $gr (Br (Argb 60 $cl[1])) 1000 360 300 300
            for ($i = 0; $i -lt 3; $i++) { $gr.FillRectangle((Br $cl[$i]), 0, 618 + 18 * $i, 1280, 12) }
            $rnd = New-Object Random $info.Seed; $grain = Br (Argb 18 $Ink)
            for ($n = 0; $n -lt 2500; $n++) { $gr.FillRectangle($grain, $rnd.Next(1280), $rnd.Next(720), 2, 2) }
            $gr.DrawPath((New-Object Drawing.Pen $Ink, 6), (Rounded 22 22 1236 676 34))
        }
        Clip = { Rounded 25 25 1230 670 31 }
        Title = { param($gr, $title, $cl, $pal, $st)
            $gr.FillPath((Br $cl[1]), (Shifted $title 14 14)); $gr.FillPath((Br $cl[0]), (Shifted $title 7 7)); $gr.FillPath((Br $Ink), $title)
        }
        Font = @{ Rock = 'Segoe UI Black'; HipHop = 'Segoe UI Black'; Pop = 'Segoe UI Black'; Electronic = 'Segoe UI Black'; Children = 'Segoe UI Black'; Indie = 'Franklin Gothic Medium'; Default = 'Georgia' }
        Bold = $true; Shear = -0.1; Max = 180
        SubFont = 'Franklin Gothic Medium'; Sub = { param($cl, $pal) $Ink }
    }
    Futuristic = @{
        Description = 'Holographic HUD rings, a perspective grid floor, scanlines and chromatic glow.'
        Color = { param($p) RgbF (0.6 * $p[0] + 44) (0.6 * $p[1] + 90) (0.6 * $p[2] + 102) }
        Art = @{ Mode = 'Glow'; Glow = 0.45; Ghost = $true; Core = (Argb 170 (Rgb 255 255 255)) }
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((Linear (Rgb 4 8 22) (Rgb 6 20 36)), 0, 0, 1280, 720)
            Glow-Spot $gr $cl[0] 40 1000 360 340
            $state = $gr.Save(); $gr.SetClip((New-Object Drawing.Rectangle 0, 560, 1280, 160))
            $fp = New-Object Drawing.Pen (Argb 60 $cl[0]), 2
            for ($x = -1600; $x -le 2880; $x += 140) { L $gr $fp 640 470 $x 720 }
            for ($i = 1; $i -le 8; $i++) { $y = 560 + 160 * [Math]::Pow($i / 8, 2); L $gr $fp 0 $y 1280 $y }
            $gr.Restore($state); L $gr (New-Object Drawing.Pen (Argb 140 $cl[0]), 2) 0 560 1280 560
            E $gr (New-Object Drawing.Pen (Argb 70 $cl[1]), 2) 1000 360 268 268
            $dash = New-Object Drawing.Pen (Argb 100 $cl[0]), 3; $dash.DashPattern = @(6, 4); E $gr $dash 1000 360 300 300
            $ap = New-Object Drawing.Pen (Argb 160 $cl[0]), 5
            foreach ($a in -40, 140) { Arc $gr $ap 1000 360 330 $a 80 }
            $tp = New-Object Drawing.Pen (Argb 90 $cl[1]), 2
            for ($a = 0; $a -lt 360; $a += 10) { $t = $a * [Math]::PI / 180; L $gr $tp (1000 + 276 * [Math]::Cos($t)) (360 + 276 * [Math]::Sin($t)) (1000 + 290 * [Math]::Cos($t)) (360 + 290 * [Math]::Sin($t)) }
            $bp = New-Object Drawing.Pen (Argb 180 $cl[1]), 3
            foreach ($cn in @(@(40, 40, 1, 1), @(1240, 40, -1, 1), @(40, 680, 1, -1), @(1240, 680, -1, -1))) {
                $x = $cn[0]; $y = $cn[1]; $sx = $cn[2]; $sy = $cn[3]
                Poly $gr $bp @($x, ($y + 70 * $sy), $x, ($y + 20 * $sy), ($x + 20 * $sx), $y, ($x + 110 * $sx), $y) -Open
            }
            $sl = New-Object Drawing.Pen (Argb 26 (Rgb 0 0 0)), 2
            for ($y = 0; $y -lt 720; $y += 4) { L $gr $sl 0 $y 1280 $y }
        }
        Title = { param($gr, $title, $cl, $pal, $st)
            Neon $cl[0] { param($g, $c, $k) $g.DrawPath((Pn $c 2.6 $k), $title) } 0 0
            $b = $title.GetBounds(); $gb = New-Object Drawing.Drawing2D.LinearGradientBrush (P 0 $b.Top), (P 0 ($b.Bottom + 1)), (Rgb 255 255 255), (Mix $cl[0] (Rgb 255 255 255) 0.25)
            $gr.FillPath($gb, $title)
        }
        Font = 'Bahnschrift SemiLight'; Case = 'Upper'; Shear = 0; Max = 180
        SubFont = 'Cascadia Mono'; SubPrefix = '>> '; Sub = { param($cl, $pal) $cl[1] }
    }
    Cartoon    = @{
        Description = 'Comic-panel border, burst rays and halftone dots with bold outlined line art.'
        Color = { param($p) RgbF (0.85 * $p[0] + 20) (0.85 * $p[1] + 20) (0.85 * $p[2] + 20) }
        Art = @{ Mode = 'Flat'; K = 1.5; Shadow = 6; ShadowColor = (Rgb 0 0 0); ShadowAlpha = 255; Outline = (Rgb 20 20 24); OutlineK = 1.6 }
        Background = { param($gr, $cl, $pal, $info)
            $gr.Clear((Rgb 255 255 255)); $panel = Rounded 18 18 1244 684 26
            $state = $gr.Save(); $gr.SetClip($panel)
            $gr.FillRectangle((Br (Mix $cl[2] (Rgb 255 255 255) 0.72)), 0, 0, 1280, 720)
            $ray = Br (Argb 150 (Rgb 255 255 255))
            for ($a = 0; $a -lt 360; $a += 20) {
                $t1 = $a * [Math]::PI / 180; $t2 = ($a + 9) * [Math]::PI / 180
                $gr.FillPolygon($ray, (Pts @(1000, 360, (1000 + 1400 * [Math]::Cos($t1)), (360 + 1400 * [Math]::Sin($t1)), (1000 + 1400 * [Math]::Cos($t2)), (360 + 1400 * [Math]::Sin($t2)))))
            }
            $dot = Br (Argb 70 $cl[0])
            for ($y = 11; $y -lt 720; $y += 22) { for ($x = 11 + 11 * [int]($y % 44 -eq 11); $x -lt 760; $x += 22) {
                $r = 7 * (1 - [Math]::Sqrt($x * $x + (720 - $y) * (720 - $y)) / 760); if ($r -gt 0.8) { FE $gr $dot $x $y $r $r } } }
            $gr.Restore($state); $gr.DrawPath((Outline-Pen (Rgb 20 20 24) 10), $panel)
        }
        Clip = { Rounded 23 23 1234 674 22 }
        Title = { param($gr, $title, $cl, $pal, $st)
            $sh = Shifted $title 9 9; $gr.DrawPath((Outline-Pen (Rgb 20 20 24) 18), $sh); $gr.FillPath((Br (Rgb 20 20 24)), $sh)
            $gr.DrawPath((Outline-Pen (Rgb 20 20 24) 18), $title); $gr.FillPath((Br $cl[1]), $title)
        }
        Font = 'Segoe UI Black'; Shear = -0.06; Max = 180
        SubFont = 'Segoe UI Black'; Sub = { param($cl, $pal) Rgb 20 20 24 }
    }
    Cat        = @{
        Description = 'Pastel paw-print wallpaper with a headphone-wearing cartoon cat beside the line art.'
        Color = { param($p) RgbF (0.75 * $p[0]) (0.75 * $p[1]) (0.75 * $p[2]) }
        OX = 1000; OY = 245; Scale = 0.6
        Art = @{ Mode = 'Flat'; K = 2.2; Shadow = 5; ShadowColor = (Rgb 120 70 110); ShadowAlpha = 60 }
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((Linear (Rgb 255 228 236) (Rgb 232 222 255)), 0, 0, 1280, 720)
            $paw = Br (Argb 34 $cl[1]); Scatter $gr (New-Object Random $info.Seed) 110 { param($g) PawPrint $g $paw }
            FE $gr (Br (Argb 170 (Rgb 255 255 255))) 1000 245 200 200
            $gr.DrawPath((Outline-Pen $cl[0] 8), (Rounded 22 22 1236 676 34))
        }
        Character = { param($gr, $cl, $info) Draw-Cat $gr $cl $info }
        Title = { param($gr, $title, $cl, $pal, $st)
            $gr.FillPath((Br $cl[0]), (Shifted $title 7 7)); $gr.DrawPath((Outline-Pen (Rgb 255 255 255) 16), $title); $gr.FillPath((Br (Rgb 70 35 70)), $title)
        }
        Font = 'Segoe UI Black'; Shear = 0; Max = 170
        SubFont = 'Segoe UI Black'; Sub = { param($cl, $pal) Rgb 110 60 110 }
    }
    Dog        = @{
        Description = 'Sunny bone-print wallpaper with a bandana-wearing cartoon dog beside the line art.'
        Color = { param($p) RgbF (0.75 * $p[0]) (0.75 * $p[1]) (0.75 * $p[2]) }
        OX = 1000; OY = 245; Scale = 0.6
        Art = @{ Mode = 'Flat'; K = 2.2; Shadow = 5; ShadowColor = (Rgb 60 70 110); ShadowAlpha = 60 }
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((Linear (Rgb 255 240 200) (Rgb 205 230 255)), 0, 0, 1280, 720)
            $bone = Br (Argb 40 $cl[1]); Scatter $gr (New-Object Random $info.Seed) 110 { param($g) Bone $g $bone }
            FE $gr (Br (Argb 170 (Rgb 255 255 255))) 1000 245 200 200
            $gr.DrawPath((Outline-Pen $cl[0] 8), (Rounded 22 22 1236 676 34))
        }
        Character = { param($gr, $cl, $info) Draw-Dog $gr $cl $info }
        Title = { param($gr, $title, $cl, $pal, $st)
            $gr.FillPath((Br $cl[0]), (Shifted $title 7 7)); $gr.DrawPath((Outline-Pen (Rgb 255 255 255) 16), $title); $gr.FillPath((Br (Rgb 30 40 80)), $title)
        }
        Font = 'Segoe UI Black'; Shear = 0; Max = 170
        SubFont = 'Segoe UI Black'; Sub = { param($cl, $pal) Rgb 30 40 80 }
    }
    Nature     = @{
        Description = 'Layered mountain ridges, pines, a soft sun and earthy line art.'
        Color = { param($p) RgbF ((0.5 * $p[0] + 52) * 0.9) ((0.5 * $p[1] + 62) * 0.9) ((0.5 * $p[2] + 35) * 0.9) }
        Art = @{ Mode = 'Flat'; K = 1.6; Shadow = 5; ShadowColor = (Rgb 30 50 30); ShadowAlpha = 70 }
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((Linear (Rgb 196 222 234) (Rgb 246 236 212)), 0, 0, 1280, 720)
            Glow-Spot $gr (Rgb 255 236 170) 200 1170 105 150; FE $gr (Br (Rgb 255 236 180)) 1170 105 52 52
            $rnd = New-Object Random $info.Seed
            [void](Ridge $gr (Br (Rgb 170 196 190)) 600 260 26 $rnd)
            [void](Ridge $gr (Br (Rgb 118 156 126)) 650 190 20 $rnd)
            $near = Ridge $gr (Br (Rgb 74 112 78)) 700 110 12 $rnd
            $pb = Br (Rgb 46 80 52)
            foreach ($i in 24..40) { if ($rnd.Next(3)) { Pine $gr $pb ($near[$i + 1].X + $rnd.Next(-10, 10)) ($near[$i + 1].Y + 14) (50 + $rnd.Next(40)) } }
            $leaf = Br (Argb 150 (Rgb 80 120 70)); $stem = New-Object Drawing.Pen (Argb 150 (Rgb 80 120 70)), 4
            $gr.DrawBezier($stem, (P 0 150), (P 70 120), (P 140 70), (P 190 0))
            foreach ($l in @(@(40, 133, 30), @(90, 105, -40), @(115, 78, 35), @(160, 40, -35))) { At $gr $l[0] $l[1] $l[2] 1 { param($g) FE $g $leaf 0 -22 11 24 } }
        }
        Title = { param($gr, $title, $cl, $pal, $st)
            $gr.FillPath((Br (Argb 210 (Rgb 252 248 236))), (Shifted $title 4 4)); $gr.FillPath((Br (Rgb 40 72 46)), $title)
        }
        Font = 'Georgia'; Bold = $true; Shear = 0; Max = 170
        SubFont = 'Franklin Gothic Medium'; Sub = { param($cl, $pal) Rgb 54 84 58 }
    }
    Blocky     = @{
        Description = 'Chunky pixel art inspired by voxel sandbox games: blocky sky, clouds and a grass-and-dirt ground.'
        Art = @{ Mode = 'Pixel'; K = 5 }
        Background = { param($gr, $cl, $pal, $info)
            $rnd = New-Object Random $info.Seed
            for ($y = 0; $y -lt 624; $y += 8) { $gr.FillRectangle((Br (Mix (Rgb 104 160 236) (Rgb 178 214 250) ($y / 624))), 0, $y, 1280, 8) }
            $gr.FillRectangle((Br (Rgb 255 214 70)), 1136, 32, 72, 72); $gr.FillRectangle((Br (Rgb 255 244 150)), 1152, 48, 40, 40)
            $cloud = Br (Argb 235 (Rgb 255 255 255))
            foreach ($cx in 80, 470, 820) {
                $x = $cx + 8 * $rnd.Next(-6, 6); $y = 24 + 8 * $rnd.Next(0, 4); $w = 8 * $rnd.Next(14, 22)
                $gr.FillRectangle($cloud, $x, $y + 16, $w, 24); $gr.FillRectangle($cloud, $x + 24, $y, $w - 64, 16)
            }
            for ($x = 0; $x -lt 1280; $x += 8) {
                $drip = 624 + 24 + 8 * [Math]::Max(0, $rnd.Next(-3, 3))
                for ($y = 624; $y -lt 720; $y += 8) {
                    $base = if ($y -lt $drip) { Rgb 96 164 58 } elseif ($rnd.Next(14) -eq 0) { Rgb 128 128 128 } else { Rgb 134 96 66 }
                    $gr.FillRectangle((Br (Mix $base (Rgb 0 0 0) ($rnd.NextDouble() * 0.16))), $x, $y, 8, 8)
                }
            }
        }
        Title = { param($gr, $title, $cl, $pal, $st)
            Pixel-Layer { param($p) $p.DrawPath((Outline-Pen (Rgb 40 40 40) 22), $title); $p.FillPath((Br (Rgb 236 236 228)), $title) }
        }
        Font = 'Segoe UI Black'; Case = 'Upper'; Shear = 0; Max = 170
        SubFont = 'Cascadia Mono'; SubBold = $true; Sub = { param($cl, $pal) Rgb 236 236 228 }; SubShadow = (Rgb 40 40 40)
    }
    Rebel      = @{
        Description = 'Scrappy sci-fi resistance: starfield, a dusky planet, weathered orange and hazard stripes.'
        Color = { param($p) RgbF (0.5 * $p[0] + 125) (0.5 * $p[1] + 95) (0.5 * $p[2] + 62) }
        Art = @{ Mode = 'Flat'; K = 1.7; Shadow = 6; ShadowColor = (Rgb 0 0 0); ShadowAlpha = 150 }
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((Linear (Rgb 8 10 22) (Rgb 26 16 24)), 0, 0, 1280, 720)
            $rnd = New-Object Random $info.Seed
            for ($n = 0; $n -lt 420; $n++) { $s = 1 + $rnd.Next(3); $gr.FillRectangle((Br (Argb (60 + $rnd.Next(190)) (Rgb 255 250 235))), $rnd.Next(1280), $rnd.Next(620), $s / 1.5, $s / 1.5) }
            Glow-Spot $gr (Rgb 255 140 60) 70 1120 860 520
            $planet = New-Object Drawing.Drawing2D.GraphicsPath; $planet.AddEllipse(760, 470, 720, 720)
            $gr.FillPath((New-Object Drawing.Drawing2D.LinearGradientBrush (P 760 470), (P 1300 900), (Rgb 214 120 62), (Rgb 70 30 26)), $planet)
            $state = $gr.Save(); $gr.SetClip($planet)
            for ($i = 0; $i -lt 6; $i++) { $gr.FillRectangle((Br (Argb 40 (Rgb 60 20 10))), 700, 520 + 34 * $i + $rnd.Next(12), 800, 10 + $rnd.Next(10)) }
            $gr.Restore($state)
            $hz = Br (Rgb 236 120 32); $state = $gr.Save(); $gr.SetClip((New-Object Drawing.Rectangle 0, 650, 700, 26))
            $gr.FillRectangle((Br (Rgb 30 26 28)), 0, 650, 700, 26)
            for ($x = -40; $x -lt 720; $x += 44) { $gr.FillPolygon($hz, (Pts @($x, 676, ($x + 22), 676, ($x + 48), 650, ($x + 26), 650))) }
            $gr.Restore($state)
            $gr.FillRectangle((Br (Rgb 236 120 32)), 48, 130, 10, 400)
            $scr = New-Object Drawing.Pen (Argb 26 (Rgb 255 255 255)), 1
            for ($n = 0; $n -lt 90; $n++) { $x = $rnd.Next(1280); $y = $rnd.Next(720); L $gr $scr $x $y ($x + $rnd.Next(-40, 40)) ($y + $rnd.Next(-8, 8)) }
        }
        Title = { param($gr, $title, $cl, $pal, $st)
            $gr.FillPath((Br (Argb 200 (Rgb 0 0 0))), (Shifted $title 6 6)); $gr.FillPath((Br (Rgb 236 120 32)), $title)
            $state = $gr.Save(); $gr.SetClip($title); $rnd = New-Object Random $title.PointCount
            $scr = New-Object Drawing.Pen (Argb 110 (Rgb 40 20 16)), 2
            for ($n = 0; $n -lt 70; $n++) { $x = 95 + $rnd.Next(660); $y = 120 + $rnd.Next(420); L $gr $scr $x $y ($x + $rnd.Next(-50, 50)) ($y + $rnd.Next(-6, 6)) }
            $gr.Restore($state)
        }
        Font = 'Bahnschrift SemiBold Condensed'; Bold = $true; Case = 'Upper'; Shear = 0; Max = 210
        SubFont = 'Bahnschrift'; Sub = { param($cl, $pal) Rgb 236 226 206 }
    }
    Imperial   = @{
        Description = 'Cold, symmetrical sci-fi empire: steel panels, corridor lights and red accent bars.'
        Color = { param($p) $l = 0.3 * $p[0] + 0.59 * $p[1] + 0.11 * $p[2]; RgbF (0.25 * $p[0] + 0.55 * $l + 70) (0.15 * $p[1] + 0.55 * $l + 70) (0.15 * $p[2] + 0.55 * $l + 76) }
        Art = @{ Mode = 'Glow'; Glow = 0.4; Core = (Argb 170 (Rgb 255 255 255)) }
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((Linear (Rgb 12 13 16) (Rgb 34 36 41)), 0, 0, 1280, 720)
            $seam = New-Object Drawing.Pen (Argb 90 (Rgb 0 0 0)), 3; $hi = New-Object Drawing.Pen (Argb 18 (Rgb 255 255 255)), 1
            for ($y = 90; $y -lt 720; $y += 90) { L $gr $seam 0 $y 1280 $y; L $gr $hi 0 ($y + 2) 1280 ($y + 2)
                for ($x = 160 * (($y / 90) % 2); $x -lt 1280; $x += 320) { L $gr $seam $x ($y - 90) $x $y } }
            $lt = Br (Argb 210 (Rgb 236 240 248))
            for ($x = 70; $x -lt 1240; $x += 90) { $gr.FillRectangle($lt, $x, 24, 50, 10); $gr.FillRectangle($lt, $x, 686, 50, 10) }
            Glow-Spot $gr (Rgb 200 210 230) 26 1000 360 330
            $hex = for ($i = 0; $i -lt 6; $i++) { $t = ($i * 60 + 30) * [Math]::PI / 180; 1000 + 300 * [Math]::Cos($t); 360 + 300 * [Math]::Sin($t) }
            $gr.DrawPolygon((New-Object Drawing.Pen (Argb 70 (Rgb 190 196 210)), 6), (Pts $hex))
            $red = Br (Rgb 200 22 26)
            $gr.FillRectangle($red, 60, 150, 8, 370); $gr.FillRectangle($red, 0, 612, 1280, 6); $gr.FillRectangle((Br (Argb 120 (Rgb 200 22 26))), 0, 624, 1280, 2)
        }
        Title = { param($gr, $title, $cl, $pal, $st)
            $gr.FillPath((Br (Argb 180 (Rgb 0 0 0))), (Shifted $title 4 4)); $gr.FillPath((Br (Rgb 236 238 244)), $title)
        }
        Font = 'Bahnschrift SemiBold SemiConden'; Case = 'Upper'; Shear = 0; Max = 190
        SubFont = 'Bahnschrift'; Sub = { param($cl, $pal) Rgb 214 40 40 }
    }
    Tile       = @{
        Description = 'The original plugin look: a dark-to-violet gradient, line art in a rounded tile and a centred caption.'
        Color = { param($p) RgbF (0.5 * $p[0] + 120) (0.5 * $p[1] + 120) (0.5 * $p[2] + 120) }
        Art = @{ Mode = 'Flat'; K = 2.3 }
        OX = 640; OY = 250; Scale = 0.34
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush (P 0 0), (P 1280 720), (Rgb 20 27 43), (Rgb 112 66 180)), 0, 0, 1280, 720)
            $gr.FillPath((Br (Argb 90 (Rgb 0 0 0))), (Rounded 497 117 290 290 36))
            $gr.FillPath((Br (Rgb 46 46 74)), (Rounded 495 105 290 290 36))
        }
        Clip = { Rounded 503 113 274 274 30 }
        NoSub = $true
        Title = { param($gr, $title, $cl, $pal, $st, $info)
            $font = if ($info.NativeFont) { $info.NativeFont } else { 'Segoe UI Semibold' }
            $tp = Center-Title $gr $info.Name $font $false 'Title' 0 520 1000 90 72
            $gr.FillPath((Br (Rgb 255 255 255)), $tp)
            Centered-Sub $gr $(if ($info.Label) { $info.Label.ToUpperInvariant() } elseif ($info.Sub) { $info.Parent.ToUpperInvariant() } else { 'TUNEIN RADIO' }) 'Segoe UI' 22 (Argb 190 (Rgb 220 214 240)) 580
        }
    }
    Classic    = @{
        Description = 'Bold centred typography on a rich genre-coloured gradient, with faint line art and an accent band.'
        Color = { param($p) RgbF (0.5 * $p[0] + 90) (0.5 * $p[1] + 90) (0.5 * $p[2] + 90) }
        Art = @{ Mode = 'Flat'; K = 1.2 }
        OX = 640; OY = 360; Scale = 1.2
        Background = { param($gr, $cl, $pal, $info)
            $c1 = Mix $pal[0] (Rgb 0 0 0) 0.2; $c2 = Mix $cl[0] $pal[1] 0.45
            $gr.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush (P 0 0), (P 1280 720), $c1, $c2), 0, 0, 1280, 720)
            $gr.FillRectangle((Br (Argb 70 (Rgb 0 0 0))), 0, 0, 1280, 720)
            $gr.FillRectangle((Br $cl[1]), 0, 690, 1280, 30)
        }
        Clip = { $cp = New-Object Drawing.Drawing2D.GraphicsPath; $cp.AddRectangle((New-Object Drawing.Rectangle 0, 0, 1280, 690)); $cp }
        NoSub = $true
        Title = { param($gr, $title, $cl, $pal, $st, $info)
            $c1 = Argb 215 (Mix (Mix $pal[0] (Rgb 0 0 0) 0.2) (Rgb 0 0 0) 0.27); $c2 = Argb 215 (Mix (Mix $cl[0] $pal[1] 0.45) (Rgb 0 0 0) 0.27)
            $gr.FillRectangle((New-Object Drawing.Drawing2D.LinearGradientBrush (P 0 0), (P 1280 720), $c1, $c2), 0, 0, 1280, 690)
            $tp = Center-Title $gr $info.Name $st.Font $st.Bold $st.Case $st.Shear 330 1100 300 200
            $gr.FillPath((Br (Argb 150 (Rgb 0 0 0))), (Shifted $tp 5 6)); $gr.FillPath((Br (Rgb 252 248 240)), $tp)
            $b = $tp.GetBounds(); $label = if ($info.Label) { $info.Label } elseif ($info.Sub) { $info.Parent } else { 'Music' }
            Centered-Sub $gr $label 'Segoe UI' 34 (Argb 220 (Rgb 245 240 230)) ($b.Bottom + 44)
        }
    }
    Elegant    = @{
        Description = 'Quiet charcoal, a warm vignette, champagne hairline art and serif titles.'
        Color = { param($p) $l = 0.3 * $p[0] + 0.59 * $p[1] + 0.11 * $p[2]; RgbF (0.1 * $p[0] + 0.35 * $l + 130) (0.1 * $p[1] + 0.3 * $l + 112) (0.1 * $p[2] + 0.22 * $l + 84) }
        Art = @{ Mode = 'Flat'; K = 0.85 }
        Background = { param($gr, $cl, $pal, $info)
            $gr.FillRectangle((Linear (Rgb 26 28 34) (Rgb 12 13 17)), 0, 0, 1280, 720)
            $vp = New-Object Drawing.Drawing2D.GraphicsPath; $vp.AddEllipse(480, -160, 1040, 1040); $vb = New-Object Drawing.Drawing2D.PathGradientBrush $vp; $vb.CenterColor = Argb 34 (Rgb 214 182 124); $vb.SurroundColors = @((Argb 0 (Rgb 214 182 124))); $gr.FillPath($vb, $vp)
            if (-not $script:Dither) {
                $nb = New-Object Drawing.Bitmap 256, 256; $nr = New-Object Random 7
                for ($y = 0; $y -lt 256; $y++) { for ($x = 0; $x -lt 256; $x++) { $v = $nr.Next(3); if ($v -eq 1) { $nb.SetPixel($x, $y, (Argb 6 (Rgb 255 255 255))) } elseif ($v -eq 2) { $nb.SetPixel($x, $y, (Argb 6 (Rgb 0 0 0))) } } }
                $script:Dither = New-Object Drawing.TextureBrush $nb
            }
            $gr.FillRectangle($script:Dither, 0, 0, 1280, 720)
            $gold = Rgb 201 169 110
            $gr.DrawRectangle((New-Object Drawing.Pen (Argb 120 $gold), 1.5), 34, 34, 1212, 652)
            $gr.DrawRectangle((New-Object Drawing.Pen (Argb 50 $gold), 1), 44, 44, 1192, 632)
        }
        Title = { param($gr, $title, $cl, $pal, $st)
            $gr.FillPath((Br (Argb 120 (Rgb 0 0 0))), (Shifted $title 3 4)); $gr.FillPath((Br (Rgb 238 229 210)), $title)
            $gp = New-Object Drawing.Pen (Argb 200 (Rgb 201 169 110)), 2; L $gr $gp 98 540 210 540
        }
        Font = 'Georgia'; Bold = $false; Case = 'Title'; Shear = 0; Max = 170
        SubFont = 'Segoe UI Light'; Sub = { param($cl, $pal) Rgb 201 169 110 }
    }
}

function New-Card($info, [string]$file) {
    $T = $script:T
    $st = $Styles[$info.Style].Clone()
    if ($T.Font) { $st.Font = Pick $T.Font $info.Style }
    foreach ($key in 'Bold', 'Case', 'Shear') { if ($T.ContainsKey($key)) { $st[$key] = $T[$key] } }
    if ($T.Max) { $st.Max = [Math]::Min($st.Max, $T.Max) }
    $script:CurrentRTL = [bool]$info.RTL
    if ($info.NativeFont) {
        $null = Get-TitleFamily $info.NativeFont
        $st.Font = $info.NativeFont; $st.Bold = $false; $st.Case = 'Title'; $st.Shear = 0
    }
    $pal = foreach ($p in $st.Pal) { & $T.Color $p }
    $cl = @($pal[2], $pal[3], $pal[4])
    if ($info.Sub) { $r = $info.Seed % 3; $cl = @($cl[$r], $cl[($r + 1) % 3], $cl[($r + 2) % 3]) }
    $bmp = New-Object Drawing.Bitmap 1280, 720
    $script:G = [Drawing.Graphics]::FromImage($bmp); $g0 = $script:G
    $g0.SmoothingMode = 'AntiAlias'; $g0.CompositingQuality = 'HighQuality'; $g0.InterpolationMode = 'HighQualityBicubic'
    $script:OX = $T.OX; $script:OY = $T.OY; $script:ArtScale = 1
    & $T.Background $g0 $cl $pal $info

    if ($Scope -eq 'categories' -and $Theme -ne $baseTheme) {
        $x = [float]$T.OX; $y = [float]$T.OY
        $beam = Pts @(($x - 48), 0, ($x + 48), 0, ($x + 260), ($y + 190), ($x - 260), ($y + 190))
        $g0.FillPolygon((Br (Argb 22 $cl[0])), $beam)
        FE $g0 (Br (Argb 24 $cl[1])) $x $y 238 172
        $ring = New-Object Drawing.Pen (Argb 105 $cl[0]), 4
        E $g0 $ring $x $y 218 158
        $ring.Dispose()
        $fixture = New-Object Drawing.Pen (Argb 150 $cl[0]), 8
        L $g0 $fixture ($x - 52) 24 ($x + 52) 24
        $fixture.Dispose()
    }

    if ($T.Clip) { $g0.SetClip((& $T.Clip)) }
    $script:ArtScale = $T.Scale
    & "Motif-$($info.Motif)" $cl $info
    $script:ArtScale = 1; $g0.ResetClip()
    if ($T.Character) { & $T.Character $g0 $cl $info }

    $title = Title-Path $info.Name $st
    & $T.Title $g0 $title $cl $pal $st $info
    if (-not $T.NoSub) {
    $label = if ($info.Label) { $info.Label } elseif ($info.Sub) { $info.Parent } else { 'Music' }
    $fs = if ($T.SubBold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $font = New-Object Drawing.Font (Pick $T.SubFont $info.Style), 28, $fs, ([Drawing.GraphicsUnit]::Pixel)
    $text = $T.SubPrefix + (Spaced $label)
    if ($T.SubShadow) { $g0.DrawString($text, $font, (Br $T.SubShadow), 99, 563) }
    $g0.DrawString($text, $font, (Br (& $T.Sub $cl $pal)), 96, 560)
    }

    $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
    $ep = New-Object Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), ([long]80)
    $g0.Dispose(); $bmp.Save($file, $codec, $ep); $bmp.Dispose()
}

$baseTheme = $Theme -replace 'Spotlight$', ''
if ($RequireScopedScenery -and ($Scope -notin 'languages','locations' -or $baseTheme -notin 'Cartoon','Futuristic','Classic')) {
    throw 'RequireScopedScenery applies only to Cartoon, Futuristic and Classic language/location packs.'
}
$script:T = $Themes[$baseTheme]
$spotlightIds = @{
    FuturisticSpotlight = @('g2698', 'g4149', 'c57942', 'g54', 'g71', 'g373')
    CartoonSpotlight = @('g2698', 'g4149', 'c57942', 'g54', 'g71', 'g373')
    ClassicSpotlight = @('g2698', 'g4149')
}
foreach ($d in @(@('Color', { param($p) Rgb $p[0] $p[1] $p[2] }), @('OX', 1000), @('OY', 360), @('Scale', 1), @('SubPrefix', ''))) { if (-not $script:T.ContainsKey($d[0])) { $script:T[$d[0]] = $d[1] } }
$__cm = New-Object Drawing.Imaging.ColorMatrix; $__cm.Matrix33 = if ($script:T.Art.Glow) { $script:T.Art.Glow } else { 0.65 }; $script:GlowAttr.SetColorMatrix($__cm)

function Get-Opml([string]$url) {
    if ($CatalogSnapshot) {
        $key = if ($url -ceq 'https://opml.radiotime.com/Browse.ashx?c=lang') { 'languages' }
        elseif ($url -cmatch '^https://opml\.radiotime\.com/Browse\.ashx\?id=(r(?:0|[1-9][0-9]{0,9}))$') { $Matches[1] }
        else { throw "Unsupported snapshot URL: $url" }
        $path = Join-Path $CatalogSnapshot "$key.xml"
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing catalog snapshot response: $path" }
        [xml]$doc = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($path))
    } else {
        if ($AllLocations -and $Scope -eq 'locations') { Start-Sleep -Milliseconds 250 }
        [xml]$doc = [Text.Encoding]::UTF8.GetString((Invoke-WebRequest -UseBasicParsing $url -TimeoutSec 30).RawContentStream.ToArray())
    }
    if ($doc.opml.head.status -ne '200') { throw "TuneIn browse failed for $url (status $($doc.opml.head.status))." }
    $doc
}

$genres = [ordered]@{}
if ($Scope -eq 'genres') {
    foreach ($top in (Get-Opml 'https://opml.radiotime.com/Browse.ashx?c=music').opml.body.outline | Where-Object { $_.type -eq 'link' -and $_.guide_id -cmatch '^[cg][1-9][0-9]{0,9}$' }) {
        $parent = $top.text
        if (-not $Parents.ContainsKey($parent)) { Write-Warning "Unknown parent genre '$parent'; using the Pop style."; $Parents[$parent] = 'Pop', 'notes' }
        $genres[$top.guide_id] = @{ Id = $top.guide_id; Name = $parent; Parent = $parent; Sub = $false }
        foreach ($o in (Get-Opml "https://opml.radiotime.com/Browse.ashx?id=$($top.guide_id)").SelectNodes('//outline[@guide_id]')) {
            if (($o.guide_id -cmatch '^g[1-9][0-9]{0,9}$' -or ($o.type -eq 'link' -and $o.guide_id -cmatch '^c[1-9][0-9]{0,9}$')) -and -not $genres.Contains($o.guide_id)) { $genres[$o.guide_id] = @{ Id = $o.guide_id; Name = $o.text; Parent = $parent; Sub = $true } }
        }
    }
} elseif ($Scope -eq 'categories') {
    foreach ($category in @(
        @('local', 'Local Radio', 'Country', 'radio'),
        @('music', 'Music', 'Children', 'notes'),
        @('language', 'By Language', 'Folk', 'speech'),
        @('location', 'By Location', 'Reggae', 'globe'),
        @('talk', 'Talk', 'Decades', 'mic'),
        @('sports', 'Sports', 'Rock', 'sports'),
        @('podcast', 'Podcasts', 'Electronic', 'headphones'),
        @('presets', 'My Favorites', 'Holiday', 'heart')
    )) {
        $genres[$category[0]] = @{ Id = $category[0]; Name = $category[1]; Style = $category[2]; Motif = $category[3]; Label = 'TuneIn Radio'; Sub = $false }
    }
} else {
    . (Join-Path $PSScriptRoot 'Scoped-Artwork.ps1')
    . (Join-Path $PSScriptRoot 'Scoped-Artwork-Styles.ps1')
    if ($Scope -eq 'languages') { $genres = Get-Languages }
    else { $genres = Get-Locations; Set-LocationArt $genres }
}

$selected = @($genres.Values)
if ($Only) {
    $selected = @($genres.Values | Where-Object {
        $candidate = $_
        $Only | Where-Object { $candidate.Id -eq $_ -or $candidate.Name -like $_ -or ($candidate.ProviderName -and $candidate.ProviderName -like $_) }
    })
}
if (-not $selected.Count) { throw 'No artwork matched the selected catalog and -Only filters.' }
if ($RequireScopedScenery) { Assert-ScopedSceneCoverage $selected $baseTheme }
New-Item -ItemType Directory -Force $Output | Out-Null
$rendered = New-Object System.Collections.ArrayList
foreach ($info in $selected) {
    $seed = 0; foreach ($ch in $info.Id.ToCharArray()) { $seed = ($seed * 31 + [int]$ch) % 2147483647 }
    $info.Seed = [int]$seed
    if ($Scope -eq 'genres') {
        $info.Style = $Parents[$info.Parent][0]
        $info.Motif = $Parents[$info.Parent][1]
        if ($info.Sub) { foreach ($rx in $Overrides.Keys) { if ($info.Name -match $rx) { $info.Motif = $Overrides[$rx]; break } } }
        if ($info.Style -eq 'World' -and $Places.ContainsKey(($place = $info.Name -replace ' Music$'))) { $info.Lat = $Places[$place][0]; $info.Lon = $Places[$place][1] }
    }
    $target = Join-Path $Output "$($info.Id).jpg"
    $spotlight = Join-Path $PSScriptRoot "spotlight\$Theme\$($info.Id).jpg"
    if ($Scope -eq 'genres' -and $Theme -ne $baseTheme -and $spotlightIds[$Theme] -contains $info.Id) {
        if (-not (Test-Path -LiteralPath $spotlight -PathType Leaf)) {
            throw "Missing Spotlight artwork: $spotlight"
        }
        Copy-Item -LiteralPath $spotlight -Destination $target -Force
    } elseif ($Scope -in 'languages','locations' -and $baseTheme -in 'Cartoon','Futuristic','Classic') {
        New-ScopedCard $info $target $baseTheme
    } else {
        New-Card $info $target
    }
    [void]$rendered.Add($info.Id)
    Write-Host "$($info.Id)  $($info.Name)  [$($info.Style)/$($info.Motif)]"
}
if ($Only -and -not $rendered.Count) { throw 'No artwork matched -Only.' }

# SHA-256 hashes identify the exact image bytes installed from this pack.
$images = @($rendered | Sort-Object | ForEach-Object {
    $file = Get-Item (Join-Path $Output "$_.jpg")
    $info = $genres[$file.BaseName]
    [ordered]@{ id = $info.Id; file = $file.Name
        sha256 = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$manifest = [ordered]@{
    schemaVersion = 2; scope = $Scope; packId = $PackName; packName = $Theme; theme = $Theme; version = $PackVersion
    imageCount = $images.Count; images = $images
}
$manifestPath = Join-Path $Output 'tunein-artwork.json'
. (Join-Path $PSScriptRoot 'Artwork-PackValidation.ps1')
$tempManifest = Join-Path $Output ([IO.Path]::GetRandomFileName() + '.json')
try {
    [IO.File]::WriteAllText($tempManifest, ($manifest | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
    $validatedManifest = Assert-ArtworkPack $Output $tempManifest
    Move-Item -LiteralPath $tempManifest -Destination $manifestPath -Force
} finally {
    if (Test-Path -LiteralPath $tempManifest) { Remove-Item -LiteralPath $tempManifest -Force }
}

if ($Pack) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = Join-Path (Split-Path ([IO.Path]::GetFullPath($Output)) -Parent) "$zipName.zip"
    $note = @"
$PackName - $Scope artwork for the Emby TuneIn plugin ($Theme theme)
Built by Build-GenreArtwork.ps1 from https://github.com/oconnoradv/EmbyTuneInArt (GPL-3.0).
Requires a TuneIn plugin build with schema 2 artwork-pack support.

1. Extract the .jpg files and tunein-artwork.json into <Emby data>\plugins\configurations\TuneInArtwork\$Scope
   (Settings > Advanced Settings > Custom Artwork Packs > Details & installation shows the exact folder).
2. Under Catalog Refresh > TuneIn Library Refresh, refresh the corresponding category or all enabled categories.
Delete the images and refresh again to return to the default icons. Also delete the manifest to clear the pack name.
"@
    if ($Scope -in 'languages','locations') { $note += @"

Flags are representative, not exclusive to a language. Unknown language names retain the provider's label.
Cities may use a labeled regional ancestor map. Unmapped locations use a labeled generic location pin, not invented boundaries.
City markers are approximate and appear only when a reliable matching point is available; unmarked maps do not imply a center point.
Scenery is shared by explicitly mapped countries/regions; it is decorative, not a depiction of every individual city.
Scenic backgrounds and map-fill textures are AI-generated illustrations, not geographic or terrain data.
Neutral language categories use speech motifs rather than an assigned nationality. Language packs include FLAGS-SOURCES.txt for representative flag provenance.
Natural Earth country and region geometry and populated-place points are public domain: https://www.naturalearthdata.com/about/terms-of-use/
Noto Sans Khmer and Noto Serif KR are distributed under the SIL Open Font License 1.1; see Noto-OFL.txt.
"@ }
    $tempZip = Join-Path (Split-Path $zip -Parent) ([IO.Path]::GetRandomFileName() + '.zip')
    try {
        $archive = [IO.Compression.ZipFile]::Open($tempZip, 'Create')
        try {
            foreach ($image in $images) {
                [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $Output $image.file), $image.file, 'Optimal')
            }
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $Output 'tunein-artwork.json'), 'tunein-artwork.json', 'Optimal')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $PSScriptRoot 'LICENSE'), 'LICENSE.txt', 'Optimal')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $PSScriptRoot 'data\Noto-OFL.txt'), 'Noto-OFL.txt', 'Optimal')
            if ($Scope -eq 'languages') {
                [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $PSScriptRoot 'data\flags\FLAGS-SOURCES.txt'), 'FLAGS-SOURCES.txt', 'Optimal')
                [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $PSScriptRoot 'data\flags\sources.json'), 'flag-sources.json', 'Optimal')
            }
            $writer = New-Object IO.StreamWriter ($archive.CreateEntry('README.txt').Open())
            try { $writer.Write($note.Replace("`r`n", "`n").Replace("`n", "`r`n")) } finally { $writer.Dispose() }
        } finally { $archive.Dispose() }
        Assert-ArtworkArchive $tempZip $validatedManifest $manifestPath
        Move-Item -LiteralPath $tempZip -Destination $zip -Force
    } finally {
        if (Test-Path -LiteralPath $tempZip) { Remove-Item -LiteralPath $tempZip -Force }
    }
    Write-Host "Pack: $zip"
}