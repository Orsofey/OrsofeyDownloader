param([switch]$Force)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$rawDir = Join-Path $root 'android\app\src\main\res\raw'
$downloadDir = Join-Path $root 'engine\downloads'
[System.IO.Directory]::CreateDirectory($rawDir) | Out-Null
[System.IO.Directory]::CreateDirectory($downloadDir) | Out-Null

$target = Join-Path $rawDir 'ytdlp'
$sums = Join-Path $downloadDir 'yt-dlp-SHA2-256SUMS'
if ($Force -or !(Test-Path $target)) {
    curl.exe -L --fail --retry 3 --retry-all-errors --silent --show-error 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp' -o $target
    if ($LASTEXITCODE -ne 0) { throw 'Failed to download Android yt-dlp asset' }
}
if ($Force -or !(Test-Path $sums)) {
    curl.exe -L --fail --retry 3 --retry-all-errors --silent --show-error 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS' -o $sums
    if ($LASTEXITCODE -ne 0) { throw 'Failed to download yt-dlp checksums' }
}

$line = Get-Content $sums | Where-Object {
    $parts = $_ -split '\s+'
    $parts[-1].Replace('./', '') -eq 'yt-dlp'
} | Select-Object -First 1
if (!$line) { throw 'Android yt-dlp checksum was not found' }
$expected = ($line -split '\s+')[0].ToLowerInvariant()
$actual = (Get-FileHash -Algorithm SHA256 $target).Hash.ToLowerInvariant()
if ($expected -ne $actual) { throw 'Android yt-dlp checksum mismatch' }
Write-Output "Verified Android yt-dlp asset: $(Split-Path -Leaf $target) ($actual)"
