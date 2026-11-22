function Scoped-Scenery($g, $theme, $seed) {
    if (-not $script:ScopedScenes) { $script:ScopedScenes = @{} }
    if (-not $script:ScopedScenes.ContainsKey($theme)) {
        $path = Join-Path $PSScriptRoot ("data\scenes\" + $theme.ToLowerInvariant() + '.png')
        $script:ScopedScenes[$theme] = [Drawing.Image]::FromFile($path)
    }
    $g.DrawImage($script:ScopedScenes[$theme], 0, 0, 1280, 720)
    if ($theme -eq 'Classic') {
        $tints = @((Rgb 120 0 25), (Rgb 0 95 35), (Rgb 0 36 100))
        $g.FillRectangle((Br (Argb 60 $tints[$seed % 3])), 0, 0, 1280, 720)
    }
}

function Scoped-Flag($g, $flag, $x, $y, $w, $h, $theme) {
    $state = $g.Save(); $g.TranslateTransform($x, $y); $g.ScaleTransform(($w / 420), ($h / 280))
    $g.FillRectangle((Br (Rgb 255 255 250)), 0, 0, 420, 280)
    if ($flag -eq 'Japan') { FE $g (Br (Rgb 188 0 45)) 210 140 84 84 }
    elseif ($flag -eq 'Iceland') {
        $g.FillRectangle((Br (Rgb 0 82 156)), 0, 0, 420, 280)
        $g.FillRectangle((Br (Rgb 255 255 255)), 117.6, 0, 67.2, 280); $g.FillRectangle((Br (Rgb 255 255 255)), 0, 108.89, 420, 62.22)
        $g.FillRectangle((Br (Rgb 220 30 53)), 134.4, 0, 33.6, 280); $g.FillRectangle((Br (Rgb 220 30 53)), 0, 124.44, 420, 31.11)
    } elseif ($flag -eq 'Ireland') {
        $g.FillRectangle((Br (Rgb 22 139 62)), 0, 0, 140, 280); $g.FillRectangle((Br (Rgb 255 136 62)), 280, 0, 140, 280)
    } elseif ($flag -eq 'South Korea') {
        $state2 = $g.Save(); $g.TranslateTransform(210,140); $g.RotateTransform(33.69)
        $g.FillPie((Br (Rgb 205 46 58)), -70, -70, 140, 140, 180, 180)
        $g.FillPie((Br (Rgb 0 71 160)), -70, -70, 140, 140, 0, 180)
        FE $g (Br (Rgb 205 46 58)) -35 0 35 35; FE $g (Br (Rgb 0 71 160)) 35 0 35 35
        $g.Restore($state2)
        foreach ($t in @(@(100,65,-56.31,'000'),@(100,215,56.31,'010'),@(320,65,56.31,'101'),@(320,215,-56.31,'111'))) {
            $state3 = $g.Save(); $g.TranslateTransform($t[0],$t[1]); $g.RotateTransform($t[2])
            for ($i=0; $i -lt 3; $i++) {
                $yy = ($i - 1) * 17.5
                if ($t[3][$i] -eq '1') { $g.FillRectangle((Br (Rgb 0 0 0)), -35, $yy, 29, 11.67); $g.FillRectangle((Br (Rgb 0 0 0)), 6, $yy, 29, 11.67) }
                else { $g.FillRectangle((Br (Rgb 0 0 0)), -35, $yy, 70, 11.67) }
            }
            $g.Restore($state3)
        }
    }
    if ($theme -ne 'Futuristic') {
        for ($i = 0; $i -lt 420; $i += 4) {
            $v = [Math]::Sin($i / 35.0) + 0.4 * [Math]::Sin($i / 13.0)
            $shade = if ($v -lt 0) { Rgb 0 0 0 } else { Rgb 255 255 255 }
            $g.FillRectangle((Br (Argb ([int]([Math]::Abs($v) * 20)) $shade)), $i, 0, 4, 280)
        }
    }
    $g.DrawRectangle((New-Object Drawing.Pen (Rgb 12 30 45), 5), 0, 0, 420, 280)
    $g.Restore($state)
}

function Scoped-Motif($g, $info, $theme, $cx, $cy) {
    $state = $g.Save(); $g.TranslateTransform($cx, $cy)
    if ($info.Motif -eq 'flag') {
        $height = if ($info.Flag -eq 'Ireland') { 310 } elseif ($info.Flag -eq 'Iceland') { 446.4 } else { 413.33 }
        if ($theme -eq 'Futuristic') { $g.DrawRectangle((New-Object Drawing.Pen (Rgb 0 228 255), 6), -325, (-$height / 2 - 14), 650, ($height + 28)) }
        Scoped-Flag $g $info.Flag -310 (-$height / 2) 620 $height $theme
    } elseif ($info.Motif -eq 'map') {
        $fill = if ($theme -eq 'Futuristic') { Rgb 8 103 144 } else { Rgb 225 183 96 }
        $edge = if ($theme -eq 'Futuristic') { Rgb 48 235 255 } elseif ($theme -eq 'Cartoon') { Rgb 13 30 34 } else { Rgb 250 220 148 }
        $shape = New-Object Drawing.Drawing2D.GraphicsPath
        foreach ($ring in $info.MapRings) { if ($ring.Count -ge 6) { $shape.AddPolygon((Pts $ring)) } }
        $g.FillPath((Br $fill), $shape)
        if ($theme -in 'Cartoon','Futuristic') {
            $clip = $g.Save(); $g.SetClip($shape)
            $textureColor = if ($theme -eq 'Futuristic') { Argb 115 (Rgb 61 238 255) } else { Argb 65 (Rgb 56 85 60) }
            $texture = New-Object Drawing.Pen $textureColor, 1
            for ($y = -240; $y -le 240; $y += 15) { L $g $texture -250 $y 250 ($y + 90) }
            if ($theme -eq 'Futuristic') { for ($x = -240; $x -le 240; $x += 25) { L $g $texture $x -240 ($x+100) 240 } }
            $g.Restore($clip); $texture.Dispose()
        }
        $g.DrawPath((New-Object Drawing.Pen $edge, $(if($theme -eq 'Cartoon'){5}else{2})), $shape)
        $shape.Dispose()
        if ($info.MapPoint) {
            $px = $info.MapPoint[0]; $py = $info.MapPoint[1]
            FE $g (Br (Rgb 255 246 220)) $px $py 13 13
            FE $g (Br (Rgb 208 32 45)) $px $py 9 9
            FE $g (Br (Rgb 255 255 255)) $px $py 3 3
        }
    } else {
        $color = if ($theme -eq 'Futuristic') { Rgb 53 226 250 } else { Rgb 236 203 136 }
        $pen = New-Object Drawing.Pen $color, 6
        E $g $pen 0 0 165 165; E $g $pen 0 0 78 165; L $g $pen -165 0 165 0
        $g.DrawEllipse($pen, -165, -70, 330, 140)
    }
    $g.Restore($state)
}

function New-ScopedCard($info, [string]$file, [string]$theme) {
    $bmp = New-Object Drawing.Bitmap 1280, 720
    $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
    $script:CurrentRTL = [bool]$info.RTL
    Scoped-Scenery $g $theme $info.Seed
    $cx = if ($theme -eq 'Classic') { 320 } else { 640 }
    $cy = if ($theme -eq 'Classic') { 300 } elseif ($theme -eq 'Futuristic') { 255 } else { 270 }
    Scoped-Motif $g $info $theme $cx $cy
    $displayTitle = $info.Name
    $font = if ($info.NativeFont) { $info.NativeFont } else { 'Segoe UI' }
    if ($info.Id -eq 'r101255' -and $info.Name -eq 'Japan') {
        $displayTitle = [string][char]0x65E5 + [char]0x672C; $font = 'Meiryo'
    } elseif ($info.Id -eq 'r101252' -and $info.Name -eq 'Ireland') {
        $displayTitle = [string][char]0x00C9 + 'ire'
    }
    if ($theme -eq 'Classic' -and $displayTitle -match '^[\p{IsBasicLatin}\p{IsLatin-1Supplement}\p{IsLatinExtended-A}]+$') { $font = 'Georgia' }
    $cyTitle = if ($theme -eq 'Classic') { 338 } else { 560 }
    $maxW = if ($theme -eq 'Classic') { 560 } else { 1080 }
    $bold = $theme -eq 'Cartoon' -and (Get-TitleFamily $font).IsStyleAvailable([Drawing.FontStyle]::Bold)
    $title = Center-Title $g $displayTitle $font $bold 'Title' 0 $cyTitle $maxW 135 120
    if ($theme -eq 'Classic') { $title.Transform((New-Object Drawing.Drawing2D.Matrix 1, 0, 0, 1, 280, 0)) }
    $color = if ($theme -eq 'Futuristic') { Rgb 226 252 255 } else { Rgb 255 225 164 }
    if ($theme -eq 'Cartoon') { $g.DrawPath((Outline-Pen (Rgb 8 28 34) 15), (Shifted $title 5 5)); $g.DrawPath((Outline-Pen (Rgb 8 28 34) 12), $title) }
    else { $g.FillPath((Br (Argb 170 (Rgb 0 0 0))), (Shifted $title 4 5)) }
    $g.FillPath((Br $color), $title)
    $name = if ($info.ProviderName) { $info.ProviderName } else { $info.Name }
    $kind = if ($info.ProviderName) { 'LANGUAGE' } else { 'LOCATION' }
    $label = "$name  |  $kind".ToUpperInvariant()
    $labelFont = New-Object Drawing.Font 'Segoe UI', 25, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object Drawing.StringFormat; $fmt.Alignment = 'Center'
    $area = if ($theme -eq 'Classic') { New-Object Drawing.RectangleF 660, 431, 560, 44 } else { New-Object Drawing.RectangleF 70, 630, 1140, 44 }
    $g.DrawString($label, $labelFont, (Br $color), $area, $fmt)
    if ($info.Label -in 'Generic location','Regional map') {
        $small = New-Object Drawing.Font 'Segoe UI', 22, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
        $g.DrawString($info.Label.ToUpperInvariant(), $small, (Br $color), (New-Object Drawing.RectangleF ($cx-230), ($cy+205), 460, 32), $fmt)
    }
    $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
    $ep = New-Object Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), ([long]80)
    $g.Dispose(); $bmp.Save($file, $codec, $ep); $bmp.Dispose()
}
