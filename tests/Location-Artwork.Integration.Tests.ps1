param([Parameter(Mandatory=$true)][string]$Output)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'Build-GenreArtwork.ps1'
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
$snapshot = Join-Path $Output 'snapshot'
New-Item -ItemType Directory -Force $snapshot | Out-Null
$responses = @{
    r0='<outline type="link" text="North America" guide_id="r101218"/><outline type="link" text="Europe" guide_id="r101217"/>'
    r101218='<outline type="link" text="United States" guide_id="r101222"/><outline type="link" text="Canada" guide_id="r101227"/>'
    r101222='<outline type="link" text="Washington" guide_id="r100516"/>'
    r101227='<outline type="link" text="Alberta" guide_id="r100447"/>'
    r100516='<outline type="link" text="Seattle-Tacoma" guide_id="r100014"/><outline type="link" text="Spokane" guide_id="r100092"/><outline type="link" text="Unknown city" guide_id="r9999999"/>'
    r100447='<outline type="link" text="Calgary" guide_id="r100598"/><outline type="link" text="Edmonton" guide_id="r100594"/>'
    r101217='<outline type="link" text="Netherlands" guide_id="r100385"/>'
    r100385='<outline type="link" text="Amsterdam" guide_id="r101398"/>'
    r101398=''
}
foreach ($id in $responses.Keys) {
    [IO.File]::WriteAllText((Join-Path $snapshot "$id.xml"), "<opml><head><status>200</status></head><body>$($responses[$id])</body></opml>", (New-Object Text.UTF8Encoding $false))
}
. (Join-Path $root 'Scoped-Artwork.ps1')
Add-Type -AssemblyName System.Drawing
$baseTheme = 'Cartoon'
$maps = [ordered]@{
    r100516=@{ Id='r100516'; Name='Washington'; Country='United States'; Level=3 }
    r100014=@{ Id='r100014'; Name='Seattle-Tacoma'; Country='United States'; Level=4; ParentId='r100516' }
    r100092=@{ Id='r100092'; Name='Spokane'; Country='United States'; Level=4; ParentId='r100516' }
    r100447=@{ Id='r100447'; Name='Alberta'; Country='Canada'; Level=3 }
    r100598=@{ Id='r100598'; Name='Calgary'; Country='Canada'; Level=4; ParentId='r100447' }
    r100594=@{ Id='r100594'; Name='Edmonton'; Country='Canada'; Level=4; ParentId='r100447' }
    r100385=@{ Id='r100385'; Name='Netherlands'; Country='Netherlands'; Level=2 }
    r101398=@{ Id='r101398'; Name='Amsterdam'; Country='Netherlands'; Level=3; ParentId='r100385' }
}
Set-LocationArt $maps
foreach ($theme in 'Cartoon','Futuristic','Classic') {
    $folder = Join-Path $Output $theme
    & $build -Scope locations -Theme $theme -CatalogSnapshot $snapshot -Output $folder -Only 'r100014','r100092','r9999999','r100598','r100594','r101398'
    $manifest = Get-Content -LiteralPath (Join-Path $folder 'tunein-artwork.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($manifest.imageCount -eq 6) "$theme must generate all selected locations."
    $unknown = @($manifest.images | Where-Object id -eq 'r9999999')[0]
    Assert ($unknown.scenerySource -ceq 'generic-landscape' -and $unknown.motifLabel -ceq 'Regional map') "$theme must record generic scenery and the correct map coverage."
    foreach ($id in 'r100014','r100092','r100598','r100594','r101398') {
        $image = [Drawing.Bitmap]::FromFile((Join-Path $folder "$id.jpg"))
        try {
            $cx = if ($theme -eq 'Classic') { 320 } elseif ($theme -eq 'Cartoon') { 360 } else { 640 }
            $cy = if ($theme -eq 'Classic') { 300 } elseif ($theme -eq 'Cartoon') { 310 } else { 240 }
            $scale = if ($theme -eq 'Cartoon') { 1.3 } else { 1 }
            $x = [int]($cx + $maps[$id].MapPoint[0] * $scale + 5)
            $y = [int]($cy + $maps[$id].MapPoint[1] * $scale)
            $pixel = $image.GetPixel($x, $y)
            Assert ($pixel.R -gt 140 -and $pixel.R -gt 2*$pixel.G -and $pixel.R -gt 2*$pixel.B) "$theme output must render $id at its projected coordinates."
        } finally { $image.Dispose() }
    }
    $image = [Drawing.Bitmap]::FromFile((Join-Path $folder 'r9999999.jpg'))
    try {
        $cx = if ($theme -eq 'Classic') { 320 } elseif ($theme -eq 'Cartoon') { 360 } else { 640 }
        $cy = if ($theme -eq 'Classic') { 300 } elseif ($theme -eq 'Cartoon') { 310 } else { 240 }
        $scale = if ($theme -eq 'Cartoon') { 1.3 } else { 1 }
        $pixel = $image.GetPixel([int]($cx + $maps['r100014'].MapPoint[0] * $scale + 5), [int]($cy + $maps['r100014'].MapPoint[1] * $scale))
        Assert (-not ($pixel.R -gt 140 -and $pixel.R -gt 2*$pixel.G -and $pixel.R -gt 2*$pixel.B)) "$theme must not reuse Seattle's marker for an unknown city."
    } finally { $image.Dispose() }
    $strictFolder = Join-Path $Output "$theme-strict"
    $failed = $false
    try { & $build -Scope locations -Theme $theme -CatalogSnapshot $snapshot -Output $strictFolder -Only 'r9999999' -RequireScopedScenery }
    catch { $failed = $_.Exception.Message -like '*missing for 1 of 1*' }
    Assert ($failed -and -not (Test-Path -LiteralPath $strictFolder)) "$theme strict build must reject generic scenery before writing."
}
$folder = Join-Path $Output 'Neon'
& $build -Scope locations -Theme Neon -CatalogSnapshot $snapshot -Output $folder -Only 'r100598'
$image = [Drawing.Bitmap]::FromFile((Join-Path $folder 'r100598.jpg'))
try {
    $point = $maps['r100598'].MapPoint
    $pixel = $image.GetPixel([int](1000+$point[0]+5), [int](360+$point[1]))
    Assert ($pixel.R -gt 140 -and $pixel.R -gt 2*$pixel.G -and $pixel.R -gt 2*$pixel.B) 'Non-scoped map styles must render verified markers too.'
} finally { $image.Dispose() }
Write-Host 'Location artwork integration tests passed.'
