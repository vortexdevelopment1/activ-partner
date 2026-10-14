$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Bitmap]::new((Join-Path $projectRoot 'assets/logo.png'))

function Export-Logo([string]$relativePath, [int]$width, [int]$height, [bool]$opaque = $false) {
    $bitmap = [System.Drawing.Bitmap]::new($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        if ($opaque) {
            $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#F3F9D7'))
        }
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $padding = if ($opaque) { 0.12 } else { 0 }
        $scale = [Math]::Min($width * (1 - 2 * $padding) / $source.Width, $height * (1 - 2 * $padding) / $source.Height)
        $drawWidth = [single]($source.Width * $scale)
        $drawHeight = [single]($source.Height * $scale)
        $rectangle = [System.Drawing.RectangleF]::new(($width - $drawWidth) / 2, ($height - $drawHeight) / 2, $drawWidth, $drawHeight)
        $graphics.DrawImage($source, $rectangle)
        $bitmap.Save((Join-Path $projectRoot $relativePath), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    Export-Logo 'assets/launcher_logo.png' 1024 1024 $true
    $densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
    foreach ($density in $densities.Keys) {
        Export-Logo "android/app/src/main/res/mipmap-$density/ic_launcher_round.png" $densities[$density] $densities[$density] $true
    }
    Export-Logo 'android/app/src/main/res/drawable-nodpi/launch_logo.png' 168 96
    Export-Logo 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png' 168 96
    Export-Logo 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png' 336 192
    Export-Logo 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png' 504 288
} finally {
    $source.Dispose()
}
