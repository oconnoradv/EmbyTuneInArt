param([Parameter(Mandatory=$true)][string]$Output)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'Build-GenreArtwork.ps1'
. (Join-Path $root 'Artwork-PackValidation.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Invoke-WebRequest {
    param([string]$Uri, [switch]$UseBasicParsing, [int]$TimeoutSec)
    $body = if ($Uri -like '*c=music') {
        '<outline type="link" text="Decades Music" guide_id="c481372"/>'
    } elseif ($Uri -like '*id=c481372') {
        @'
<outline text="Stations"><outline type="audio" text="Station" guide_id="s1"/><outline type="audio" text="Not a category link" guide_id="c999"/></outline>
<outline text="Explore Decades Music" key="related">
  <outline type="link" text="00's" guide_id="c100000165"/>
  <outline type="link" text="50's" guide_id="c100000955"/>
  <outline type="link" text="90's" guide_id="c100000946"/>
  <outline type="link" text="80's" guide_id="c100000781"/>
  <outline type="link" text="70s" guide_id="c100000783"/>
  <outline type="link" text="60's" guide_id="c100000633"/>
  <outline type="link" text="Duplicate" guide_id="c100000781"/>
  <outline type="link" text="Invalid" guide_id="c0"/>
  <outline type="link" text="Legacy genre" guide_id="g42"/>
</outline>
'@
    } else { throw "Unexpected catalog request: $Uri" }
    $xml = "<opml><head><status>200</status></head><body>$body</body></opml>"
    return @{ RawContentStream = New-Object IO.MemoryStream(,[Text.Encoding]::UTF8.GetBytes($xml)) }
}

$folder = Join-Path $Output 'decades'
& $build -Scope genres -Theme Tile -Output $folder -Pack
$manifestPath = Join-Path $folder 'tunein-artwork.json'
$manifest = Assert-ArtworkPack $folder $manifestPath
$expected = @('c481372','c100000165','c100000955','c100000946','c100000781','c100000783','c100000633','g42')
Assert ($manifest.imageCount -eq $expected.Count) 'Genre pack must include each valid category and genre exactly once.'
foreach ($id in $expected) {
    Assert (@($manifest.images | Where-Object { $_.id -ceq $id -and $_.file -ceq "$id.jpg" }).Count -eq 1) "Missing manifest entry for $id."
}
$zip = Join-Path $Output 'artpack-tile-genres.zip'
Assert-ArtworkArchive $zip $manifest $manifestPath
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    foreach ($id in $expected) { Assert ($null -ne $archive.GetEntry("$id.jpg")) "Missing ZIP image for $id." }
} finally { $archive.Dispose() }

$only = Join-Path $Output 'only'
& $build -Scope genres -Theme Tile -Only "80's" -Output $only
$filtered = Assert-ArtworkPack $only (Join-Path $only 'tunein-artwork.json')
Assert ($filtered.imageCount -eq 1 -and $filtered.images[0].id -ceq 'c100000781') 'Name filtering must select the category ID, preserving its original label.'
Write-Host 'Genre decade tests passed.'
