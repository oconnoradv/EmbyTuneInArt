$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Scoped-Artwork.ps1')

function Assert($condition, [string]$message) {
    if (-not $condition) { throw $message }
}
function Get-Opml([string]$url) {
    $script:requests++
    switch -Regex ($url) {
        'c=lang' { return [xml]'<opml><body>
          <outline type="link" text="Japanese" URL="http://opml.radiotime.com/Browse.ashx?c=lang&amp;filter=l178"/>
          <outline type="link" text="Dutch" URL="http://opml.radiotime.com/Browse.ashx?c=lang&amp;filter=l101"/>
          <outline type="link" text="Arabic" URL="http://opml.radiotime.com/Browse.ashx?id=c424724&amp;filter=l122"/>
          <outline type="link" text="Bad" URL="http://opml.radiotime.com/Browse.ashx?filter=l0"/>
          <outline type="link" text="Bad" URL="http://opml.radiotime.com/Browse.ashx?filter=L12"/>
          <outline type="link" text="Bad" URL="http://opml.radiotime.com/Browse.ashx?filter=l12345678901"/>
          <outline type="link" text="Bad" URL="http://opml.radiotime.com/Browse.ashx?filter=l12extra"/>
          <outline type="audio" text="Station" URL="http://opml.radiotime.com/Browse.ashx?filter=l12"/>
        </body></opml>' }
        'id=r0$' { return [xml]'<opml><head><title>Locations</title></head><body>
          <outline type="link" text="North America" guide_id="r101218"/>
          <outline type="audio" text="Station" guide_id="s1"/>
          <outline type="link" text="Invalid" guide_id="r0"/>
        </body></opml>' }
        'id=r101218$' { return [xml]'<opml><head><title>North America</title></head><body>
          <outline type="link" text="Canada" guide_id="r101227"/>
        </body></opml>' }
        'id=r101227$' { return [xml]'<opml><head><title>Canada</title></head><body>
          <outline type="link" text="Alberta" guide_id="r100447"/>
          <outline type="link" text="Cycle" guide_id="r101218"/>
          <outline text="Stations"><outline type="audio" text="Station" guide_id="s1"/></outline>
        </body></opml>' }
        'id=r100447$' { return [xml]'<opml><head><title>Alberta</title></head><body>
          <outline type="link" text="Calgary" guide_id="r100598"/>
          <outline type="audio" text="Station" guide_id="s123"/>
        </body></opml>' }
        default { throw "Unexpected request $url" }
    }
}

$baseTheme='Cartoon'; $NeutralLanguages = $false
$languages = Get-Languages
Assert ($languages.Count -eq 3) 'Language filter IDs or station exclusion failed.'
Assert ($languages['l122'].RTL -and $languages['l122'].Name -eq [Globalization.CultureInfo]::GetCultureInfo('ar').NativeName) 'Arabic native title or RTL failed.'
Assert ($languages['l178'].Flag -eq 'Japan') 'Representative flag mapping failed.'
Assert ($languages['l101'].Flag -eq 'Netherlands' -and $languages['l101'].Motif -eq 'flag') 'Dutch must use the representative Netherlands flag.'
Assert ($languages['l122'].Motif -eq 'neutral') 'Arabic must retain a neutral motif rather than an invented representative nationality.'
$NeutralLanguages = $true
Assert ((Get-Languages)['l178'].Motif -eq 'neutral') 'Neutral language option failed.'
Assert ((Get-Languages)['l101'].Motif -eq 'neutral') 'Neutral language option must disable the Dutch flag.'

$LocationRoot = 'r0'; $LocationRootLevel = 0; $LocationDepth = 4
$MaxLocationRequests = 10; $script:requests = 0; $Only = $null
$locations = Get-Locations
Assert ($locations.Count -eq 4 -and $script:requests -eq 4) 'Location depth, cycles, or station exclusion failed.'
Assert ($locations['r100598'].Parent -eq 'Alberta' -and $locations['r100598'].Country -eq 'Canada') 'Location ancestry failed.'
Set-LocationArt $locations
Assert ($locations['r101227'].Motif -eq 'map' -and $locations['r100447'].Motif -eq 'map') 'Country/region geometry failed.'
Assert ($locations['r100598'].Motif -eq 'map' -and $locations['r100598'].Label -eq 'Regional map') 'City must use the nearest verified ancestor map with an explicit label.'
Assert ($locations['r100598'].SceneryRegion -eq $locations['r100447'].SceneryRegion) 'City scenery must inherit the verified regional profile without changing its title.'
$calgaryPoint = Get-MapPoint $locations['r100447'].MapGeometry -114.0719 51.0447
Assert ($locations['r100598'].MapPoint.Count -eq 2 -and $locations['r100598'].MapPoint[0] -eq $calgaryPoint[0] -and $locations['r100598'].MapPoint[1] -eq $calgaryPoint[1]) 'Calgary must use its own projected coordinates on the Alberta map.'
$locations['r100598'].Name = 'Unrelated'
Set-LocationArt $locations
Assert (-not $locations['r100598'].MapPoint) 'A reused location ID must not retain an unrelated marker.'
$unknown = [ordered]@{ r123=@{ Id='r123'; Name='Alberta'; Country='Canada'; Level=3; Parent='Canada' } }
Set-LocationArt $unknown
Assert ($unknown['r123'].Motif -eq 'neutral') 'Unverified region ID must not inherit a namesake map.'
$countries = [ordered]@{
    r1=@{ Id='r1'; Name='Japan'; Country='Japan'; Level=2; Parent='Asia' }
    r2=@{ Id='r2'; Name='Ireland'; Country='Ireland'; Level=2; Parent='Europe' }
    r100385=@{ Id='r100385'; Name='Netherlands'; Country='Netherlands'; Level=2; Parent='Europe' }
}
Set-LocationArt $countries
Assert ($countries['r1'].MapRings.Count -gt 2 -and $countries['r2'].MapRings.Count -eq 2) 'Detailed country geometries must not be mixed.'
Assert ($countries['r100385'].MapRings.Count -eq 9 -and $countries['r100385'].MapRings[0].Count -gt 300) 'Netherlands must retain its detailed mainland, coastal and Wadden island outlines.'
$outsideEurope = @($countries['r100385'].MapGeometry.coordinates | ForEach-Object {
    $_[0] | Where-Object { $_[0] -lt 3 -or $_[0] -gt 8 -or $_[1] -lt 50 -or $_[1] -gt 54 }
})
Assert (-not $outsideEurope.Count) 'The European Netherlands card must not be distorted by Caribbean territory geometry.'
$regional = [ordered]@{
    r100516=@{ Id='r100516'; Name='Washington'; Country='United States'; Level=3; Parent='United States' }
    r100014=@{ Id='r100014'; Name='Seattle-Tacoma'; Country='United States'; Level=4; Parent='Washington'; ParentId='r100516' }
    r100092=@{ Id='r100092'; Name='Spokane'; Country='United States'; Level=4; Parent='Washington'; ParentId='r100516' }
    r100198=@{ Id='r100198'; Name='Yakima'; Country='United States'; Level=4; Parent='Washington'; ParentId='r100516' }
}
Set-LocationArt $regional
Assert ($regional['r100516'].Motif -eq 'map' -and $regional['r100014'].Label -eq 'Regional map' -and $regional['r100014'].MapPoint.Count -eq 2) 'Seattle must use the verified Washington state outline and marker.'
foreach ($id in 'r100092','r100198') {
    Assert ($regional[$id].MapPoint.Count -eq 2) "An unambiguous populated place in the verified state must be marked: $id."
}
$regional['r100015'] = @{ Id='r100015'; Name='Unknown city'; Country='United States'; Level=4; Parent='Washington'; ParentId='r100516' }
Set-LocationArt $regional
Assert ($regional['r100015'].Motif -eq 'map' -and -not $regional['r100015'].MapPoint) 'An unverified city must not be assigned a guessed marker.'
$MaxLocationRequests = 2; $script:requests = 0
$failed = $false
try { $null = Get-Locations } catch { $failed = $_.Exception.Message -like '*exceeded*' }
Assert ($failed -and $script:requests -eq 2) 'Discovery request limit failed.'

$AllLocations = $true; $MaxLocationRequests = 10; $script:requests = 0
function Get-Opml([string]$url) {
    $script:requests++
    switch -Regex ($url) {
        'id=r0$' { return [xml]'<opml><body><outline type="link" text="Continent" guide_id="r1" URL="http://opml.radiotime.com/Browse.ashx?id=r1"/></body></opml>' }
        'id=r1$' { return [xml]'<opml><body><outline text="Group"><outline type="link" text="Country" guide_id="r2" URL="http://opml.radiotime.com/Browse.ashx?id=r2"/></outline></body></opml>' }
        'id=r2$' { return [xml]'<opml><body><outline type="link" text="Region" guide_id="r3" URL="http://opml.radiotime.com/Browse.ashx?id=r3"/></body></opml>' }
        'id=r3$' { return [xml]'<opml><body><outline type="link" text="City" guide_id="r4" URL="http://opml.radiotime.com/Browse.ashx?id=r4"/></body></opml>' }
        'id=r4$' { return [xml]'<opml><body><outline type="link" text="District" guide_id="r5" URL="http://opml.radiotime.com/Browse.ashx?id=r5"/><outline type="link" text="Cycle" guide_id="r1" URL="http://opml.radiotime.com/Browse.ashx?id=r1"/></body></opml>' }
        'id=r5$' { return [xml]'<opml><body><outline type="audio" text="Station" guide_id="s1"/></body></opml>' }
        default { throw "Unexpected request $url" }
    }
}
$all = Get-Locations
Assert ($all.Count -eq 5 -and $script:requests -eq 6 -and $all['r5'].Level -eq 5) 'Complete traversal must include nested and deeper links, deduplicate cycles, and browse leaves.'
function Get-Opml([string]$url) {
    return [xml]'<opml><body><outline type="link" text="Unsafe" guide_id="r1" URL="http://example.com/Browse.ashx?id=r1"/></body></opml>'
}
$failed = $false
try { $null = Get-Locations } catch { $failed = $_.Exception.Message -like '*Noncanonical*' }
Assert $failed 'Complete traversal must reject mismatched provider links.'
function Get-Opml([string]$url) {
    return [xml]'<opml><body><outline type="link" text="More locations" URL="http://opml.radiotime.com/Browse.ashx?id=r0&amp;offset=10" key="nextLocations"/></body></opml>'
}
$failed = $false
try { $null = Get-Locations } catch { $failed = $_.Exception.Message -like '*pagination*' }
Assert $failed 'Complete traversal must fail on unsupported location pagination.'

$polygon = [pscustomobject]@{ type='Polygon'; coordinates=@(, @(@(0,0), @(2,0), @(2,1), @(0,0))) }
$rings = Get-MapRings $polygon
Assert ($rings.Count -eq 1 -and $rings[0].Count -eq 8) 'Single polygon ring was flattened.'
$highLatitude = [pscustomobject]@{ type='Polygon'; coordinates=@(, @(@(-5,50), @(5,50), @(5,60), @(-5,60), @(-5,50))) }
$projected = Get-MapRings $highLatitude
$marker = Get-MapPoint $highLatitude -5 60
$aspect = [Math]::Abs(($projected[0][2] - $projected[0][0]) / ($projected[0][5] - $projected[0][1]))
Assert ([Math]::Abs($aspect - [Math]::Cos(55 * [Math]::PI / 180)) -lt 0.0001) 'Projection must correct longitude aspect at the map latitude.'
Assert ([Math]::Abs($marker[0] - $projected[0][6]) -lt 0.001 -and [Math]::Abs($marker[1] - $projected[0][7]) -lt 0.001) 'Markers must use the same projection as map rings.'
$wrapped = [pscustomobject]@{ type='Polygon'; coordinates=@(, @(@(-179,0), @(179,0), @(179,1), @(-179,0))) }
$projection = Get-MapProjection $wrapped
$wrappedRings = Get-MapRings $wrapped
Assert ($projection.Wrapped -and ($projection.XMax-$projection.XMin) -eq 2 -and $wrappedRings.Count -eq 1) 'Antimeridian geometry must retain its verified shape in a continuous longitude interval.'
$marker = Get-MapPoint $wrapped -179 0
Assert ([Math]::Abs($marker[0]-$wrappedRings[0][0]) -lt .001) 'Wrapped map markers must use the same longitude interval as the map.'
$box = [pscustomobject]@{ type='Polygon'; coordinates=@(, @(@(0,0), @(10,0), @(10,10), @(0,10), @(0,0))) }
Assert (Test-MapContainsPoint $box 5 5) 'A point inside a map must be accepted.'
Assert (-not (Test-MapContainsPoint $box 11 5)) 'A point outside a map must be rejected.'
$hole = [pscustomobject]@{ type='Polygon'; coordinates=@(
    @(@(0,0), @(10,0), @(10,10), @(0,10), @(0,0)),
    @(@(4,4), @(6,4), @(6,6), @(4,6), @(4,4))
) }
Assert (-not (Test-MapContainsPoint $hole 5 5)) 'A point inside a polygon hole must not be marked.'
$dateline = [pscustomobject]@{ type='Polygon'; coordinates=@(, @(@(179,-2), @(-179,-2), @(-179,2), @(179,2), @(179,-2))) }
Assert ((Test-MapContainsPoint $dateline -179.5 0) -and -not (Test-MapContainsPoint $dateline 0 0)) 'Containment must follow the wrapped map, not the opposite hemisphere.'
$parent = @{ Id='r2'; Name='Example'; Country='Example'; Level=2; MapGeometry=$box }
$city = @{ Id='r3'; Name='Springfield'; Country='Example'; ParentId='r2' }
$place = [pscustomobject]@{ name='Springfield'; country='Example'; region='Other'; lon=5; lat=5 }
Assert ((Get-PopulatedPlacePoint $city $parent 'Example' @($place)).Count -eq 2) 'A unique direct city within the country map must be marked.'
Assert (-not (Get-PopulatedPlacePoint $city $parent 'Example' @($place,$place))) 'Ambiguous place names must not receive a marker.'
$place.region = 'Springfield'
Assert (-not (Get-PopulatedPlacePoint $city $parent 'Example' @($place))) 'A city name matching an admin-1 name must not be assumed to identify the city.'
$otherPlace = [pscustomobject]@{ name='Springfield'; country='Example'; region='Other'; lon=5; lat=5 }
Assert (-not (Get-PopulatedPlacePoint $city $parent 'Example' @($place,$otherPlace))) 'Excluding an admin-1 namesake must not make an otherwise ambiguous country match appear unique.'
$place.region = 'Other'; $place.lon = 11
Assert (-not (Get-PopulatedPlacePoint $city $parent 'Example' @($place))) 'A place outside the mapped geometry must not be marked.'
$place.lon = 5; $city.ParentId = 'r4'
Assert (-not (Get-PopulatedPlacePoint $city $parent 'Example' @($place))) 'A place must not use a more distant ancestor map for automatic matching.'
$stateParent = @{ Id='r100447'; Name='Alberta'; Country='Canada'; Level=3; MapGeometry=$box }
$stateCity = @{ Id='r9'; Name='Springfield'; Country='Canada'; ParentId='r100447' }
$albertaPlace = [pscustomobject]@{ name='Springfield'; country='Canada'; region='Alberta'; lon=5; lat=5 }
$otherRegion = [pscustomobject]@{ name='Springfield'; country='Canada'; region='Ontario'; lon=5; lat=5 }
Assert ((Get-PopulatedPlacePoint $stateCity $stateParent 'Canada' @($albertaPlace,$otherRegion)).Count -eq 2) 'A verified region must disambiguate same-name cities in different regions.'
$stateParent.Id = 'r123'
$stateCity.ParentId = 'r123'
Assert (-not (Get-PopulatedPlacePoint $stateCity $stateParent 'Canada' @($albertaPlace))) 'An unverified region ID must not authorize a marker.'

. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Scoped-Artwork-Styles.ps1')
foreach ($flag in 'Japan','Netherlands','Iceland','Ireland','South Korea') {
    $layout = Get-ScopedFlagLayout $flag 'Cartoon'
    $poleTop = $layout.CenterY - $layout.Height / 2 - 42 - 14
    $flagBottom = $layout.CenterY + $layout.Height / 2 + 26
    Assert ($poleTop -gt 15 -and $flagBottom -lt 500) "Cartoon $flag flag and pole must clear the inset frame and title area."
}
$dutchScene = Get-ScopedScene 'Classic' @{ Id='l101'; Name='Nederlands'; ProviderName='Dutch' }
Assert ($dutchScene.SourceId -eq 'l101' -and -not $dutchScene.Inherited) 'Dutch must select its own language scenery.'
$netherlandsScene = Get-ScopedScene 'Cartoon' @{ Id='r100385'; Name='Netherlands'; Country='Netherlands' }
Assert ($netherlandsScene.SourceId -eq 'r100385' -and $netherlandsScene.Title -eq 'Nederland') 'Netherlands must select its country scenery and native title.'
$cityScene = Get-ScopedScene 'Futuristic' @{ Id='r123'; Name='Amsterdam'; Country='Netherlands' }
Assert ($cityScene.SourceId -eq 'r100385' -and $cityScene.Inherited -and -not $cityScene.Title) 'A city may inherit contextual country scenery, but not the country title.'
foreach ($theme in 'Cartoon','Futuristic','Classic') {
    $generic = Get-ScopedScene $theme @{ Id='r999'; Name='Unknown city'; Country='United States' }
    Assert ($generic.SourceId -eq 'generic-landscape' -and $generic.Generic -and (Test-Path -LiteralPath $generic.Path)) "$theme must replace the Seattle-like shared scene with a generic landscape."
    $seattle = Get-ScopedScene $theme @{ Id='r100014'; Name='Seattle-Tacoma'; Country='United States' }
    Assert ($seattle.SourceId -eq 'r100014' -and -not $seattle.Generic) "$theme must retain Seattle's dedicated scene."
    $failed = $false
    try { Assert-ScopedSceneCoverage @(@{ Id='r999'; Name='Unknown city'; Country='United States' }) $theme }
    catch { $failed = $_.Exception.Message -like '*missing for 1 of 1*' }
    Assert $failed 'Strict scenery coverage must not count the generic landscape as regional scenery.'
}
Assert (-not (Get-ScopedScene 'Classic' @{ Id='r100385'; Name='Unrelated'; Country=$null })) 'A reused ID with a mismatched subject must not select curated scenery.'
Assert (-not (Get-ScopedScene 'Classic' @{ Id='l123'; Name='Dutch'; ProviderName='Unrelated' })) 'Language scenery must match the provider label, not the displayed title.'
Assert-ScopedSceneCoverage @(@{ Id='l101'; Name='Nederlands'; ProviderName='Dutch' }) 'Classic'
$failed = $false
try {
    Assert-ScopedSceneCoverage @(
        @{ Id='l101'; Name='Nederlands'; ProviderName='Dutch' },
        @{ Id='l1'; Name='Unmapped fixture'; ProviderName='Unmapped fixture' }
    ) 'Classic'
} catch { $failed = $_.Exception.Message -like '*missing for 1 of 2*' -and $_.Exception.Message -like '*l1 (Unmapped fixture)*' }
Assert $failed 'Strict scenery coverage must fail with missing IDs instead of approving a generic fallback.'
$script:ScopedSubjects['l999'] = [pscustomobject]@{ subject='Missing asset' }
$failed = $false
try { Assert-ScopedSceneCoverage @(@{ Id='l999'; Name='Missing asset' }) 'Classic' }
catch { $failed = $_.Exception.Message -like '*missing for 1 of 1*' -and $_.Exception.Message -like '*l999*' }
Assert $failed 'A registry entry without its theme PNG must fail strict coverage.'
$script:ScopedSubjects.Remove('l999')
Add-Type -AssemblyName System.Drawing
$title=New-Object Drawing.Drawing2D.GraphicsPath
try {
    $title.AddRectangle((New-Object Drawing.RectangleF 40,200,1000,300))
    Fit-ScopedTitle $title 560 110
    $bounds=$title.GetBounds()
    Assert ($bounds.Width -le 560.01 -and $bounds.Height -le 110.01 -and [Math]::Abs($bounds.X+$bounds.Width/2-540) -lt .01) 'Oversized scoped titles must fit their band without moving the text center.'
} finally {$title.Dispose()}
# Load the real drawing helpers without running the catalog build.
$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path (Split-Path $PSScriptRoot -Parent) 'Build-GenreArtwork.ps1'),[ref]$tokens,[ref]$parseErrors)
foreach($definition in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in 'Rgb','Argb','Br','P','Pts','L','E','FE'},$false)) {
    Invoke-Expression $definition.Extent.Text
}
$motif=New-Object Drawing.Bitmap 720,500
$paint=[Drawing.Graphics]::FromImage($motif)
try {
    Scoped-Motif $paint @{Motif='neutral';ProviderName='Arabic'} 'Classic' 360 245
    $pixel=$motif.GetPixel(360,245)
    Assert ($pixel.R -eq 236 -and $pixel.G -eq 203 -and $pixel.B -eq 136) 'Neutral languages must draw speech lines, not a location pin.'
} finally {$paint.Dispose();$motif.Dispose()}
foreach ($theme in 'Cartoon','Futuristic','Classic') {
    $motif=New-Object Drawing.Bitmap 720,500
    $paint=[Drawing.Graphics]::FromImage($motif)
    try {
        Scoped-Motif $paint @{ Motif='map'; MapRings=@([float[]]@(-100,-100,100,-100,100,100,-100,100)); MapPoint=@(40,20); Seed=1 } $theme 360 245
        $scale = if ($theme -eq 'Cartoon') { 1.3 } else { 1 }
        $pixel=$motif.GetPixel([int](360+40*$scale+5),[int](245+20*$scale))
        Assert ($pixel.R -eq 208 -and $pixel.G -eq 32 -and $pixel.B -eq 45) "$theme must render the marker at the projected position."
    } finally { $paint.Dispose(); $motif.Dispose() }
}
$profiles = Get-ScopedProfiles
foreach ($language in $profiles.languages.PSObject.Properties) {
    $scene = Get-ScopedScene 'Cartoon' @{Id='l998';Name=$language.Name;ProviderName=$language.Name}
    Assert (Test-Path -LiteralPath $scene.Path) "Missing regional language scenery: $($language.Name)"
    if ($language.Value.code) {
        $image = Get-ScopedFlagImage $language.Value.code
        foreach ($theme in 'Cartoon','Futuristic','Classic') {
            $layout = Get-ScopedFlagLayout $language.Value.flag $theme $language.Value.code
            Assert ([Math]::Abs($layout.Height/[double]$layout.Width - $image.Height/[double]$image.Width) -lt .01) "Flag proportions changed for $($language.Name)"
            $bottom = if ($theme -eq 'Classic') { 690 } else { 510 }
            $top = if ($theme -eq 'Futuristic') { 35 } else { 56 }
            Assert ($layout.CenterY-$layout.Height/2-$top -gt 15 -and $layout.CenterY+$layout.Height/2+40 -lt $bottom) "Flag clips frame/title for $($language.Name) in $theme"
        }
    }
}
$sharedScene = Get-ScopedScene 'Futuristic' @{Id='r999';Name='Paris';Country='France'}
Assert ($sharedScene.SourceId -eq $profiles.countries.France -and $sharedScene.Inherited -and -not $sharedScene.Title) 'Country profile scenery must preserve individual location titles.'
$canvas = New-Object Drawing.Bitmap 1280, 720
$graphics = [Drawing.Graphics]::FromImage($canvas)
try {
    Scoped-Scenery $graphics 'Classic' @{ Id='l1'; Name='English'; Seed=0 }
    $classicScene = Join-Path (Split-Path $PSScriptRoot -Parent) 'data\scenes\classic.png'
    Assert ($script:ScopedScenes.ContainsKey($classicScene)) 'Legacy builds must retain the generic Classic background when strict scenery is not requested.'
    Scoped-Scenery $graphics 'Classic' @{ Id='r101255'; Name='Japan'; Seed=0 }
    $japanScene = Join-Path (Split-Path $PSScriptRoot -Parent) 'data\scoped-scenes\Classic\r101255.png'
    Assert ($script:ScopedScenes.ContainsKey($japanScene)) 'Curated scoped scenery must override the generic background.'
    foreach ($theme in 'Cartoon','Futuristic','Classic') {
        Scoped-Scenery $graphics $theme @{ Id='r999'; Name='Unmapped'; Seed=0 }
        $path = Get-GenericLocationScenePath $theme
        Assert ($script:ScopedScenes.ContainsKey($path)) "$theme must draw a generic landscape for an unmapped location."
    }
} finally {
    $graphics.Dispose()
    $canvas.Dispose()
    foreach ($scene in $script:ScopedScenes.Values) { $scene.Dispose() }
    foreach ($flag in $script:ScopedFlags.Values) { $flag.Dispose() }
}
Write-Host 'Scoped artwork tests passed.'
