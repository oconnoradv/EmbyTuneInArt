param([Parameter(Mandatory=$true)][string]$Output)

$ErrorActionPreference = 'Stop'
$build = Join-Path (Split-Path $PSScriptRoot -Parent) 'Build-GenreArtwork.ps1'
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Invoke-WebRequest {
    param([string]$Uri, [switch]$UseBasicParsing, [int]$TimeoutSec)
    $body = if ($Uri -like '*c=music') {
        '<outline type="link" text="Rock Music" guide_id="c1"/>'
    } elseif ($Uri -like '*id=c1') {
        '<outline type="link" text="Pop Hits" guide_id="g1"/>'
    } else { throw "Unexpected catalog request: $Uri" }
    $xml = "<opml><head><status>200</status></head><body>$body</body></opml>"
    return @{ RawContentStream = New-Object IO.MemoryStream(,[Text.Encoding]::UTF8.GetBytes($xml)) }
}
$default = Join-Path $Output 'default'
& $build -Scope genres -Theme Retro -Only c1 -Pack -Output $default
$manifest = Get-Content -LiteralPath (Join-Path $default 'tunein-artwork.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert (Test-Path -LiteralPath (Join-Path $Output 'artpack-retro-genres.zip')) 'The default genre ZIP must include its scope.'
Assert ($manifest.packId -ceq 'artpack-retro' -and $manifest.scope -ceq 'genres') 'The default genre pack identity must remain compatible.'
$custom = Join-Path $Output 'custom'
& $build -Scope genres -Theme Retro -Only c1 -Pack -PackName 'my-retro' -Output $custom
$manifest = Get-Content -LiteralPath (Join-Path $custom 'tunein-artwork.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ((Test-Path -LiteralPath (Join-Path $Output 'my-retro.zip')) -and $manifest.packId -ceq 'my-retro') 'A custom pack name must continue to control both ZIP and manifest identity.'
Write-Host 'Genre pack naming tests passed.'
