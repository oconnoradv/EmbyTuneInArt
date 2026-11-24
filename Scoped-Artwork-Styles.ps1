function Get-ScopedScene($theme, $info) {
    if ($theme -notin 'Cartoon','Futuristic','Classic') { throw "Unsupported scoped scenery theme: $theme" }
    if (-not $script:ScopedSubjects) {
        $registry = Get-Content (Join-Path $PSScriptRoot 'data\scoped-scenes\subjects.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $subjects = @{}
        foreach ($entry in $registry.PSObject.Properties) {
            if ($entry.Name -cnotmatch '^[lr][1-9][0-9]{0,9}$' -or -not $entry.Value.subject) {
                throw "Invalid scoped scenery subject: $($entry.Name)"
            }
            if ($entry.Value.country -and ($entry.Name -cnotmatch '^r' -or $entry.Value.country -cne $entry.Value.subject)) {
                throw "Country scenery must identify its country: $($entry.Name)"
            }
            $subjects[$entry.Name] = $entry.Value
        }
        $script:ScopedSubjects = $subjects
    }
    $subject = if ($info.ProviderName) { $info.ProviderName } else { $info.Name }
    $sourceId = $null; $title = $null
    if ($script:ScopedSubjects.ContainsKey($info.Id) -and $script:ScopedSubjects[$info.Id].subject -ceq $subject) {
        $sourceId = $info.Id; $title = $script:ScopedSubjects[$sourceId].title
    } elseif ($info.Id -cmatch '^r' -and $info.Country) {
        $countries = @($script:ScopedSubjects.Keys | Where-Object { $script:ScopedSubjects[$_].country -ceq $info.Country })
        if ($countries.Count -gt 1) { throw "Multiple scenery sources for country: $($info.Country)" }
        if ($countries.Count -eq 1) { $sourceId = $countries[0] }
    }
    if ($sourceId) {
        return @{ Path=(Join-Path $PSScriptRoot "data\scoped-scenes\$theme\$sourceId.png")
            SourceId=$sourceId; Title=$title; Inherited=($sourceId -cne $info.Id) }
    }
    $profiles = Get-ScopedProfiles
    $region = $info.SceneryRegion
    if (-not $region) {
        $entry = if ($info.ProviderName) { $profiles.languages.PSObject.Properties[$subject] }
            elseif ($info.Country) { $profiles.countries.PSObject.Properties[$info.Country] }
            elseif ($info.Level -eq 1) { $profiles.continents.PSObject.Properties[$subject] }
        if ($entry) { $region = if ($info.ProviderName) { $entry.Value.region } else { $entry.Value } }
    }
    if ($region) {
        if (-not $profiles.regions.PSObject.Properties[[string]$region]) { throw "Unknown scenery region: $region" }
        if (-not $info.ProviderName -and $region -eq 'north-american-city') {
            return @{ Path=(Get-GenericLocationScenePath $theme); SourceId='generic-landscape'
                Title=$null; Inherited=$true; Generic=$true }
        }
        $asset = if ($theme -eq 'Classic' -and $info.ProviderName) { 'language-fabric' } else { $region }
        return @{ Path=(Join-Path $PSScriptRoot "data\scoped-scenes\$theme\$asset.png")
            SourceId=$asset; Title=$null; Inherited=$true }
    }
}

function Get-GenericLocationScenePath($theme) {
    $asset = if ($theme -eq 'Futuristic') { 'futuristic-landscape' } else { $theme.ToLowerInvariant() }
    return Join-Path $PSScriptRoot "data\scenes\$asset.png"
}

function Assert-ScopedSceneCoverage($items, $theme) {
    $missing = @($items | Where-Object {
        $scene = Get-ScopedScene $theme $_
        -not $scene -or $scene.Generic -or -not (Test-Path -LiteralPath $scene.Path -PathType Leaf) -or
            ($_.FlagCode -and -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "data\flags\$($_.FlagCode).png") -PathType Leaf))
    })
    if ($missing.Count) {
        $examples = ($missing | Select-Object -First 8 | ForEach-Object {
            "$($_.Id) ($(if ($_.ProviderName) { $_.ProviderName } else { $_.Name }))"
        }) -join ', '
        throw "Subject-specific scenery is missing for $($missing.Count) of $($items.Count) $theme cards. Examples: $examples. Add verified entries to data\scoped-scenes\subjects.json and their $theme PNGs before rebuilding the refreshed packs."
    }
}

function Scoped-Scenery($g, $theme, $info) {
    $scene = Get-ScopedScene $theme $info
    if ($scene) {
        if ($RequireScopedScenery -and $scene.Generic) { throw "No subject-specific $theme scenery for $($info.Id)." }
        $path = $scene.Path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing declared scoped scenery: $path" }
    } else {
        if ($RequireScopedScenery) { throw "No subject-specific $theme scenery for $($info.Id)." }
        if (-not $info.ProviderName -and $info.Id -cmatch '^r') {
            $path = Get-GenericLocationScenePath $theme
        } elseif ($theme -eq 'Classic') {
            $path = Join-Path $PSScriptRoot 'data\scenes\classic.png'
        } else {
            $path = if ($theme -eq 'Futuristic') { Join-Path $PSScriptRoot 'data\scoped-scenes\Futuristic\l178.png' } else { Join-Path $PSScriptRoot 'data\scenes\cartoon.png' }
        }
    }
    if (-not $script:ScopedScenes) { $script:ScopedScenes = @{} }
    if (-not $script:ScopedScenes.ContainsKey($path)) { $script:ScopedScenes[$path] = [Drawing.Image]::FromFile($path) }
    $g.DrawImage($script:ScopedScenes[$path], 0, 0, 1280, 720)
    if ($theme -eq 'Cartoon') { $g.DrawRectangle((New-Object Drawing.Pen (Rgb 245 213 143), 6), 12, 12, 1256, 696) }
}

function Get-ScopedFlagImage([string]$code) {
    if ($code -cnotmatch '^[a-z]{2}(?:-[a-z]{2,3})?$') { throw "Invalid flag asset code: $code" }
    if (-not $script:ScopedFlags) { $script:ScopedFlags = @{} }
    if (-not $script:ScopedFlags.ContainsKey($code)) {
        $path = Join-Path $PSScriptRoot "data\flags\$code.png"
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing representative flag: $path" }
        $script:ScopedFlags[$code] = [Drawing.Bitmap]::FromFile($path)
    }
    return $script:ScopedFlags[$code]
}

function Scoped-Flag($g, $flag, $x, $y, $w, $h, $theme, [string]$code) {
    $state = $g.Save(); $g.TranslateTransform($x, $y); $g.ScaleTransform(($w / 420), ($h / 280))
    if ($code) {
        $image = Get-ScopedFlagImage $code
        $g.DrawImage($image, 0, 0, 420, 280)
        if ($theme -eq 'Cartoon' -and $image.GetPixel($image.Width-1, $image.Height-1).A -eq 255) {
            $border = New-Object Drawing.Pen (Rgb 12 30 45), 5
            try { $g.DrawRectangle($border, 0, 0, 420, 280) } finally { $border.Dispose() }
        }
        $g.Restore($state)
        return
    }
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

function Get-ScopedFlagLayout($flag, $theme, [string]$code) {
    $ratio = if ($code) { $image = Get-ScopedFlagImage $code; $image.Height / [double]$image.Width }
        elseif ($flag -eq 'Ireland') { 0.5 } elseif ($flag -eq 'Iceland') { 0.72 } else { 2.0/3 }
    $width = if ($theme -eq 'Futuristic') { 560 } elseif ($theme -eq 'Cartoon') { [int][Math]::Min(620, 380 / $ratio) } else { 620 }
    if ($code) { $width = [int][Math]::Min($width, $(if ($theme -eq 'Futuristic') { 340 } elseif ($theme -eq 'Classic') { 400 } else { 380 }) / $ratio) }
    $height = [int]($width * $ratio)
    $cy = if ($theme -eq 'Futuristic') { 240 } elseif ($theme -eq 'Cartoon') { [Math]::Max(245, $height / 2 + 76) } else { 300 }
    return @{ Width=$width; Height=$height; CenterY=$cy }
}

function Scoped-FlagDisplay($g, $info, $theme) {
    $layout = Get-ScopedFlagLayout $info.Flag $theme $info.FlagCode
    $width = $layout.Width; $height = $layout.Height
    $flag = New-Object Drawing.Bitmap $width, $height
    $paint = [Drawing.Graphics]::FromImage($flag)
    $paint.SmoothingMode = 'AntiAlias'
    Scoped-Flag $paint $info.Flag 0 0 $width $height $theme $info.FlagCode
    $paint.Dispose()
    if ($theme -eq 'Futuristic') {
        $half = $width / 2
        $pts = [Drawing.PointF[]]@((P (-$half-10) (-$height/2 - 20)), (P ($half-5) (-$height/2 + 20)), (P (-$half-5) ($height/2 - 20)))
        $frame = [Drawing.PointF[]]@((P (-$half-25) (-$height/2 - 35)), (P ($half+10) (-$height/2 + 5)), (P ($half+15) ($height/2 + 35)), (P (-$half-20) ($height/2 - 35)))
        $g.DrawPolygon((New-Object Drawing.Pen (Rgb 26 217 255), 7), $frame)
        $g.DrawImage($flag, $pts)
        $scan = New-Object Drawing.Pen (Argb 40 (Rgb 25 139 255)), 2
        for ($y = -$height/2; $y -lt $height/2; $y += 8) { L $g $scan (-$half) $y ($half-10) $y }
    } else {
        if ($theme -eq 'Cartoon') {
            $poleX = if ($info.FlagCode) { -$width/2-15 } else { -325 }
            $g.DrawLine((New-Object Drawing.Pen (Rgb 19 24 26), 16), $poleX, (-$height/2-35), $poleX, ($height/2+40))
            $g.DrawLine((New-Object Drawing.Pen (Rgb 231 184 90), 7), $poleX, (-$height/2-35), $poleX, ($height/2+40))
            FE $g (Br (Rgb 237 192 100)) $poleX (-$height/2-42) 14 14
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
        if ($theme -eq 'Cartoon') { $g.ScaleTransform(1.3, 1.3) }
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
    } elseif ($info.ProviderName) {
        $color = if ($theme -eq 'Futuristic') { Rgb 53 226 250 } else { Rgb 236 203 136 }
        $pen = New-Object Drawing.Pen $color, 6
        $bubble = New-Object Drawing.Drawing2D.GraphicsPath
        try {
            $bubble.AddPolygon((Pts @(-210,-100,170,-100,170,90,-70,90,-150,140,-125,90,-210,90)))
            $g.FillPath((Br (Argb 180 (Rgb 8 36 48))), $bubble)
            $g.DrawPath($pen, $bubble)
            L $g $pen -155 -45 110 -45; L $g $pen -155 0 95 0; L $g $pen -155 45 25 45
        } finally { $bubble.Dispose(); $pen.Dispose() }
    } else {
        $color = if ($theme -eq 'Futuristic') { Rgb 53 226 250 } else { Rgb 236 203 136 }
        $pen = New-Object Drawing.Pen $color, 6
        $pin = New-Object Drawing.Drawing2D.GraphicsPath
        try {
            $pin.AddBezier(0,170,-50,110,-145,15,-145,-65)
            $pin.AddArc(-145,-210,290,290,180,180)
            $pin.AddBezier(145,-65,145,15,50,110,0,170)
            $pin.CloseFigure()
            $g.FillPath((Br (Argb 180 (Rgb 8 36 48))), $pin)
            $g.DrawPath($pen,$pin); E $g $pen 0 -65 55 55
        } finally { $pin.Dispose(); $pen.Dispose() }
    }
    $g.Restore($state)
}

function Fit-ScopedTitle([Drawing.Drawing2D.GraphicsPath]$title, [float]$width, [float]$height) {
    $bounds=$title.GetBounds()
    if ($bounds.Width -gt $width -or $bounds.Height -gt $height) {
        $scale=[Math]::Min($width/$bounds.Width,$height/$bounds.Height)
        $matrix=New-Object Drawing.Drawing2D.Matrix $scale,0,0,$scale,((1-$scale)*($bounds.X+$bounds.Width/2)),((1-$scale)*($bounds.Y+$bounds.Height/2))
        try {$title.Transform($matrix)} finally {$matrix.Dispose()}
    }
}

function New-ScopedCard($info, [string]$file, [string]$theme) {
    $bmp = New-Object Drawing.Bitmap 1280, 720
    $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
    $script:CurrentRTL = [bool]$info.RTL
    Scoped-Scenery $g $theme $info
    $cx = if ($theme -eq 'Classic') { 320 } elseif ($theme -eq 'Cartoon') { 360 } else { 640 }
    $cy = if ($theme -eq 'Classic') { 300 } elseif ($theme -eq 'Futuristic') { 240 } elseif ($info.Motif -eq 'map') { 310 } else { 245 }
    if ($info.Motif -eq 'flag') { $cy = (Get-ScopedFlagLayout $info.Flag $theme $info.FlagCode).CenterY }
    Scoped-Motif $g $info $theme $cx $cy
    $displayTitle = $info.Name
    $scene = Get-ScopedScene $theme $info
    if ($scene -and $scene.Title) { $displayTitle = $scene.Title }
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
    $titleHeight = if ($theme -eq 'Cartoon') { 110 } elseif ($theme -eq 'Futuristic') { 130 } else { 150 }
    Fit-ScopedTitle $title $maxW $titleHeight
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
    $labelWidth = $g.MeasureString($label,$labelFont).Width
    if ($labelWidth -gt $area.Width) {
        $size = $labelFont.Size * $area.Width / $labelWidth * .98
        $labelFont.Dispose()
        $labelFont = New-Object Drawing.Font 'Segoe UI', ([float]$size), ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
    }
    if ($theme -eq 'Classic') {
        $gold = New-Object Drawing.Pen (Rgb 233 190 104), 2
        L $g $gold 700 430 885 430; L $g $gold 955 430 1140 430
        $g.DrawEllipse($gold, 910, 420, 20, 20)
    }
    $shadow = New-Object Drawing.RectangleF ($area.X+2),($area.Y+2),$area.Width,$area.Height
    $g.DrawString($label,$labelFont,(Br (Argb 220 (Rgb 0 0 0))),$shadow,$fmt)
    $g.DrawString($label, $labelFont, (Br $color), $area, $fmt)
    $labelFont.Dispose()
    if ($info.Label -in 'Generic location','Regional map') {
        $small = New-Object Drawing.Font 'Segoe UI', 22, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
        $y = if ($theme -eq 'Cartoon' -and $info.Motif -eq 'map') { 480 } else { $cy+225 }
        $area = New-Object Drawing.RectangleF ($cx-230), $y, 460, 32
        if ($theme -eq 'Cartoon' -and $info.Motif -eq 'map' -and $info.MapPoint) {
            $markerX = $cx + 1.3 * $info.MapPoint[0]; $markerY = $cy + 1.3 * $info.MapPoint[1]
            if ($markerX + 17 -ge $area.Left -and $markerX - 17 -le $area.Right -and
                $markerY + 17 -ge $area.Top -and $markerY - 17 -le $area.Bottom) {
                $area = New-Object Drawing.RectangleF 650, $y, 570, 32
            }
        }
        $g.DrawString($info.Label.ToUpperInvariant(), $small, (Br $color), $area, $fmt)
    }
    $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
    $ep = New-Object Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), ([long]80)
    $g.Dispose(); $bmp.Save($file, $codec, $ep); $bmp.Dispose()
}
