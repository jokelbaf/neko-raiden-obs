# Installs the Neko Raiden theme into the current user's OBS themes folder (Windows).
$ErrorActionPreference = 'Stop'

$themes = Join-Path $env:APPDATA 'obs-studio\themes'
New-Item -ItemType Directory -Force -Path $themes | Out-Null

foreach ($old in 'NekoRaiden', 'RaidenShogun', 'RaidenShogun.ovt') {
    $path = Join-Path $themes $old
    if (Test-Path $path) { Remove-Item -Recurse -Force $path }
}

Copy-Item -Force (Join-Path $PSScriptRoot 'NekoRaiden.ovt') $themes
Copy-Item -Force -Recurse (Join-Path $PSScriptRoot 'NekoRaiden') $themes

Write-Host "Installed to $themes"
Write-Host "Restart OBS, then pick Settings > Appearance > Theme: Yami, Style: Neko Raiden."
