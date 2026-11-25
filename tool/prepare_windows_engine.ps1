param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$engineDir = Join-Path $root 'engine\windows'
$downloadDir = Join-Path $root 'engine\downloads'
$licenseDir = Join-Path $engineDir 'licenses'
[System.IO.Directory]::CreateDirectory($engineDir) | Out-Null
[System.IO.Directory]::CreateDirectory($downloadDir) | Out-Null
[System.IO.Directory]::CreateDirectory($licenseDir) | Out-Null

function Download-Asset([string]$url, [string]$destination, [switch]$ForceDownload) {
    if (!$ForceDownload -and (Test-Path $destination) -and ((Get-Item $destination).Length -gt 0)) {
        Write-Output "Using cached $(Split-Path -Leaf $destination)"
        return
    }
    Write-Output "Downloading $(Split-Path -Leaf $destination)"
    curl.exe -L --fail --retry 3 --retry-all-errors --silent --show-error $url -o $destination
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $url" }
}

function Assert-Checksum([string]$file, [string]$checksumFile, [string]$assetName) {
    $raw = Get-Content $checksumFile -Raw
    if ($raw -match 'Hash\s*:\s*([A-Fa-f0-9]{64})') {
        $expected = $Matches[1].ToLowerInvariant()
    } else {
        $expectedLine = Get-Content $checksumFile | Where-Object {
            $parts = $_ -split '\s+'
            $name = $parts[-1].Replace('./', '')
            $name -eq $assetName
        } | Select-Object -First 1
        if (!$expectedLine) { throw "No checksum for $assetName" }
        $expected = ($expectedLine -split '\s+')[0].ToLowerInvariant()
    }
    $actual = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLowerInvariant()
    if ($expected -ne $actual) { throw "Checksum mismatch for $assetName" }
    Write-Output "Verified $assetName"
}

$ytDlp = Join-Path $engineDir 'yt-dlp.exe'
Download-Asset 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' $ytDlp -ForceDownload:$Force
$ytSums = Join-Path $downloadDir 'yt-dlp-SHA2-256SUMS'
Download-Asset 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS' $ytSums -ForceDownload:$Force
Assert-Checksum $ytDlp $ytSums 'yt-dlp.exe'

$denoZip = Join-Path $downloadDir 'deno-x86_64-pc-windows-msvc.zip'
Download-Asset 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' $denoZip -ForceDownload:$Force
$denoSums = Join-Path $downloadDir 'deno-x86_64-pc-windows-msvc.zip.sha256sum'
Download-Asset 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip.sha256sum' $denoSums -ForceDownload:$Force
Assert-Checksum $denoZip $denoSums 'deno-x86_64-pc-windows-msvc.zip'
$denoExtract = Join-Path $downloadDir 'deno'
Expand-Archive -Path $denoZip -DestinationPath $denoExtract -Force
Copy-Item (Join-Path $denoExtract 'deno.exe') (Join-Path $engineDir 'deno.exe') -Force

$ffmpegZip = Join-Path $downloadDir 'ffmpeg-master-latest-win64-gpl.zip'
Download-Asset 'https://github.com/yt-dlp/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip' $ffmpegZip -ForceDownload:$Force
$ffmpegSums = Join-Path $downloadDir 'ffmpeg-checksums.sha256'
Download-Asset 'https://github.com/yt-dlp/FFmpeg-Builds/releases/latest/download/checksums.sha256' $ffmpegSums -ForceDownload:$Force
Assert-Checksum $ffmpegZip $ffmpegSums 'ffmpeg-master-latest-win64-gpl.zip'
$ffmpegExtract = Join-Path $downloadDir 'ffmpeg'
Expand-Archive -Path $ffmpegZip -DestinationPath $ffmpegExtract -Force
$ffmpegBin = Get-ChildItem $ffmpegExtract -Recurse -Filter ffmpeg.exe | Select-Object -First 1
$ffprobeBin = Get-ChildItem $ffmpegExtract -Recurse -Filter ffprobe.exe | Select-Object -First 1
if (!$ffmpegBin -or !$ffprobeBin) { throw 'FFmpeg binaries were not found in the archive' }
Copy-Item $ffmpegBin.FullName (Join-Path $engineDir 'ffmpeg.exe') -Force
Copy-Item $ffprobeBin.FullName (Join-Path $engineDir 'ffprobe.exe') -Force

curl.exe -L --fail --silent --show-error 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/LICENSE' -o (Join-Path $licenseDir 'yt-dlp-LICENSE')
curl.exe -L --fail --silent --show-error 'https://raw.githubusercontent.com/denoland/deno/main/LICENSE.md' -o (Join-Path $licenseDir 'Deno-LICENSE.md')
$ffmpegLicense = Get-ChildItem $ffmpegExtract -Recurse -File | Where-Object { $_.Name -match '^LICENSE' } | Select-Object -First 1
if ($ffmpegLicense) { Copy-Item $ffmpegLicense.FullName (Join-Path $licenseDir 'FFmpeg-LICENSE.txt') -Force }

& (Join-Path $engineDir 'yt-dlp.exe') --version
& (Join-Path $engineDir 'deno.exe') --version | Select-Object -First 1
& (Join-Path $engineDir 'ffmpeg.exe') -version | Select-Object -First 1
Write-Output "Windows engine is ready: $engineDir"
