param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot

function New-RoundedPath([float]$x, [float]$y, [float]$width, [float]$height, [float]$radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-BrandBitmap([int]$size) {
    $bitmap = [System.Drawing.Bitmap]::new(
        $size,
        $size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $rect = [System.Drawing.RectangleF]::new(0, 0, $size, $size)
    $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $rect,
        [System.Drawing.Color]::FromArgb(255, 105, 103, 229),
        [System.Drawing.Color]::FromArgb(255, 55, 55, 153),
        [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
    )
    $shape = New-RoundedPath 0 0 $size $size ($size * 0.225)
    $graphics.FillPath($gradient, $shape)

    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $stem = New-RoundedPath ($size * 0.454) ($size * 0.20) ($size * 0.092) ($size * 0.36) ($size * 0.046)
    $graphics.FillPath($white, $stem)

    $arrow = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $points = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($size * 0.29, $size * 0.49),
        [System.Drawing.PointF]::new($size * 0.71, $size * 0.49),
        [System.Drawing.PointF]::new($size * 0.50, $size * 0.76)
    )
    $arrow.AddPolygon($points)
    $graphics.FillPath($white, $arrow)

    $peach = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 255, 218, 199))
    $graphics.FillEllipse($peach, $size * 0.72, $size * 0.16, $size * 0.10, $size * 0.10)

    $graphics.Dispose()
    $gradient.Dispose()
    $shape.Dispose()
    $white.Dispose()
    $stem.Dispose()
    $arrow.Dispose()
    $peach.Dispose()
    return $bitmap
}

function Save-Resized([System.Drawing.Bitmap]$source, [int]$size, [string]$path) {
    $directory = Split-Path -Parent $path
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($source, 0, 0, $size, $size)
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

$source = New-BrandBitmap 1024
$sourcePath = Join-Path $root 'assets\images\app_icon.png'
[System.IO.Directory]::CreateDirectory((Split-Path -Parent $sourcePath)) | Out-Null
$source.Save($sourcePath, [System.Drawing.Imaging.ImageFormat]::Png)

$androidSizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}
foreach ($entry in $androidSizes.GetEnumerator()) {
    $path = Join-Path $root "android\app\src\main\res\$($entry.Key)\ic_launcher.png"
    Save-Resized $source $entry.Value $path
}

$pngPath = Join-Path $root 'assets\images\app_icon_256.png'
Save-Resized $source 256 $pngPath
$pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
$stream = [System.IO.MemoryStream]::new()
$writer = [System.IO.BinaryWriter]::new($stream)
$writer.Write([uint16]0)
$writer.Write([uint16]1)
$writer.Write([uint16]1)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([uint16]1)
$writer.Write([uint16]32)
$writer.Write([uint32]$pngBytes.Length)
$writer.Write([uint32]22)
$writer.Write($pngBytes)
$writer.Flush()
[System.IO.File]::WriteAllBytes(
    (Join-Path $root 'windows\runner\resources\app_icon.ico'),
    $stream.ToArray()
)
$writer.Dispose()
$stream.Dispose()
$source.Dispose()

Write-Output 'Brand icons generated.'
