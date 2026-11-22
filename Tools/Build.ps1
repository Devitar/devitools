param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$toc = Join-Path $root 'Devitools.toc'
$tocLines = Get-Content -LiteralPath $toc
$versionLine = $tocLines | Where-Object { $_ -match '^##\s*Version:\s*(\S+)\s*$' } | Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^##\s*Version:\s*([0-9A-Za-z][0-9A-Za-z._-]*)\s*$') {
    throw 'Devitools.toc must contain a valid Version metadata line.'
}
$version = $Matches[1]
if (-not $OutputPath) {
    $OutputPath = Join-Path $root "build\Devitools-$version.zip"
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
function Add-AddonFile([string]$relativePath) {
    $relativePath = $relativePath.Replace('/', '\')
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $root $relativePath))
    $prefix = $root.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Addon file must stay inside the project: $relativePath"
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required addon file is missing: $relativePath"
    }
    [void]$files.Add($fullPath.Substring($prefix.Length))
}

Add-AddonFile 'Devitools.toc'
foreach ($line in $tocLines) {
    $entry = $line.Trim()
    if (-not $entry -or $entry.StartsWith('#')) { continue }
    Add-AddonFile $entry
    if ([System.IO.Path]::GetExtension($entry) -ieq '.xml') {
        [xml]$xml = Get-Content -LiteralPath (Join-Path $root $entry) -Raw
        foreach ($script in $xml.SelectNodes('//*[local-name()="Script"][@file]')) {
            $child = Join-Path (Split-Path -Parent $entry) $script.GetAttribute('file')
            Add-AddonFile $child
        }
    }
}

# These notices accompany the NPC data and bundled GPL router in every release.
foreach ($notice in @(
    'LICENSE', 'README.md', 'Data\NPC_SOURCES.md',
    'Data\WaypointTracker-LICENSE.txt', 'Data\WaypointTracker-THIRD-PARTY-LICENSES.txt',
    'Data\WaypointTracker-TRAVEL-LICENSES.txt', 'Vendor\PolestarNav\LICENSE',
    'Vendor\PolestarNav\CREDITS.md', 'Vendor\PolestarNav\README.md'
)) {
    Add-AddonFile $notice
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tempFile = [System.IO.Path]::GetTempFileName()
try {
    $stream = [System.IO.File]::Open($tempFile, [System.IO.FileMode]::Create)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($file in ($files | Sort-Object)) {
                $entryName = $file.Replace('\', '/')
                [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $archive, (Join-Path $root $file), $entryName, [System.IO.Compression.CompressionLevel]::Optimal)
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
    Move-Item -LiteralPath $tempFile -Destination $OutputPath -Force
} finally {
    if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force }
}
Write-Output "Created $OutputPath ($($files.Count) files, version $version)."
