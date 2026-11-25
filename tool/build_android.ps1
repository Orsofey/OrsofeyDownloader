param(
    [ValidateSet('debug', 'release')]
    [string]$Configuration = 'release'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$env:PUB_CACHE = Join-Path $root '.pub-cache'
$env:GRADLE_USER_HOME = Join-Path $root '.gradle'

if (!(Test-Path (Join-Path $root 'android\app\src\main\res\raw\ytdlp'))) {
    & (Join-Path $PSScriptRoot 'prepare_android_engine.ps1')
}

if ($Configuration -eq 'release' -and !(Test-Path (Join-Path $root 'android\key.properties'))) {
    & (Join-Path $PSScriptRoot 'setup_android_signing.ps1')
}

flutter build apk --$Configuration --target-platform android-arm64
if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }

$source = Join-Path $root "build\app\outputs\flutter-apk\app-$Configuration.apk"
$dist = Join-Path $root 'dist'
[System.IO.Directory]::CreateDirectory($dist) | Out-Null
$target = Join-Path $dist "OrsofeyDownloader-arm64-v8a-$Configuration.apk"
Copy-Item $source $target -Force
$hash = (Get-FileHash -Algorithm SHA256 $target).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText("$target.sha256", "$hash  $(Split-Path -Leaf $target)`n")
Write-Output "APK: $target"
Write-Output "SHA256: $hash"
