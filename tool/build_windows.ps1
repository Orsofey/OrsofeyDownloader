param(
    [switch]$SkipEngineDownload,
    [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$env:PUB_CACHE = Join-Path $root '.pub-cache'

$ytDlp = Join-Path $root 'engine\windows\yt-dlp.exe'
if (!$SkipEngineDownload -and !(Test-Path $ytDlp)) {
    & (Join-Path $PSScriptRoot 'prepare_windows_engine.ps1')
}

flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }

$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$engineTarget = Join-Path $releaseDir 'engine'
if (Test-Path (Join-Path $root 'engine\windows')) {
    [System.IO.Directory]::CreateDirectory($engineTarget) | Out-Null
    Copy-Item (Join-Path $root 'engine\windows\*') $engineTarget -Recurse -Force
}
Copy-Item (Join-Path $root 'LICENSE') (Join-Path $releaseDir 'LICENSE.txt') -Force
Copy-Item (Join-Path $root 'THIRD_PARTY_NOTICES.md') (Join-Path $releaseDir 'THIRD_PARTY_NOTICES.md') -Force

if ($SkipInstaller) {
    Write-Output "Windows app: $releaseDir"
    exit 0
}

$iscc = Get-Command iscc -ErrorAction SilentlyContinue
$isccCandidates = @(
    $(if ($iscc) { $iscc.Source }),
    "$env:LOCALAPPDATA\Programs\Inno Setup 7\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) }
$isccPath = $isccCandidates | Select-Object -First 1
if (!$isccPath) {
    throw 'Inno Setup was not found. Install it or run with -SkipInstaller.'
}
& $isccPath (Join-Path $root 'packaging\windows\installer.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer build failed.' }

$setup = Join-Path $root 'dist\OrsofeyDownloader-Setup.exe'
$hash = (Get-FileHash -Algorithm SHA256 $setup).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText("$setup.sha256", "$hash  OrsofeyDownloader-Setup.exe`n")
Write-Output "Installer: $setup"
Write-Output "SHA256: $hash"
