param([Parameter(Mandatory=$true)][string]$Output)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'Build-GenreArtwork.ps1'
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Hash([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }

$expected = [ordered]@{
    local='Local Radio'; music='Music'; language='By Language'; location='By Location'
    talk='Talk'; sports='Sports'; podcast='Podcasts'; presets='My Favorites'
}
$folder = Join-Path $Output 'categories'
# A nonexistent snapshot makes any accidental catalog discovery fail.
$buildLog = @(& $build -Scope categories -Theme Futuristic -Output $folder -CatalogSnapshot (Join-Path $Output 'missing-snapshot') -Pack 6>&1)
foreach ($id in $expected.Keys) {
    Assert (@($buildLog | Where-Object { "$_" -like "$id  $($expected[$id])  *" }).Count -eq 1) "Missing or incorrect visible label for $id."
}
$manifestPath = Join-Path $folder 'tunein-artwork.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($manifest.schemaVersion -eq 2 -and $manifest.scope -ceq 'categories' -and $manifest.packName -eq 'Futuristic' -and $manifest.packId -ceq 'artpack-futuristic-categories' -and $manifest.version -ceq '1') 'Invalid category manifest identity.'
Assert ((@($manifest.PSObject.Properties.Name | Sort-Object) -join ',') -ceq 'imageCount,images,packId,packName,schemaVersion,scope,theme,version') 'Category manifest has missing or extra fields.'
Assert ($manifest.imageCount -eq 8 -and @($manifest.images).Count -eq 8) 'Category manifest must contain exactly eight images.'
$seen = @{}
$hashes = @{}
Add-Type -AssemblyName System.Drawing
foreach ($entry in $manifest.images) {
    Assert ($expected.Contains($entry.id) -and -not $seen.ContainsKey($entry.id)) "Unexpected or duplicate category ID: $($entry.id)"
    $seen[$entry.id] = $true
    Assert ((@($entry.PSObject.Properties.Name | Sort-Object) -join ',') -ceq 'file,id,sha256' -and $entry.file -ceq "$($entry.id).jpg") "Invalid fields or filename for $($entry.id)."
    $path = Join-Path $folder $entry.file
    $hash = Hash $path
    Assert ($entry.sha256 -ceq $hash -and -not $hashes.ContainsKey($hash)) "Invalid hash or duplicate image for $($entry.id)."
    $hashes[$hash] = $true
    $image = [Drawing.Image]::FromFile($path)
    try { Assert ($image.Width -eq 1280 -and $image.Height -eq 720 -and $image.RawFormat.Guid -eq [Drawing.Imaging.ImageFormat]::Jpeg.Guid) "Invalid image dimensions or format for $($entry.id)." }
    finally { $image.Dispose() }
}
Assert ($seen.Count -eq $expected.Count) 'A category is missing.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = Join-Path $Output 'artpack-futuristic-categories.zip'
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName })
    Assert ($entries.Count -eq 12 -and ($entries | Select-Object -Unique).Count -eq 12) 'Unexpected ZIP contents.'
    foreach ($name in @('tunein-artwork.json','LICENSE.txt','Noto-OFL.txt','README.txt') + @($manifest.images | ForEach-Object { $_.file })) {
        Assert ($entries -ccontains $name) "ZIP is missing $name."
        $stream = $archive.GetEntry($name).Open()
        try {
            if ($name -eq 'tunein-artwork.json' -or $name -like '*.jpg') {
                $sha = [Security.Cryptography.SHA256]::Create()
                try { $actual = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
                finally { $sha.Dispose() }
                Assert ($actual -ceq (Hash (Join-Path $folder $name))) "ZIP content differs for $name."
            }
        } finally { $stream.Dispose() }
    }
} finally { $archive.Dispose() }

foreach ($theme in 'Neon','Retro','Futuristic','Cartoon','Cat','Dog','Nature','Blocky','Rebel','Imperial','Elegant','Tile','Classic') {
    $themeFolder = Join-Path $Output $theme
    & $build -Scope categories -Theme $theme -Output $themeFolder
    $m = Get-Content -LiteralPath (Join-Path $themeFolder 'tunein-artwork.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($m.imageCount -eq 8 -and @($m.images).Count -eq 8) "$theme category generation failed."
    $themeHashes = @{}
    foreach ($entry in $m.images) {
        $hash = Hash (Join-Path $themeFolder $entry.file)
        Assert ($expected.Contains($entry.id) -and $hash -ceq $entry.sha256 -and -not $themeHashes.ContainsKey($hash)) "$theme category image is invalid: $($entry.id)."
        $themeHashes[$hash] = $true
    }
}
foreach ($theme in 'Futuristic','Cartoon','Classic') {
    $spot = Join-Path $Output "${theme}Spotlight"
    & $build -Scope categories -Theme "${theme}Spotlight" -Output $spot -Pack
    $spotHashes = @{}
    foreach ($id in $expected.Keys) {
        $spotHash = Hash (Join-Path $spot "$id.jpg")
        Assert ($spotHash -cne (Hash (Join-Path (Join-Path $Output $theme) "$id.jpg"))) "$theme Spotlight category duplicates its base theme: $id."
        Assert (-not $spotHashes.ContainsKey($spotHash)) "$theme Spotlight category images are duplicates: $id."
        $spotHashes[$spotHash] = $true
    }
}
$filtered = Join-Path $Output 'filtered'
& $build -Scope categories -Only 'My Fav*' -Output $filtered
$m = Get-Content -LiteralPath (Join-Path $filtered 'tunein-artwork.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($m.imageCount -eq 1 -and $m.images[0].id -ceq 'presets') 'Category label filtering failed.'
$failed = $false
try { & $build -Scope categories -Only 'channel' -Output (Join-Path $Output 'invalid') }
catch { $failed = $_.Exception.Message -like '*No artwork matched*' }
Assert $failed 'Channel must not be a category-pack entry.'
$failed = $false
try { & $build -Scope categories -RequireScopedScenery -Output (Join-Path $Output 'invalid') }
catch { $failed = $_.Exception.Message -like '*only*language/location*' }
Assert $failed 'Category packs must reject language/location scenery validation.'
Write-Host 'Category artwork tests passed.'
