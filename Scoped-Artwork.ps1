# Natural-language names come from Windows' neutral culture data. Unlisted TuneIn
# categories deliberately retain the provider's label rather than guessing.
function Motif-neutral($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pen = Pn $c 5 $k
        E $g $pen 0 0 200 200; E $g $pen 0 0 90 200
        L $g $pen -200 0 200 0; Arc $g $pen 0 0 150 0 180; Arc $g $pen 0 0 150 180 180
    }
}
function Motif-flag($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pen = Pn $c 6 $k
        if ($info.Flag -eq 'Japan') { Rc $g $pen -210 -140 420 280; E $g $pen 0 0 84 84 }
        elseif ($info.Flag -eq 'Iceland') {
            Rc $g $pen -200 -144 400 288
            L $g $pen -88 -144 -88 144; L $g $pen -24 -144 -24 144
            L $g $pen -200 -32 200 -32; L $g $pen -200 32 200 32
        } elseif ($info.Flag -eq 'Netherlands') {
            Rc $g $pen -210 -140 420 280
            L $g $pen -210 -47 210 -47; L $g $pen -210 47 210 47
        }
    }
    $state = $script:G.Save(); Place $script:G $script:OX $script:OY
    if ($info.Flag -eq 'Japan') {
        $script:G.FillRectangle((Br (Rgb 255 255 255)), -210, -140, 420, 280)
        FE $script:G (Br (Rgb 188 0 45)) 0 0 84 84
    } elseif ($info.Flag -eq 'Iceland') {
        $script:G.FillRectangle((Br (Rgb 0 82 156)), -200, -144, 400, 288)
        $script:G.FillRectangle((Br (Rgb 255 255 255)), -88, -144, 64, 288)
        $script:G.FillRectangle((Br (Rgb 255 255 255)), -200, -32, 400, 64)
        $script:G.FillRectangle((Br (Rgb 220 30 53)), -72, -144, 32, 288)
        $script:G.FillRectangle((Br (Rgb 220 30 53)), -200, -16, 400, 32)
    } elseif ($info.Flag -eq 'Netherlands') {
        $script:G.FillRectangle((Br (Rgb 174 28 40)), -210, -140, 420, 93)
        $script:G.FillRectangle((Br (Rgb 33 70 139)), -210, 47, 420, 93)
    }
    $script:G.Restore($state)
}
function Motif-map($cl, $info) {
    Neon $cl[0] { param($g, $c, $k)
        $pen = Pn $c 5 $k
        foreach ($ring in $info.MapRings) {
            if ($ring.Count -ge 6) { $g.DrawPolygon($pen, (Pts $ring)) }
        }
        if ($info.MapPoint) {
            $state = $script:G.Save(); Place $script:G $script:OX $script:OY
            FE $script:G (Br (Rgb 255 246 220)) $info.MapPoint[0] $info.MapPoint[1] 13 13
            FE $script:G (Br (Rgb 208 32 45)) $info.MapPoint[0] $info.MapPoint[1] 9 9
            FE $script:G (Br (Rgb 255 255 255)) $info.MapPoint[0] $info.MapPoint[1] 3 3
            $script:G.Restore($state)
        }
    }
}
$LanguageCultures = @{
    Afrikaans='af'; Albanian='sq'; Arabic='ar'; Armenian='hy'; Azerbaijani='az'
    Basque='eu'; Bashkir='ba'; Belarusian='be'; Bengali='bn'; Bosnian='bs'; Bulgarian='bg'
    Catalan='ca'; Chinese='zh'; Croatian='hr'; Czech='cs'; Dhivehi='dv'
    Danish='da'; Dutch='nl'; English='en'; Estonian='et'; Faroese='fo'
    Finnish='fi'; French='fr'; Galician='gl'; German='de'; Greek='el'
    Gujarati='gu'; Hausa='ha'; Hawaiian='haw'; Hebrew='he'; Hindi='hi'; Hungarian='hu'
    Icelandic='is'; Indonesian='id'; Irish='ga'; Italian='it'; Japanese='ja'
    Kannada='kn'; Kashmiri='ks'; Khmer='km'; Korean='ko'; Latvian='lv'; Lithuanian='lt'
    Macedonian='mk'; Malay='ms'; Malayalam='ml'; Maltese='mt'; Nepali='ne'
    'Myanmar (Burmese)'='my'; Norwegian='no'; 'Norwegian Bokmal'='nb'; Papiamentu='pap'
    Pashto='ps'; Persian='fa'; Polish='pl'; Portuguese='pt'
    Punjabi='pa'; Romanian='ro'; Romansch='rm'; Russian='ru'; Serbian='sr'; Shona='sn'; Sindhi='sd'
    Sinhala='si'; Slovak='sk'; Slovenian='sl'; Spanish='es'; Swahili='sw'
    Swedish='sv'; Tamil='ta'; Telugu='te'; Thai='th'; Turkish='tr'
    Ukrainian='uk'; Urdu='ur'; Uyghur='ug'; Uzbek='uz'; Vietnamese='vi'; Welsh='cy'; Yoruba='yo'
}

# Verified direct children of TuneIn's Canada and United States location nodes.
# The provider does not otherwise distinguish regions from cities in OPML.
$KnownRegions = @{
    r100447='Canada|Alberta'; r100453='Canada|British Columbia'; r100475='Canada|Manitoba'
    r100484='Canada|New Brunswick'; r100488='Canada|Newfoundland and Labrador'
    r100493='Canada|Northwest Territories'; r100492='Canada|Nova Scotia'; r100494='Canada|Nunavut'
    r100498='Canada|Ontario'; r100501='Canada|Prince Edward Island'; r100503='Canada|Quebec'
    r100508='Canada|Saskatchewan'; r100520='Canada|Yukon'
    r100449='United States|Alabama'; r100448='United States|Alaska'; r100452='United States|Arizona'
    r100450='United States|Arkansas'; r100455='United States|California'; r100457='United States|Colorado'
    r100458='United States|Connecticut'; r100460='United States|Delaware'; r100462='United States|Florida'
    r100464='United States|Georgia'; r100466='United States|Hawaii'; r100468='United States|Idaho'
    r100469='United States|Illinois'; r100470='United States|Indiana'; r100467='United States|Iowa'
    r100471='United States|Kansas'; r100472='United States|Kentucky'; r100473='United States|Louisiana'
    r100477='United States|Maine'; r100476='United States|Maryland'; r100474='United States|Massachusetts'
    r100478='United States|Michigan'; r100479='United States|Minnesota'; r100482='United States|Mississippi'
    r100480='United States|Missouri'; r100483='United States|Montana'; r100487='United States|Nebraska'
    r100495='United States|Nevada'; r100489='United States|New Hampshire'; r100490='United States|New Jersey'
    r100491='United States|New Mexico'; r101322='United States|New York'; r100485='United States|North Carolina'
    r100486='United States|North Dakota'; r100496='United States|Ohio'; r100497='United States|Oklahoma'
    r100499='United States|Oregon'; r100500='United States|Pennsylvania'; r100505='United States|Rhode Island'
    r100506='United States|South Carolina'; r100507='United States|South Dakota'; r100510='United States|Tennessee'
    r100511='United States|Texas'; r100512='United States|Utah'; r100515='United States|Vermont'
    r100513='United States|Virginia'; r100516='United States|Washington'; r100518='United States|West Virginia'
    r100517='United States|Wisconsin'; r100519='United States|Wyoming'
}

function Get-LanguageFont([string]$culture) {
    switch ($culture) {
        { $_ -in 'ja' } { 'Meiryo'; break }
        { $_ -in 'zh','yue' } { 'Microsoft YaHei'; break }
        'ko' { 'Malgun Gothic'; break }
        { $_ -in 'bn','gu','hi','kn','ml','mr','ne','pa','si','ta','te' } { 'Nirmala UI'; break }
        'th' { 'Leelawadee UI'; break }
        'km' { 'Noto Sans Khmer'; break }
        'my' { 'Myanmar Text'; break }
        'dv' { 'MV Boli'; break }
        default { 'Segoe UI' }
    }
}

function Get-Languages {
    $items = [ordered]@{}
    $doc = Get-Opml 'https://opml.radiotime.com/Browse.ashx?c=lang'
    foreach ($node in $doc.SelectNodes('/opml/body/outline[@type="link"]')) {
        if ($node.URL -cnotmatch '(?:\?|&)filter=(l[1-9][0-9]{0,9})(?:&|$)') { continue }
        $id = $Matches[1]; $name = ([string]$node.text).Trim()
        if (-not $name -or $items.Contains($id)) { continue }
        $title = $name; $font = 'Segoe UI'; $rtl = $false
        if ($name -eq 'Cantonese') {
            $title = [string][char]0x7CB5 + [char]0x8A9E; $font = 'Microsoft YaHei'
        } elseif ($LanguageCultures.ContainsKey($name)) {
            $code = $LanguageCultures[$name]
            try { $culture = [Globalization.CultureInfo]::GetCultureInfo($code) }
            catch [Globalization.CultureNotFoundException] { throw "Windows does not support culture '$code' for '$name'." }
            $title = $culture.NativeName; $font = Get-LanguageFont $code; $rtl = $culture.TextInfo.IsRightToLeft
            if ($title -like 'Unknown Language*') { throw "Windows has no native name for '$name' ($code)." }
        } else { Write-Warning "No curated native name for '$name'; using the TuneIn label." }
        $flag = if (-not $NeutralLanguages -and ($name -in 'Dutch','Japanese','Icelandic' -or
            ($name -in 'Irish','Korean' -and $baseTheme -in 'Cartoon','Futuristic','Classic'))) {
            @{ Dutch='Netherlands'; Japanese='Japan'; Icelandic='Iceland'; Irish='Ireland'; Korean='South Korea' }[$name]
        } else { $null }
        $flagCode = $null
        if ($baseTheme -in 'Cartoon','Futuristic','Classic') {
            $profile = (Get-ScopedProfiles).languages.PSObject.Properties[$name]
            if ($profile -and -not $NeutralLanguages) {
                $flag = $profile.Value.flag
                $flagCode = $profile.Value.code
            }
        }
        $items[$id] = @{
            Id=$id; Name=$title; ProviderName=$name; Parent='Languages'; Sub=$false; Style='Electronic'
            Motif=$(if ($flag) { 'flag' } else { 'neutral' }); Flag=$flag; FlagCode=$flagCode
            Label=$(if ($flag) { 'Representative flag' } else { 'Language' }); NativeFont=$font; RTL=$rtl
        }
    }
    return ,$items
}

function Get-ScopedProfiles {
    if (-not $script:ScopedProfiles) {
        $profiles = Get-Content (Join-Path $PSScriptRoot 'data\scoped-scenes\profiles.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($region in $profiles.regions.PSObject.Properties) {
            if ($region.Name -cnotmatch '^[a-z]+(?:-[a-z]+)*$') { throw "Invalid scenery region: $($region.Name)" }
        }
        foreach ($entry in @($profiles.countries.PSObject.Properties) + @($profiles.continents.PSObject.Properties)) {
            if (-not $profiles.regions.PSObject.Properties[[string]$entry.Value]) { throw "Unknown scenery region for $($entry.Name)" }
        }
        foreach ($entry in @($profiles.languages.PSObject.Properties) + @($profiles.states.PSObject.Properties)) {
            if (-not $profiles.regions.PSObject.Properties[[string]$entry.Value.region]) { throw "Unknown scenery region for $($entry.Name)" }
            if ($entry.Value.code -and ($entry.Value.code -cnotmatch '^[a-z]{2}(?:-[a-z]{2,3})?$' -or -not $entry.Value.flag)) {
                throw "Invalid representative flag for $($entry.Name)"
            }
        }
        $script:ScopedProfiles = $profiles
    }
    return $script:ScopedProfiles
}

function Get-Locations {
    $items = [ordered]@{}
    $queue = New-Object System.Collections.Queue
    $queue.Enqueue(@{ Id=$LocationRoot; Level=$LocationRootLevel; Parent='Locations'; Country=$null })
    $visited = @{}; $requests = 0
    while ($queue.Count) {
        $entry = $queue.Dequeue()
        if ($visited.ContainsKey($entry.Id)) { continue }
        if ($requests -ge $MaxLocationRequests) { throw "Location discovery exceeded $MaxLocationRequests requests; increase -MaxLocationRequests or restrict the root/depth." }
        $visited[$entry.Id] = $true; $requests++
        $doc = Get-Opml "https://opml.radiotime.com/Browse.ashx?id=$($entry.Id)"
        if ($entry.Id -ne 'r0' -and -not $items.Contains($entry.Id)) {
            $rootName = [string]$doc.opml.head.title
            if (-not $rootName.Trim()) { throw "Location $($entry.Id) has no title." }
            if ($entry.Level -eq 2) { $entry.Country = $rootName }
            if ($entry.Level -eq 3 -and $KnownRegions.ContainsKey($entry.Id)) {
                $parts = $KnownRegions[$entry.Id] -split '\|', 2
                if ($parts[1] -eq $rootName) { $entry.Country = $parts[0] }
            }
            $items[$entry.Id] = @{ Id=$entry.Id; Name=$rootName; Parent=$entry.Parent; Level=$entry.Level; Country=$entry.Country }
        }
        if (-not $AllLocations -and $entry.Level -ge $LocationDepth) { continue }
        if ($AllLocations) {
            foreach ($link in $doc.SelectNodes('/opml/body//outline[@type="link"]')) {
                if ([string]$link.URL -match '(?i)(?:\?|&)(?:offset|page|cursor|start)=' -or
                    [string]$link.key -match '(?i)(next|more|page)') {
                    if ($link.key -ceq 'nextStations' -and [string]$link.URL -match '(?:\?|&)filter=s(?:&|$)') { continue }
                    throw "Unsupported location pagination in $($entry.Id): $($link.URL)"
                }
            }
        }
        $selector = if ($AllLocations) { '/opml/body//outline[@type="link"][@guide_id]' } else { '/opml/body/outline[@type="link"][@guide_id]' }
        foreach ($node in $doc.SelectNodes($selector)) {
            $id = [string]$node.guide_id; $name = ([string]$node.text).Trim()
            if ($id -cnotmatch '^r[1-9][0-9]{0,9}$') { continue }
            if (-not $name) {
                if ($AllLocations) { throw "Location $id has no title." }
                continue
            }
            if ($AllLocations) {
                $url = [Uri]$node.URL
                if ($url.Scheme -notin @('http','https') -or $url.Host -cne 'opml.radiotime.com' -or
                    -not $url.IsDefaultPort -or $url.UserInfo -or $url.AbsolutePath -cne '/Browse.ashx' -or
                    $url.Query -cne "?id=$id" -or $url.Fragment) { throw "Noncanonical location link $id $url" }
            }
            if ($items.Contains($id)) { continue }
            $level = $entry.Level + 1
            $parent = if ($entry.Id -eq 'r0') { 'Locations' } else { $items[$entry.Id].Name }
            $country = if ($level -eq 2) { $name } else { $entry.Country }
            $items[$id] = @{ Id=$id; Name=$name; Parent=$parent; ParentId=$entry.Id; Level=$level; Country=$country }
            if ($AllLocations -or $level -lt $LocationDepth) { $queue.Enqueue(@{ Id=$id; Level=$level; Parent=$parent; Country=$country }) }
        }
    }
    return ,$items
}

function Get-MapProjection($geometry) {
    $polygons = @()
    if ($geometry.type -eq 'Polygon') { $polygons += ,$geometry.coordinates }
    elseif ($geometry.type -eq 'MultiPolygon') { foreach ($polygon in $geometry.coordinates) { $polygons += ,$polygon } }
    else { return }
    $rings = @(); $xs = New-Object 'System.Collections.Generic.List[double]'; $ys = New-Object 'System.Collections.Generic.List[double]'
    foreach ($polygon in $polygons) {
        if (-not $polygon.Count) { continue }
        $ring = $polygon[0]
        if ($ring.Count -lt 3) { continue }
        $rings += ,$ring
        foreach ($point in $ring) { $xs.Add([double]$point[0]); $ys.Add([double]$point[1]) }
    }
    if (-not $xs.Count) { return }
    $xmin = ($xs | Measure-Object -Minimum).Minimum; $xmax = ($xs | Measure-Object -Maximum).Maximum
    $ymin = ($ys | Measure-Object -Minimum).Minimum; $ymax = ($ys | Measure-Object -Maximum).Maximum
    $wrapped = $false
    if (($xmax - $xmin) -gt 180) {
        $shifted = @($xs | ForEach-Object { if ($_ -lt 0) { $_ + 360 } else { $_ } })
        $min = ($shifted | Measure-Object -Minimum).Minimum; $max = ($shifted | Measure-Object -Maximum).Maximum
        if (($max-$min) -lt ($xmax-$xmin)) { $xmin=$min; $xmax=$max; $wrapped=$true }
    }
    if ($xmax -eq $xmin -or $ymax -eq $ymin) { return }
    $lonFactor = [Math]::Cos((($ymin + $ymax) / 2) * [Math]::PI / 180)
    if ($lonFactor -le 0) { return }
    return @{ Rings = $rings; XMin = $xmin; XMax = $xmax; YMin = $ymin; YMax = $ymax
        Wrapped=$wrapped; LonFactor = $lonFactor; Scale = [Math]::Min(420 / (($xmax - $xmin) * $lonFactor), 420 / ($ymax - $ymin)) }
}

function Get-MapRings($geometry) {
    $projection = Get-MapProjection $geometry
    if (-not $projection) { return }
    $result = New-Object System.Collections.ArrayList
    foreach ($ring in $projection.Rings) {
        $values = foreach ($point in $ring) {
            $lon = if ($projection.Wrapped -and $point[0] -lt 0) { $point[0]+360 } else { $point[0] }
            [float](($lon - ($projection.XMin + $projection.XMax) / 2) * $projection.LonFactor * $projection.Scale)
            [float]((($projection.YMin + $projection.YMax) / 2 - $point[1]) * $projection.Scale)
        }
        [void]$result.Add([float[]]$values)
    }
    return ,$result.ToArray()
}

function Get-MapPoint($geometry, [double]$lon, [double]$lat) {
    $projection = Get-MapProjection $geometry
    if (-not $projection) { throw 'Cannot project marker on invalid map geometry.' }
    if ($projection.Wrapped -and $lon -lt 0) { $lon += 360 }
    if ($lon -lt $projection.XMin -or $lon -gt $projection.XMax -or $lat -lt $projection.YMin -or $lat -gt $projection.YMax) { throw 'Map marker falls outside its verified map bounds.' }
    return ,@([float](($lon - ($projection.XMin + $projection.XMax) / 2) * $projection.LonFactor * $projection.Scale), [float]((($projection.YMin + $projection.YMax) / 2 - $lat) * $projection.Scale))
}

function Test-MapContainsPoint($geometry, [double]$lon, [double]$lat) {
    $projection = Get-MapProjection $geometry
    if (-not $projection) { return $false }
    if ($projection.Wrapped -and $lon -lt 0) { $lon += 360 }
    if ($lon -lt $projection.XMin -or $lon -gt $projection.XMax -or $lat -lt $projection.YMin -or $lat -gt $projection.YMax) { return $false }
    $polygons = @()
    if ($geometry.type -eq 'Polygon') { $polygons += ,$geometry.coordinates }
    else { foreach ($polygon in $geometry.coordinates) { $polygons += ,$polygon } }
    foreach ($polygon in $polygons) {
        $insidePolygon = $false
        for ($r = 0; $r -lt $polygon.Count; $r++) {
            $ring = $polygon[$r]; $inside = $false
            $j = $ring.Count - 1
            for ($i = 0; $i -lt $ring.Count; $i++) {
                $xi = [double]$ring[$i][0]; $xj = [double]$ring[$j][0]
                if ($projection.Wrapped) {
                    if ($xi -lt 0) { $xi += 360 }
                    if ($xj -lt 0) { $xj += 360 }
                }
                $yi = [double]$ring[$i][1]; $yj = [double]$ring[$j][1]
                if (($yi -gt $lat) -ne ($yj -gt $lat) -and $lon -lt (($xj - $xi) * ($lat - $yi) / ($yj - $yi) + $xi)) { $inside = -not $inside }
                $j = $i
            }
            if ($r -eq 0) { $insidePolygon = $inside }
            elseif ($inside) { $insidePolygon = $false; break }
        }
        if ($insidePolygon) { return $true }
    }
    return $false
}

function Get-PopulatedPlacePoint($info, $parent, [string]$country, $places) {
    if ($info.ParentId -cne $parent.Id -or $info.Country -cne $parent.Country -or
        $info.Name -ceq $parent.Name -or $parent.Level -notin 2,3) { return }
    if ($parent.Level -eq 3 -and $KnownRegions[$parent.Id] -cne "$($parent.Country)|$($parent.Name)") { return }
    $candidates = @($places | Where-Object {
        $_.name -ceq $info.Name -and $_.country -ceq $country -and
        $(if ($parent.Level -eq 3) { $_.region -ceq $parent.Name } else { $true })
    })
    if ($candidates.Count -ne 1) { return }
    $place = $candidates[0]
    if ($parent.Level -eq 2 -and $place.region -ceq $info.Name) { return }
    if (Test-MapContainsPoint $parent.MapGeometry $place.lon $place.lat) {
        return ,(Get-MapPoint $parent.MapGeometry $place.lon $place.lat)
    }
}

function Set-LocationArt($items) {
    $data = Get-Content (Join-Path $PSScriptRoot 'data\natural-earth.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $detailedCountries = Get-Content (Join-Path $PSScriptRoot 'data\natural-earth-countries-50m.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $washington = Get-Content (Join-Path $PSScriptRoot 'data\washington-50m.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $aliases = @{
        'United States'='United States of America'; 'Cape Verde'='Cabo Verde'; Congo='Republic of the Congo'
        "Cote D'ivoire"='Ivory Coast'; 'DR Congo'='Democratic Republic of the Congo'
        'Sao Tome-Principe'="S$([char]0xE3)o Tom$([char]0xE9) and Principe"; 'St. Helena'='Saint Helena'; Swaziland='eSwatini'
        Tanzania='United Republic of Tanzania'; 'Brunei Darussalam'='Brunei'; 'Hong Kong'='Hong Kong S.A.R.'
        'Myanmar (Burma)'='Myanmar'; 'Wallis-Futuna Islands'='Wallis and Futuna'; 'Czech Republic'='Czechia'
        Macedonia='North Macedonia'; Serbia='Republic of Serbia'; 'Vatican City'='Vatican'
        'St. Pierre-Miquelon'='Saint Pierre and Miquelon'; 'Antigua-Barbuda'='Antigua and Barbuda'
        'Cayman Island'='Cayman Islands'; 'Saint Kitts-Nevis'='Saint Kitts and Nevis'
        'Saint Vincent-The Grenadines'='Saint Vincent and the Grenadines'; 'St. Martin'='Saint Martin'
        'Trinidad-Tobago'='Trinidad and Tobago'; 'Turks-Caicos Islands'='Turks and Caicos Islands'
        'Virgin Islands (British)'='British Virgin Islands'; 'Virgin Islands (U.S.)'='United States Virgin Islands'
        Bahamas='The Bahamas'
        "Saint Barth$([char]0xE9)lemy"='Saint Barthelemy'; "Cura$([char]0xE7)ao"="Cura$([char]0xE7)ao"
    }
    $profiles = if ($baseTheme -in 'Cartoon','Futuristic','Classic') { Get-ScopedProfiles }
    if (-not $script:ScopedPlaces) {
        $script:ScopedPlaces = @{}
        $places = Get-Content (Join-Path $PSScriptRoot 'data\natural-earth-places-10m.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($place in $places) {
            $key = "$($place.country)`n$($place.name)"
            if (-not $script:ScopedPlaces.ContainsKey($key)) { $script:ScopedPlaces[$key] = New-Object System.Collections.ArrayList }
            [void]$script:ScopedPlaces[$key].Add($place)
        }
    }
    # Approximate city centers, tied to the exact TuneIn subject and verified ancestor.
    $markers = @{
        r100014=@{ Name='Seattle-Tacoma'; Country='United States'; ParentId='r100516'; Lon=-122.3321; Lat=47.6062 }
        r100598=@{ Name='Calgary'; Country='Canada'; ParentId='r100447'; Lon=-114.0719; Lat=51.0447 }
    }
    foreach ($info in $items.Values) {
        $info.Remove('MapPoint')
        $info.Style = 'Electronic'; $info.Sub = $false; $info.NativeFont = 'Segoe UI'
        $info.Motif = 'neutral'; $info.Label = 'Generic location'
        if ($profiles) {
            $profile = if ($info.Country) { $profiles.countries.PSObject.Properties[$info.Country] }
                elseif ($info.Level -eq 1) { $profiles.continents.PSObject.Properties[$info.Name] }
            if ($profile) { $info.SceneryRegion = $profile.Value }
            $state = $profiles.states.PSObject.Properties[$info.Id]
            if ($state -and $state.Value.subject -ceq $info.Name -and $state.Value.country -ceq $info.Country) {
                $info.SceneryRegion = $state.Value.region; $info.StateScenery = $true
            }
        }
        $country = if ($info.Country -and $aliases.ContainsKey($info.Country)) { $aliases[$info.Country] } else { $info.Country }
        $features = @(if ($info.Level -eq 2) {
            $detailed = @($detailedCountries | Where-Object { $_.name -eq $country })
            if ($detailed.Count) { $detailed } else { $data.countries | Where-Object { $_.name -eq $country } }
        } elseif ($info.Country -eq 'Caribbean Islands') {
            $name = if ($aliases.ContainsKey($info.Name)) { $aliases[$info.Name] } else { $info.Name }
            $detailedCountries | Where-Object { $_.name -eq $name }
        } elseif ($info.Level -eq 3 -and $country -and $KnownRegions[$info.Id] -eq "$($info.Country)|$($info.Name)") {
            if ($info.Id -eq 'r100516') { $washington }
            else { $data.regions | Where-Object { $_.country -eq $country -and $_.name -eq $info.Name } }
        })
        if ($features.Count -eq 1) {
            $rings = Get-MapRings $features[0].geometry
            if ($rings) { $info.MapRings = $rings; $info.MapGeometry = $features[0].geometry; $info.Motif = 'map'; $info.Label = 'Map' }
        }
    }
    foreach ($info in $items.Values) {
        if ($profiles) {
            $parentId = $info.ParentId; $seen = @{}
            while ($parentId -and $items.Contains($parentId) -and -not $seen.ContainsKey($parentId)) {
                $seen[$parentId]=$true; $parent=$items[$parentId]
                if ($parent.StateScenery) { $info.SceneryRegion=$parent.SceneryRegion; break }
                $parentId=$parent.ParentId
            }
        }
        if ($info.Motif -ne 'neutral') { continue }
        $parentId = $info.ParentId; $seen = @{}
        while ($parentId -and $items.Contains($parentId) -and -not $seen.ContainsKey($parentId)) {
            $seen[$parentId] = $true; $parent = $items[$parentId]
            if ($parent.Motif -eq 'map' -and $parent.Label -eq 'Map') {
                $info.Motif = 'map'; $info.MapRings = $parent.MapRings; $info.Label = 'Regional map'
                $marker = $markers[$info.Id]
                if ($marker -and $info.Name -ceq $marker.Name -and $info.Country -ceq $marker.Country -and
                    $info.ParentId -ceq $marker.ParentId -and $parent.Id -ceq $marker.ParentId) {
                    $info.MapPoint = Get-MapPoint $parent.MapGeometry $marker.Lon $marker.Lat
                } elseif (-not $marker) {
                    $country = if ($aliases.ContainsKey($info.Country)) { $aliases[$info.Country] } else { $info.Country }
                    $key = "$country`n$($info.Name)"
                    if ($script:ScopedPlaces.ContainsKey($key)) {
                        $info.MapPoint = Get-PopulatedPlacePoint $info $parent $country $script:ScopedPlaces[$key]
                    }
                }
                break
            }
            $parentId = $parent.ParentId
        }
    }
}
