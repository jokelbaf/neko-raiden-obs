<#
.SYNOPSIS
    Puts your own image into one of the theme's artwork spots, then reinstalls the theme.

.EXAMPLE
    .\set-art.ps1 -Slot sources -Image "C:\Pictures\neko-raiden.png"
    .\set-art.ps1 -Slot mixer -Image .\raiden.webp -Opacity 0.8
    .\set-art.ps1 -Slot scenes -Reset
#>
param(
    [Parameter(Mandatory)] [ValidateSet('scenes', 'sources', 'mixer', 'settings')] [string]$Slot,
    [string]$Image,
    [ValidateRange(0.1, 1.0)] [double]$Opacity = 1.0,
    [switch]$Reset,
    # File name to save under NekoRaiden\art (default: custom-<slot>.png)
    [string]$Name,
    [switch]$NoInstall
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$slots = @{
    scenes   = @{ Selector = 'SceneTree';                    Default = 'neko-raiden.png'; MaxW = 200; MaxH = 250 }
    sources  = @{ Selector = 'SourceTree';                   Default = $null;             MaxW = 150; MaxH = 170 }
    mixer    = @{ Selector = '#vMixerScrollArea';            Default = 'sit.svg';         MaxW = 220; MaxH = 150 }
    settings = @{ Selector = 'OBSBasicSettings #listWidget'; Default = 'loaf.svg';        MaxW = 160; MaxH = 110 }
}
$s = $slots[$Slot]
$theme = Join-Path $PSScriptRoot 'NekoRaiden.ovt'
$artDir = Join-Path $PSScriptRoot 'NekoRaiden\art'

function Get-OpaqueBounds([System.Drawing.Bitmap]$bmp) {
    $rect = New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height
    $data = $bmp.LockBits($rect, 'ReadOnly', [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $bytes = New-Object byte[] ($data.Stride * $bmp.Height)
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    } finally {
        $bmp.UnlockBits($data)
    }
    $minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        $row = $y * $data.Stride
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            if ($bytes[$row + $x * 4 + 3] -gt 8) {
                if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt 0) { return $rect }
    New-Object System.Drawing.Rectangle $minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1)
}

if ($Reset) {
    $file = $s.Default
} else {
    if (-not $Image) { throw 'Pass -Image <path> or -Reset.' }
    $src = New-Object System.Drawing.Bitmap ([System.Drawing.Image]::FromFile((Resolve-Path $Image)))
    try {
        $crop = Get-OpaqueBounds $src
        $scale = [Math]::Min(1.0, [Math]::Min($s.MaxW / $crop.Width, $s.MaxH / $crop.Height))
        $w = [int][Math]::Round($crop.Width * $scale)
        $h = [int][Math]::Round($crop.Height * $scale)
        $dst = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($dst)
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.SmoothingMode = 'HighQuality'
        $g.PixelOffsetMode = 'HighQuality'
        $attr = New-Object System.Drawing.Imaging.ImageAttributes
        $attr.SetWrapMode('TileFlipXY')
        $cm = New-Object System.Drawing.Imaging.ColorMatrix
        $cm.Matrix33 = [single]$Opacity
        $attr.SetColorMatrix($cm)
        $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), $crop.X, $crop.Y, $crop.Width, $crop.Height, 'Pixel', $attr)
        $g.Dispose()
        $file = if ($Name) { $Name } else { "custom-$Slot.png" }
        $dst.Save((Join-Path $artDir $file), [System.Drawing.Imaging.ImageFormat]::Png)
        $dst.Dispose()
        Write-Host "Saved $file (${w}x${h})"
    } finally {
        $src.Dispose()
    }
}

$value = if ($file) { "url(theme:NekoRaiden/art/$file)" } else { 'none' }
$css = [IO.File]::ReadAllText($theme)
$pattern = '(?s)(' + [Regex]::Escape($s.Selector) + '\s*\{[^}]*?background-image:\s*)[^;]+(;)'
if ($css -notmatch $pattern) { throw "Couldn't find the $Slot artwork rule in NekoRaiden.ovt." }
$css = [Regex]::Replace($css, $pattern, "`${1}$value`${2}")
[IO.File]::WriteAllText($theme, $css)
Write-Host "$Slot now uses $value"

if (-not $NoInstall) { & (Join-Path $PSScriptRoot 'install.ps1') }
