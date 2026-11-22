param([Parameter(Mandatory = $true)][string]$ArchivePath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ArchivePath).Path)
try {
    $names = @{}
    $hash = [System.Security.Cryptography.SHA256]::Create()
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -match '(^|/)(Devitools|tests|Tools|\.git|build)/') {
                throw "Unexpected archive entry: $($entry.FullName)"
            }
            $names[$entry.FullName] = $true
            $relative = $entry.FullName.Replace('/', '\')
            $source = [System.IO.File]::OpenRead((Join-Path $root $relative))
            $packed = $entry.Open()
            try {
                $sourceHash = [System.Convert]::ToBase64String($hash.ComputeHash($source))
                $packedHash = [System.Convert]::ToBase64String($hash.ComputeHash($packed))
                if ($sourceHash -ne $packedHash) { throw "Archive content differs: $relative" }
            } finally {
                $source.Dispose()
                $packed.Dispose()
            }
        }
    } finally {
        $hash.Dispose()
    }
    foreach ($name in @('Devitools.toc', 'LICENSE', 'Data/NPC_SOURCES.md',
        'Data/WaypointTracker-LICENSE.txt', 'Data/WaypointTracker-THIRD-PARTY-LICENSES.txt',
        'Data/WaypointTracker-TRAVEL-LICENSES.txt', 'Vendor/PolestarNav/LICENSE',
        'Vendor/PolestarNav/CREDITS.md')) {
        if (-not $names.ContainsKey($name)) { throw "Missing required entry: $name" }
    }
    foreach ($line in Get-Content -LiteralPath (Join-Path $root 'Devitools.toc')) {
        $entry = $line.Trim()
        if (-not $entry -or $entry.StartsWith('#')) { continue }
        if (-not $names.ContainsKey($entry.Replace('\', '/'))) { throw "Missing TOC entry: $entry" }
        if ([System.IO.Path]::GetExtension($entry) -ieq '.xml') {
            [xml]$xml = Get-Content -LiteralPath (Join-Path $root $entry) -Raw
            foreach ($script in $xml.SelectNodes('//*[local-name()="Script"][@file]')) {
                $child = (Join-Path (Split-Path -Parent $entry) $script.GetAttribute('file')).Replace('\', '/')
                if (-not $names.ContainsKey($child)) { throw "Missing XML entry: $child" }
            }
        }
    }
    Write-Output "Archive validation passed ($($zip.Entries.Count) files)."
} finally {
    $zip.Dispose()
}
