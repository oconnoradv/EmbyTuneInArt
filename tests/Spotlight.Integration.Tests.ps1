param([Parameter(Mandatory=$true)][string]$Output)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'Build-GenreArtwork.ps1'
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Hash([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
function Manifest([string]$path) { Get-Content (Join-Path $path 'tunein-artwork.json') -Raw -Encoding UTF8 | ConvertFrom-Json }

$genre = Join-Path $Output 'genre-spotlight'
$base = Join-Path $Output 'genre-base'
& $build -Scope genres -Theme CartoonSpotlight -Only 'g2698','c57944' -Output $genre -Pack
& $build -Scope genres -Theme Cartoon -Only 'c57944' -Output $base
$manifest = Manifest $genre
Assert ($manifest.scope -eq 'genres' -and $manifest.imageCount -eq 2) 'Genre Spotlight manifest is incorrect.'
Assert ((Hash (Join-Path $genre 'g2698.jpg')) -eq (Hash (Join-Path $root 'spotlight\CartoonSpotlight\g2698.jpg'))) 'Spotlight image was not copied.'
Assert ((Hash (Join-Path $genre 'c57944.jpg')) -eq (Hash (Join-Path $base 'c57944.jpg'))) 'Non-Spotlight genre differs from base theme.'
foreach ($theme in 'FuturisticSpotlight','ClassicSpotlight') {
    $folder = Join-Path $Output $theme
    & $build -Scope genres -Theme $theme -Only 'g2698' -Output $folder
    Assert ((Hash (Join-Path $folder 'g2698.jpg')) -eq (Hash (Join-Path $root "spotlight\$theme\g2698.jpg"))) "$theme image was not copied."
    $m = Manifest $folder
    Assert ($m.scope -eq 'genres' -and $m.imageCount -eq 1 -and $m.theme -eq $theme) "Invalid $theme manifest."
}

foreach ($scope in 'languages','locations') {
    $spot = Join-Path $Output "$scope-spotlight"
    $normal = Join-Path $Output "$scope-base"
    $options = if ($scope -eq 'languages') { @{ Only=@('l178') } } else {
        @{ LocationRoot='r101227'; LocationRootLevel=2; LocationDepth=2; Only=@('r101227') }
    }
    & $build -Scope $scope -Theme FuturisticSpotlight -Output $spot @options
    & $build -Scope $scope -Theme Futuristic -Output $normal @options
    $m = Manifest $spot
    Assert ($m.scope -eq $scope -and $m.imageCount -eq 1) "Invalid $scope Spotlight manifest."
    $id = $m.images[0].id
    Assert ((Hash (Join-Path $spot "$id.jpg")) -eq (Hash (Join-Path $normal "$id.jpg"))) "$scope Spotlight differs from its base theme."
    Assert ((Hash (Join-Path $spot "$id.jpg")).ToLowerInvariant() -eq $m.images[0].sha256) "$scope manifest hash is incorrect."
}
Write-Host 'Spotlight and scoped integration tests passed.'
