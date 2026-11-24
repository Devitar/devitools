param(
    [string]$AddOnsPath = 'D:\Games\Battle.net\World of Warcraft\_forever_\Interface\AddOns'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$build = Join-Path $root 'build'
$archive = Join-Path $build 'Devitools-dev-staging.zip'
$staging = Join-Path $build 'dev-staging'
$source = Join-Path $staging 'Devitools'
$destination = Join-Path $AddOnsPath 'Devitools-Dev'

# Build the same complete file set as a release, then isolate the dev copy's
# globals, slash command, and saved variables without modifying release files.
& (Join-Path $PSScriptRoot 'Build.ps1') -OutputPath $archive
if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
Expand-Archive -LiteralPath $archive -DestinationPath $staging
$utf8 = New-Object System.Text.UTF8Encoding($false)
Get-ChildItem -LiteralPath $source -Filter '*.lua' -File -Recurse | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName)
    $text = $text.Replace('Devitools', 'DevitoolsDev').Replace('DEVITOOLS', 'DEVITOOLSDEV').Replace('/dvt', '/dvtdev')
    $text = $text.Replace('DevitoolsDev:', 'Devitools Dev:').Replace('"DevitoolsDev"', '"Devitools (Dev)"')
    [System.IO.File]::WriteAllText($_.FullName, $text, $utf8)
}
$toc = Join-Path $source 'Devitools.toc'
$text = [System.IO.File]::ReadAllText($toc)
$text = $text.Replace('## Title: Devitools', '## Title: Devitools (Dev)')
$text = $text.Replace('DevitoolsCharacterDB', 'DevitoolsDevCharacterDB').Replace('DevitoolsDB', 'DevitoolsDevDB')
[System.IO.File]::WriteAllText((Join-Path $source 'Devitools-Dev.toc'), $text, $utf8)
Remove-Item -LiteralPath $toc -Force
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $destination -Recurse -Force
Write-Output "Installed development addon at $destination. Use /dvtdev for its settings."
