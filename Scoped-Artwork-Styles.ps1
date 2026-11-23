function Scoped-Scenery($g, $theme, $info) {
    $folder = Join-Path $PSScriptRoot "data\scoped-scenes\$theme"
    $subjects = @{ r101255='Japan'; l178='Japanese'; r101252='Ireland'; l176='Irish'; r100014='Seattle-Tacoma'; l180='Korean' }
    $subject = if ($info.ProviderName) { $info.ProviderName } else { $info.Name }
    $path = $null
    if ($subjects.ContainsKey($info.Id) -and $subjects[$info.Id] -ceq $subject) {
        $path = Join-Path $folder "$($info.Id).png"
    }
    if (-not $path) {
        if ($theme -eq 'Classic') {
            $path = Join-Path $PSScriptRoot 'data\scenes\classic.png'
        } else {
            $path = if ($theme -eq 'Futuristic') { Join-Path $folder 'l178.png' } else { Join-Path $PSScriptRoot 'data\scenes\cartoon.png' }
        }
    }
    if (-not $script:ScopedScenes) { $script:ScopedScenes = @{} }
    if (-not $script:ScopedScenes.ContainsKey($path)) { $script:ScopedScenes[$path] = [Drawing.Image]::FromFile($path) }
    $g.DrawImage($script:ScopedScenes[$path], 0, 0, 1280, 720)
    if ($theme -eq 'Cartoon') { $g.DrawRectangle((New-Object Drawing.Pen (Rgb 245 213 143), 6), 12, 12, 1256, 696) }
}

function Scoped-Flag($g, $flag, $x, $y, $w, $h, $theme) {
    $state = $g.Save(); $g.TranslateTransform($x, $y); $g.ScaleTransform(($w / 420), ($h / 280))
    $g.FillRectangle((Br (Rgb 255 255 250)), 0, 0, 420, 280)
    if ($flag -eq 'Japan') { FE $g (Br (Rgb 188 0 45)) 210 140 84 84 }
    elseif ($flag -eq 'Netherlands') {
        $g.FillRectangle((Br (Rgb 174 28 40)), 0, 0, 420, 93)
        $g.FillRectangle((Br (Rgb 33 70 139)), 0, 187, 420, 93)
    }
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
    for ($i = -100; $i -lt 520; $i += 4) {
        $v = [Math]::Sin($i / 35.0) + 0.4 * [Math]::Sin($i / 13.0)
        $shade = if ($v -lt 0) { Rgb 0 0 0 } else { Rgb 255 255 255 }
        $fold = [Drawing.PointF[]]@((P $i 0), (P ($i+4) 0), (P ($i-76) 280), (P ($i-80) 280))
        $g.FillPolygon((Br (Argb ([int]([Math]::Abs($v) * 48)) $shade)), $fold)
    }
    if ($theme -eq 'Cartoon') { $g.DrawRectangle((New-Object Drawing.Pen (Rgb 12 30 45), 5), 0, 0, 420, 280) }
    $g.Restore($state)
}

function Scoped-FlagDisplay($g, $info, $theme) {
    $width = if ($theme -eq 'Futuristic') { 560 } else { 620 }
    $height = [int]($width * $(if ($info.Flag -eq 'Ireland') { 0.5 } elseif ($info.Flag -eq 'Iceland') { 0.72 } else { 2.0/3 }))
    $flag = New-Object Drawing.Bitmap $width, $height
    $paint = [Drawing.Graphics]::FromImage($flag)
    $paint.SmoothingMode = 'AntiAlias'
    Scoped-Flag $paint $info.Flag 0 0 $width $height $theme
    $paint.Dispose()
    if ($theme -eq 'Futuristic') {
        $pts = [Drawing.PointF[]]@((P -290 (-$height/2 - 20)), (P 275 (-$height/2 + 20)), (P -285 ($height/2 - 20)))
        $frame = [Drawing.PointF[]]@((P -305 (-$height/2 - 35)), (P 290 (-$height/2 + 5)), (P 295 ($height/2 + 35)), (P -300 ($height/2 - 35)))
        $g.DrawPolygon((New-Object Drawing.Pen (Rgb 26 217 255), 7), $frame)
        $g.DrawImage($flag, $pts)
        $scan = New-Object Drawing.Pen (Argb 40 (Rgb 25 139 255)), 2
        for ($y = -$height/2; $y -lt $height/2; $y += 8) { L $g $scan -280 $y 270 $y }
    } else {
        if ($theme -eq 'Cartoon') {
            $g.DrawLine((New-Object Drawing.Pen (Rgb 19 24 26), 16), -325, (-$height/2-35), -325, ($height/2+40))
            $g.DrawLine((New-Object Drawing.Pen (Rgb 231 184 90), 7), -325, (-$height/2-35), -325, ($height/2+40))
            FE $g (Br (Rgb 237 192 100)) -325 (-$height/2-42) 14 14
        }
        for ($x = 0; $x -lt $width; $x += 4) {
            $wave = 16 * [Math]::Sin($x / 110.0) + 10 * [Math]::Sin($x / 55.0)
            $dest = New-Object Drawing.Rectangle ([int]($x-$width/2)), ([int](-$height/2+$wave)), 4, $height
            $g.DrawImage($flag, $dest, $x, 0, 4, $height, [Drawing.GraphicsUnit]::Pixel)
        }
    }
    $flag.Dispose()
}

function Scoped-Motif($g, $info, $theme, $cx, $cy) {
    $state = $g.Save(); $g.TranslateTransform($cx, $cy)
    if ($info.Motif -eq 'flag') {
        Scoped-FlagDisplay $g $info $theme
    } elseif ($info.Motif -eq 'map') {
        if ($theme -eq 'Cartoon') { $g.ScaleTransform(1.4, 1.4) }
        $fill = if ($theme -eq 'Futuristic') { Rgb 8 103 144 } else { Rgb 225 183 96 }
        $edge = if ($theme -eq 'Futuristic') { Rgb 48 235 255 } elseif ($theme -eq 'Cartoon') { Rgb 13 30 34 } else { Rgb 250 220 148 }
        $shape = New-Object Drawing.Drawing2D.GraphicsPath
        foreach ($ring in $info.MapRings) { if ($ring.Count -ge 6) { $shape.AddPolygon((Pts $ring)) } }
        if ($theme -eq 'Futuristic') {
            $g.FillPath((Br (Argb 90 (Rgb 5 75 110))), $shape)
            $g.DrawPath((New-Object Drawing.Pen (Argb 55 (Rgb 0 160 255)), 15), $shape)
            $g.DrawPath((New-Object Drawing.Pen (Argb 100 (Rgb 18 204 255)), 6), $shape)
        } else { $g.FillPath((Br $fill), $shape) }
        $clip = $g.Save(); $g.SetClip($shape)
        if ($theme -eq 'Futuristic') {
            $texture = New-Object Drawing.Pen (Argb 100 (Rgb 61 238 255)), 1
            for ($y = -260; $y -le 260; $y += 9) { L $g $texture -260 $y 260 ($y + 100) }
            for ($x = -300; $x -le 300; $x += 12) { L $g $texture $x -260 ($x+150) 260 }
            $texture.Dispose()
        } else {
            $random = New-Object Random $info.Seed
            $gold = Br (Argb 105 (Rgb 255 231 150))
            $shade = if ($theme -eq 'Cartoon') { Br (Argb 105 (Rgb 49 105 53)) } else { Br (Argb 65 (Rgb 106 64 18)) }
            for ($i = 0; $i -lt 2200; $i++) {
                $x = $random.Next(-215,216); $y = $random.Next(-215,216)
                $r = $random.Next(1,5)
                $g.FillEllipse($(if ($i % 3 -eq 0) { $shade } else { $gold }), $x, $y, $r, $r)
            }
        }
        $g.Restore($clip)
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
    Scoped-Scenery $g $theme $info
    $cx = if ($theme -eq 'Classic') { 320 } elseif ($theme -eq 'Cartoon') { 360 } else { 640 }
    $cy = if ($theme -eq 'Classic') { 300 } elseif ($theme -eq 'Futuristic') { 240 } elseif ($info.Motif -eq 'map') { 310 } else { 245 }
    Scoped-Motif $g $info $theme $cx $cy
    $displayTitle = $info.Name
    $font = if ($info.NativeFont) { $info.NativeFont } else { 'Segoe UI' }
    if ($info.Id -eq 'r101255' -and $info.Name -eq 'Japan') {
        $displayTitle = [string][char]0x65E5 + [char]0x672C; $font = 'Meiryo'
    } elseif ($info.Id -eq 'r101252' -and $info.Name -eq 'Ireland') {
        $displayTitle = [string][char]0x00C9 + 'ire'
    } elseif ($info.Id -eq 'r100014' -and $info.Name -eq 'Seattle-Tacoma') {
        $displayTitle = 'Seattle'
    }
    if ($theme -eq 'Cartoon' -and $displayTitle -match '^[\p{IsBasicLatin}\p{IsLatin-1Supplement}\p{IsLatinExtended-A}]+$') {
        $font = 'Georgia'
        if (-not $info.ProviderName) { $displayTitle = $displayTitle.ToUpperInvariant() }
    }
    if ($theme -eq 'Classic') {
        if ($font -eq 'Meiryo') { $font = 'MS Mincho' }
        elseif ($font -eq 'Malgun Gothic') { $font = 'Noto Serif KR' }
        elseif ($displayTitle -match '^[\p{IsBasicLatin}\p{IsLatin-1Supplement}\p{IsLatinExtended-A}]+$') { $font = 'Georgia' }
    }
    $cyTitle = if ($theme -eq 'Classic') { 325 } else { 575 }
    $maxW = if ($theme -eq 'Classic' -or ($theme -eq 'Cartoon' -and $info.Motif -eq 'map')) { 560 } else { 1080 }
    $bold = $theme -in 'Cartoon','Futuristic' -and (Get-TitleFamily $font).IsStyleAvailable([Drawing.FontStyle]::Bold)
    $title = Center-Title $g $displayTitle $font $bold 'Title' 0 $cyTitle $maxW 150 160
    if ($theme -eq 'Classic') { $title.Transform((New-Object Drawing.Drawing2D.Matrix 1, 0, 0, 1, 280, 0)) }
    if ($theme -eq 'Cartoon' -and $info.Motif -eq 'map') { $title.Transform((New-Object Drawing.Drawing2D.Matrix 1, 0, 0, 1, 250, 0)) }
    $color = if ($theme -eq 'Futuristic') { Rgb 226 252 255 } else { Rgb 255 225 164 }
    if ($theme -eq 'Cartoon') { $g.DrawPath((Outline-Pen (Rgb 8 28 34) 15), (Shifted $title 5 5)); $g.DrawPath((Outline-Pen (Rgb 8 28 34) 12), $title) }
    elseif ($theme -eq 'Futuristic') { $g.DrawPath((Outline-Pen (Argb 100 (Rgb 0 162 255)) 8), $title) }
    else { $g.FillPath((Br (Argb 170 (Rgb 0 0 0))), (Shifted $title 4 5)) }
    $g.FillPath((Br $color), $title)
    $name = if ($info.ProviderName) { $info.ProviderName } else { $info.Name }
    $kind = if ($info.ProviderName) { 'LANGUAGE' } else { 'LOCATION' }
    $label = "$name  $([char]0x2022)  $kind".ToUpperInvariant()
    if ($theme -eq 'Classic') { $label = Spaced $label }
    $labelFont = New-Object Drawing.Font 'Segoe UI', $(if($theme -eq 'Classic'){22}else{25}), ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object Drawing.StringFormat; $fmt.Alignment = 'Center'
    $area = if ($theme -eq 'Classic') { New-Object Drawing.RectangleF 660, 455, 560, 44 }
        elseif ($theme -eq 'Cartoon' -and $info.Motif -eq 'map') { New-Object Drawing.RectangleF 650, 645, 570, 44 }
        else { New-Object Drawing.RectangleF 70, 645, 1140, 44 }
    if ($theme -eq 'Classic') {
        $gold = New-Object Drawing.Pen (Rgb 233 190 104), 2
        L $g $gold 700 430 885 430; L $g $gold 955 430 1140 430
        $g.DrawEllipse($gold, 910, 420, 20, 20)
    }
    $g.DrawString($label, $labelFont, (Br $color), $area, $fmt)
    if ($info.Label -in 'Generic location','Regional map') {
        $small = New-Object Drawing.Font 'Segoe UI', 22, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
        $y = if ($theme -eq 'Cartoon' -and $info.Motif -eq 'map') { 480 } else { $cy+225 }
        $g.DrawString($info.Label.ToUpperInvariant(), $small, (Br $color), (New-Object Drawing.RectangleF ($cx-230), $y, 460, 32), $fmt)
    }
    $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
    $ep = New-Object Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), ([long]80)
    $g.Dispose(); $bmp.Save($file, $codec, $ep); $bmp.Dispose()
}
