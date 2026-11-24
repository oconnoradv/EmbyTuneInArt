# Validates the generator's output against the TuneIn artwork upload contract.
function Assert-ArtworkProperties($object, [string[]]$allowed) {
    foreach ($property in $object.PSObject.Properties) {
        if ($allowed -cnotcontains $property.Name) { throw "Unknown artwork property: $($property.Name)." }
    }
}

function Assert-ArtworkJpegHeader([string]$path) {
    $stream = [IO.File]::OpenRead($path)
    $reader = New-Object IO.BinaryReader($stream)
    try {
        if ($reader.ReadByte() -ne 0xff -or $reader.ReadByte() -ne 0xd8) { throw "Invalid JPEG header: $path." }
        while ($stream.Position -lt $stream.Length) {
            if ($reader.ReadByte() -ne 0xff) { throw "Invalid JPEG marker: $path." }
            do { $marker = $reader.ReadByte() } while ($marker -eq 0xff)
            if ($marker -in 0xd9,0xda) { break }
            if ($marker -eq 0x01 -or ($marker -ge 0xd0 -and $marker -le 0xd7)) { continue }
            $length = ([int]$reader.ReadByte() * 256) + $reader.ReadByte()
            if ($length -lt 2 -or $stream.Position + $length - 2 -gt $stream.Length) { throw "Invalid JPEG segment: $path." }
            if ($marker -ge 0xc0 -and $marker -le 0xcf -and $marker -notin 0xc4,0xc8,0xcc) {
                if ($marker -notin 0xc0,0xc1,0xc2 -or $length -lt 8) { throw "Unsupported JPEG frame: $path." }
                return
            }
            $stream.Position += $length - 2
        }
        throw "Missing JPEG frame: $path."
    } finally { $reader.Dispose() }
}

function Assert-ArtworkPack($output, $manifestPath) {
    $manifestFile = Get-Item -LiteralPath $manifestPath
    if ($manifestFile.Length -gt 4MB) { throw 'Artwork manifest exceeds 4 MiB.' }
    $manifest = [IO.File]::ReadAllText($manifestPath, (New-Object Text.UTF8Encoding($false, $true))) | ConvertFrom-Json
    Assert-ArtworkProperties $manifest @('schemaVersion','scope','packId','packName','theme','version','description','minPluginVersion','sampleImageUrl','sourceUrl','toolCommit','license','builtUtc','imageCount','images')
    if ($manifest.schemaVersion -isnot [int] -or $manifest.schemaVersion -ne 1) { throw 'Invalid artwork schemaVersion.' }
    if ($manifest.scope -cnotin @('genres','languages','locations','categories')) { throw 'Invalid artwork scope.' }
    if ($manifest.packName -isnot [string] -or [string]::IsNullOrWhiteSpace($manifest.packName) -or
        $manifest.packName -cne $manifest.packName.Trim() -or $manifest.packName.Length -gt 128 -or
        $manifest.packName -match '[\p{Cc}:/\\@]|www\.') { throw 'Invalid artwork packName.' }
    foreach ($field in 'packId','theme','version','description','minPluginVersion','sampleImageUrl','sourceUrl','toolCommit','builtUtc','license') {
        $property = $manifest.PSObject.Properties[$field]
        if ($property -and $null -ne $property.Value -and $property.Value -isnot [string]) { throw "Invalid manifest field: $field." }
    }
    if ($manifest.imageCount -isnot [int] -or $manifest.imageCount -lt 1 -or $manifest.imageCount -gt 20000 -or
        $manifest.images -isnot [array] -or $manifest.imageCount -ne $manifest.images.Count) { throw 'Invalid artwork image count.' }
    $ids = @{}; $files = @{}
    foreach ($entry in $manifest.images) {
        Assert-ArtworkProperties $entry @('id','file','sha256','name','parent','bytes','motif','motifLabel','scenerySource','sceneryShared','representativeFlag','flagAsset')
        if ($entry.id -isnot [string] -or $entry.file -isnot [string] -or $entry.sha256 -isnot [string]) { throw 'Invalid artwork image fields.' }
        $validId = switch ($manifest.scope) {
            'genres' { $entry.id -cmatch '^[cg][1-9][0-9]{0,9}$' }
            'languages' { $entry.id -cmatch '^l[1-9][0-9]{0,9}$' }
            'locations' { $entry.id -cmatch '^r[1-9][0-9]{0,9}$' }
            'categories' { $entry.id -cin @('local','music','language','location','talk','sports','podcast','presets') }
        }
        if (-not $validId -or $entry.file -cne "$($entry.id).jpg" -or $entry.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            $ids.ContainsKey($entry.id) -or $files.ContainsKey($entry.file)) { throw "Invalid or duplicate artwork image: $($entry.id)." }
        $ids[$entry.id] = $true; $files[$entry.file] = $true
        foreach ($field in 'name','parent','motif','motifLabel','scenerySource','representativeFlag','flagAsset') {
            $property = $entry.PSObject.Properties[$field]
            if ($property -and $null -ne $property.Value -and $property.Value -isnot [string]) { throw "Invalid image field: $field." }
        }
        $property = $entry.PSObject.Properties['sceneryShared']
        if ($property -and $property.Value -isnot [bool]) { throw 'Invalid sceneryShared.' }
        $image = Get-Item -LiteralPath (Join-Path $output $entry.file)
        if ($image.Length -le 0 -or $image.Length -gt 16MB) { throw "Invalid artwork image size: $($entry.file)." }
        $property = $entry.PSObject.Properties['bytes']
        if ($property -and (($property.Value -isnot [int] -and $property.Value -isnot [long]) -or $property.Value -ne $image.Length)) { throw "Invalid artwork byte count: $($entry.file)." }
        if ((Get-FileHash -LiteralPath $image.FullName -Algorithm SHA256).Hash -cne $entry.sha256.ToUpperInvariant()) { throw "Artwork hash mismatch: $($entry.file)." }
        Assert-ArtworkJpegHeader $image.FullName
        $decoded = [Drawing.Image]::FromFile($image.FullName)
        try {
            if ($decoded.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Jpeg.Guid -or $decoded.Width -gt 4096 -or
                $decoded.Height -gt 4096 -or ([long]$decoded.Width * $decoded.Height) -gt 16777216) { throw "Invalid artwork image format or dimensions: $($entry.file)." }
        } finally { $decoded.Dispose() }
    }
    return $manifest
}

function Assert-ArtworkArchive($zip, $manifest, $manifestPath) {
    $file = Get-Item -LiteralPath $zip
    if ($file.Length -gt 768MB) { throw 'Artwork archive exceeds 768 MiB.' }
    $expected = @{}; $expectedNames = @{}
    $expected['tunein-artwork.json'] = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
    $expectedNames['tunein-artwork.json'] = 'tunein-artwork.json'
    foreach ($image in $manifest.images) {
        $expected[$image.file] = $image.sha256.ToUpperInvariant()
        $expectedNames[$image.file] = $image.file
    }
    $supplements = @('LICENSE.txt','Noto-OFL.txt','README.txt','FLAGS-SOURCES.txt','flag-sources.json')
    $seen = @{}; $expanded = [long]0
    $archive = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName
            if ($seen.ContainsKey($name) -or (-not $expected.ContainsKey($name) -and $supplements -cnotcontains $name)) { throw "Unexpected or duplicate archive entry: $name." }
            # The uploader requires exact root-level names, including case.
            if ($expected.ContainsKey($name) -and $expectedNames[$name] -cne $name) { throw "Invalid archive entry case: $name." }
            $seen[$name] = $true
            $expanded += $entry.Length
            if ($expanded -gt 2GB) { throw 'Expanded artwork archive exceeds 2 GiB.' }
            if ($supplements -ccontains $name) {
                if ($entry.Length -gt 1MB) { throw "Artwork supplement exceeds 1 MiB: $name." }
                $reader = New-Object IO.StreamReader($entry.Open(), (New-Object Text.UTF8Encoding($false, $true)), $false)
                try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
                if ($text -match '[\p{Cc}-[\t\r\n]]') { throw "Invalid control character in artwork supplement: $name." }
            } else {
                $limit = if ($name -ceq 'tunein-artwork.json') { 4MB } else { 16MB }
                if ($entry.Length -gt $limit) { throw "Artwork archive entry exceeds its size limit: $name." }
                $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
                try { $hash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
                finally { $sha.Dispose(); $stream.Dispose() }
                if ($hash -cne $expected[$name]) { throw "Artwork archive content mismatch: $name." }
            }
        }
        foreach ($name in $expected.Keys) { if (-not $seen.ContainsKey($name)) { throw "Missing artwork archive entry: $name." } }
    } finally { $archive.Dispose() }
}
