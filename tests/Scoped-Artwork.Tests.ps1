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

$NeutralLanguages = $false
$languages = Get-Languages
Assert ($languages.Count -eq 2) 'Language filter IDs or station exclusion failed.'
Assert ($languages['l122'].RTL -and $languages['l122'].Name -eq [Globalization.CultureInfo]::GetCultureInfo('ar').NativeName) 'Arabic native title or RTL failed.'
Assert ($languages['l178'].Flag -eq 'Japan') 'Representative flag mapping failed.'
$NeutralLanguages = $true
Assert ((Get-Languages)['l178'].Motif -eq 'neutral') 'Neutral language option failed.'

$LocationRoot = 'r0'; $LocationRootLevel = 0; $LocationDepth = 4
$MaxLocationRequests = 10; $script:requests = 0; $Only = $null
$locations = Get-Locations
Assert ($locations.Count -eq 4 -and $script:requests -eq 4) 'Location depth, cycles, or station exclusion failed.'
Assert ($locations['r100598'].Parent -eq 'Alberta' -and $locations['r100598'].Country -eq 'Canada') 'Location ancestry failed.'
Set-LocationArt $locations
Assert ($locations['r101227'].Motif -eq 'map' -and $locations['r100447'].Motif -eq 'map') 'Country/region geometry failed.'
Assert ($locations['r100598'].Motif -eq 'neutral' -and $locations['r100598'].Label -eq 'Generic location') 'City fallback was not explicit.'
$unknown = [ordered]@{ r123=@{ Id='r123'; Name='Alberta'; Country='Canada'; Level=3; Parent='Canada' } }
Set-LocationArt $unknown
Assert ($unknown['r123'].Motif -eq 'neutral') 'Unverified region ID must not inherit a namesake map.'
$MaxLocationRequests = 2; $script:requests = 0
$failed = $false
try { $null = Get-Locations } catch { $failed = $_.Exception.Message -like '*exceeded*' }
Assert ($failed -and $script:requests -eq 2) 'Discovery request limit failed.'

$polygon = [pscustomobject]@{ type='Polygon'; coordinates=@(, @(@(0,0), @(2,0), @(2,1), @(0,0))) }
$rings = Get-MapRings $polygon
Assert ($rings.Count -eq 1 -and $rings[0].Count -eq 8) 'Single polygon ring was flattened.'
$wrapped = [pscustomobject]@{ type='Polygon'; coordinates=@(, @(@(-179,0), @(179,0), @(179,1), @(-179,0))) }
Assert (-not (Get-MapRings $wrapped)) 'Antimeridian-spanning geometry must use the generic fallback.'
Write-Host 'Scoped artwork tests passed.'
