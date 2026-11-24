param([Parameter(Mandatory=$true)][string]$Output)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'Build-GenreArtwork.ps1'
. (Join-Path $root 'Artwork-PackValidation.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Invoke-WebRequest {
    param([string]$Uri, [switch]$UseBasicParsing, [int]$TimeoutSec)
    $body = if ($Uri -like '*c=music') {
        '<outline type="link" text="Rock Music" guide_id="c1"/>'
    } elseif ($Uri -like '*id=c1') {
        '<outline type="link" text="Pop Hits" guide_id="g2698"/>'
    } else { throw "Unexpected catalog request: $Uri" }
    $xml = "<opml><head><status>200</status></head><body>$body</body></opml>"
    return @{ RawContentStream = New-Object IO.MemoryStream(,[Text.Encoding]::UTF8.GetBytes($xml)) }
}
$snapshot = Join-Path $Output 'snapshot'
New-Item -ItemType Directory -Force $snapshot | Out-Null
[IO.File]::WriteAllText((Join-Path $snapshot 'languages.xml'), '<opml><head><status>200</status></head><body><outline type="link" text="Japanese" URL="http://opml.radiotime.com/Browse.ashx?c=lang&amp;filter=l178"/><outline type="link" text="English" URL="http://opml.radiotime.com/Browse.ashx?c=lang&amp;filter=l100"/></body></opml>')
[IO.File]::WriteAllText((Join-Path $snapshot 'r0.xml'), '<opml><head><status>200</status></head><body><outline type="link" text="North America" guide_id="r101218"/></body></opml>')
$themes = @('Neon','Retro','Futuristic','Cartoon','Cat','Dog','Nature','Blocky','Rebel','Imperial','Elegant','Tile','Classic','FuturisticSpotlight','CartoonSpotlight','ClassicSpotlight')
$scopes = @('genres','languages','locations','categories')
for ($i = 0; $i -lt $themes.Count; $i++) {
    $scope = $scopes[$i % $scopes.Count]; $theme = $themes[$i]
    $folder = Join-Path $Output "matrix-$scope-$theme"
    $options = switch ($scope) {
        'genres' { @{ Only = @('g2698') } }
        'languages' { @{ Only = @('l178'); CatalogSnapshot = $snapshot } }
        'locations' { @{ Only = @('r101218'); CatalogSnapshot = $snapshot; LocationDepth = 1 } }
        'categories' { @{ Only = @('music') } }
    }
    & $build -Scope $scope -Theme $theme -Output $folder -Pack @options
    $manifestPath = Join-Path $folder 'tunein-artwork.json'
    $manifest = Assert-ArtworkPack $folder $manifestPath
    Assert ($manifest.scope -ceq $scope -and $manifest.imageCount -eq 1) "Invalid partial $scope/$theme pack."
    $entry = $manifest.images[0]
    Assert ($entry.file -ceq "$($entry.id).jpg" -and $entry.sha256 -ceq (Get-FileHash (Join-Path $folder $entry.file)).Hash.ToLowerInvariant()) "Incorrect generated identity or hash for $scope/$theme."
    $zipName = "artpack-$($theme.ToLowerInvariant())-$scope.zip"
    $zip = Join-Path $Output $zipName
    Assert-ArtworkArchive $zip $manifest $manifestPath
    if ($scope -eq 'genres') { Assert ($manifest.packId -ceq "artpack-$($theme.ToLowerInvariant())" -and $manifest.version -ceq '1') 'Default genre identity changed.' }
}

foreach ($theme in 'FuturisticSpotlight','CartoonSpotlight','ClassicSpotlight') {
    $folder = Join-Path $Output "genre-$theme"
    & $build -Scope genres -Theme $theme -Only g2698 -Output $folder -Pack
    Assert ((Get-FileHash (Join-Path $folder 'g2698.jpg')).Hash -ceq (Get-FileHash (Join-Path $root "spotlight\$theme\g2698.jpg")).Hash) "$theme Spotlight source changed."
}
$category = Join-Path $Output 'category-custom'
& $build -Scope categories -Theme Retro -Only music -Output $category -Pack -PackName 'custom-category' -PackVersion '2.3'
$categoryManifest = Assert-ArtworkPack $category (Join-Path $category 'tunein-artwork.json')
Assert ((Test-Path -LiteralPath (Join-Path $Output 'custom-category.zip')) -and $categoryManifest.packName -ceq 'Retro' -and
    $null -eq $categoryManifest.PSObject.Properties['packId'] -and $null -eq $categoryManifest.PSObject.Properties['version']) 'Category custom options changed manifest identity.'
& $build -Scope categories -Theme Neon -Only talk -Output $category -Pack -PackName 'custom-category'
$replacement = Assert-ArtworkPack $category (Join-Path $category 'tunein-artwork.json')
Assert-ArtworkArchive (Join-Path $Output 'custom-category.zip') $replacement (Join-Path $category 'tunein-artwork.json')
Assert ($replacement.images[0].id -ceq 'talk') 'Existing ZIP was not replaced by the validated pack.'

$language = Join-Path $Output 'language-flag'
& $build -Scope languages -Theme Cartoon -Only l100 -CatalogSnapshot $snapshot -Output $language -Pack -PackName 'custom-language' -PackVersion '2.3'
$manifestPath = Join-Path $language 'tunein-artwork.json'
$manifest = Assert-ArtworkPack $language $manifestPath
Assert ($manifest.packId -ceq 'custom-language' -and $manifest.version -ceq '2.3') 'Custom identity/version changed.'
Assert ($manifest.images[0].representativeFlag -ceq 'United Kingdom' -and $manifest.images[0].flagAsset -ceq 'gb.png') 'Representative flag metadata missing.'
$zip = Join-Path $Output 'custom-language.zip'
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    Assert ($null -ne $archive.GetEntry('FLAGS-SOURCES.txt') -and $null -ne $archive.GetEntry('flag-sources.json')) 'Flag provenance missing.'
    Assert ($null -eq $archive.GetEntry('gb.png')) 'flagAsset must not be an archive reference.'
} finally { $archive.Dispose() }
$neutral = Join-Path $Output 'language-neutral'
& $build -Scope languages -Theme CartoonSpotlight -Only l100 -CatalogSnapshot $snapshot -Output $neutral -NeutralLanguages -Pack
$neutralManifest = Assert-ArtworkPack $neutral (Join-Path $neutral 'tunein-artwork.json')
Assert ($null -eq $neutralManifest.images[0].PSObject.Properties['representativeFlag'] -and $null -eq $neutralManifest.images[0].PSObject.Properties['flagAsset']) 'Neutral language must not assign a flag.'
foreach ($scope in 'languages','locations') {
    $base = Join-Path $Output "$scope-base"
    $spot = Join-Path $Output "$scope-spot"
    $options = if ($scope -eq 'languages') { @{ Only = @('l100'); CatalogSnapshot = $snapshot } }
        else { @{ Only = @('r101218'); CatalogSnapshot = $snapshot; LocationDepth = 1 } }
    & $build -Scope $scope -Theme Futuristic -Output $base @options
    & $build -Scope $scope -Theme FuturisticSpotlight -Output $spot @options
    $baseManifest = Assert-ArtworkPack $base (Join-Path $base 'tunein-artwork.json')
    $spotManifest = Assert-ArtworkPack $spot (Join-Path $spot 'tunein-artwork.json')
    Assert ($baseManifest.images[0].sha256 -ceq $spotManifest.images[0].sha256) "$scope Spotlight must use the base theme."
}

$original = [IO.File]::ReadAllText($manifestPath)
foreach ($change in @(
    { param($m) $m.images[0].sha256 = '0' * 64 },
    { param($m) $m.images[0].id = 'L100' },
    { param($m) $m.images[0].sceneryShared = 'true' },
    { param($m) $m.images[0].bytes = '1' },
    { param($m) $m.packName = ' www.invalid' },
    { param($m) $m.images[0] | Add-Member -NotePropertyName extra -NotePropertyValue 'bad' },
    { param($m) $m.imageCount = 2 }
)) {
    $m = $original | ConvertFrom-Json
    & $change $m
    [IO.File]::WriteAllText($manifestPath, ($m | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
    $failed = $false
    try { $null = Assert-ArtworkPack $language $manifestPath } catch { $failed = $true }
    Assert $failed 'Invalid manifest was accepted.'
}
[IO.File]::WriteAllText($manifestPath, $original, (New-Object Text.UTF8Encoding $false))
$manifest = Assert-ArtworkPack $language $manifestPath
$archive = [IO.Compression.ZipFile]::Open($zip, 'Update')
try { $null = $archive.CreateEntry('unexpected.txt') } finally { $archive.Dispose() }
$failed = $false
try { Assert-ArtworkArchive $zip $manifest $manifestPath } catch { $failed = $true }
Assert $failed 'Unexpected ZIP entry was accepted.'
$failed = $false
try { & $build -Scope categories -Only music -Output (Join-Path $Output 'invalid-name') -Pack -PackName '..\escape' } catch { $failed = $_.Exception.Message -like '*valid ZIP file name*' }
Assert $failed 'Unsafe ZIP name was accepted.'
Write-Host 'Artwork pack contract tests passed.'
