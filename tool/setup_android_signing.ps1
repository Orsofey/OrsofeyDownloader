param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$propertiesPath = Join-Path $root 'android\key.properties'
if (Test-Path $propertiesPath) {
    $raw = Get-Content $propertiesPath -Raw
    if (($raw -split "`r?`n").Count -eq 1) {
        $pattern = '^storeFile=(.*?)\s+storePassword=(.*?)\s+keyAlias=(.*?)\s+keyPassword=(.*?)$'
        if ($raw.Trim() -match $pattern) {
            $repairedLines = @(
                'storeFile=' + $Matches[1],
                'storePassword=' + $Matches[2],
                'keyAlias=' + $Matches[3],
                'keyPassword=' + $Matches[4]
            )
            [System.IO.File]::WriteAllText(
                $propertiesPath,
                ($repairedLines -join [Environment]::NewLine),
                [System.Text.UTF8Encoding]::new($false)
            )
        }
    }
    $existing = @{}
    Get-Content $propertiesPath | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $existing[$Matches[1]] = $Matches[2] }
    }
    if ($existing.ContainsKey('storePassword')) {
        $existing['keyPassword'] = $existing['storePassword']
        $currentKeystore = (Join-Path $root 'android\signing\release.jks').Replace('\', '/')
        $normalized = @(
            'storeFile=' + $currentKeystore,
            'storePassword=' + $existing['storePassword'],
            'keyAlias=' + $existing['keyAlias'],
            'keyPassword=' + $existing['keyPassword']
        )
        [System.IO.File]::WriteAllText(
            $propertiesPath,
            ($normalized -join [Environment]::NewLine),
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    Write-Output 'Android signing is already configured.'
    exit 0
}

$keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
if (!(Test-Path $keytool)) {
    $command = Get-Command keytool -ErrorAction SilentlyContinue
    if ($command) { $keytool = $command.Source }
}
if (!(Test-Path $keytool)) { throw 'keytool was not found. Install a JDK or configure JAVA_HOME.' }

$signingDir = Join-Path $root 'android\signing'
[System.IO.Directory]::CreateDirectory($signingDir) | Out-Null
$keystorePath = Join-Path $signingDir 'release.jks'

$random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
function New-Password {
    $bytes = [byte[]]::new(32)
    $random.GetBytes($bytes)
    return [Convert]::ToBase64String($bytes)
}
$storePassword = New-Password
# The default JDK keystore type is PKCS12, which requires matching passwords.
$keyPassword = $storePassword
$random.Dispose()

& $keytool -genkeypair -v `
    -keystore $keystorePath `
    -storepass $storePassword `
    -keypass $keyPassword `
    -alias orsofey `
    -keyalg RSA `
    -keysize 4096 `
    -validity 10000 `
    -dname 'CN=Orsofey Downloader, OU=Orsofey, O=Orsofey, C=RU'
if ($LASTEXITCODE -ne 0) { throw 'Failed to generate the Android signing key.' }

$normalizedPath = $keystorePath.Replace('\', '/')
$lines = @(
    'storeFile=' + $normalizedPath,
    'storePassword=' + $storePassword,
    'keyAlias=orsofey',
    'keyPassword=' + $keyPassword
)
[System.IO.File]::WriteAllText(
    $propertiesPath,
    ($lines -join [Environment]::NewLine),
    [System.Text.UTF8Encoding]::new($false)
)
Write-Output 'A local release key was generated. Back up android/key.properties and android/signing securely.'
