<#
.SYNOPSIS
    Generates an Android Release Keystore (.jks) and key.properties for Anni Music,
    and outputs Base64-encoded secrets ready for GitHub Actions CI/CD.

.DESCRIPTION
    Run from anywhere in the repository:
      powershell -ExecutionPolicy Bypass -File .\infra\scripts\generate-keystore.ps1

.PARAMETER StorePassword
    Password for the keystore (min 6 characters). Defaults to a newly generated strong password if omitted.

.PARAMETER KeyPassword
    Password for the signing key (min 6 characters). Defaults to StorePassword if omitted.

.PARAMETER KeyAlias
    Alias name for the signing key. Defaults to 'anni_release_key'.
#>

param(
    [string]$StorePassword = "",
    [string]$KeyPassword = "",
    [string]$KeyAlias = "anni_release_key",
    [string]$ValidityDays = "10000",
    [string]$DistinguishedName = "CN=Anni Music, OU=Mobile Engineering, O=Anni Labs, L=San Francisco, ST=California, C=US"
)

$ErrorActionPreference = "Stop"

# Resolve paths relative to repository root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$AndroidDir = Join-Path $RepoRoot "app\android"
$KeystoreDir = Join-Path $AndroidDir "keystore"
$KeystoreFile = Join-Path $KeystoreDir "anni-release-key.jks"
$KeyPropertiesFile = Join-Path $AndroidDir "key.properties"
$Base64OutputFile = Join-Path $ScriptDir "anni-release-key.base64.txt"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Anni Music - Android Release Keystore Generator (Windows)     " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Ensure keytool is available
$KeytoolCmd = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $KeytoolCmd) {
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\keytool.exe"))) {
        $KeytoolExe = Join-Path $env:JAVA_HOME "bin\keytool.exe"
    } else {
        Write-Error "Could not find 'keytool' on PATH or in JAVA_HOME. Install JDK 17+ or Android Studio first."
        exit 1
    }
} else {
    $KeytoolExe = $KeytoolCmd.Source
}

# Generate strong default passwords if not provided
if ([string]::IsNullOrWhiteSpace($StorePassword)) {
    $RandomBytes = New-Object byte[] 18
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($RandomBytes)
    $StorePassword = [Convert]::ToBase64String($RandomBytes) -replace '[^a-zA-Z0-9]', 'A'
}
if ([string]::IsNullOrWhiteSpace($KeyPassword)) {
    $KeyPassword = $StorePassword
}

# Create directories if needed
if (-not (Test-Path $KeystoreDir)) {
    New-Item -ItemType Directory -Path $KeystoreDir -Force | Out-Null
}

if (Test-Path $KeystoreFile) {
    Write-Warning "Existing keystore found at $KeystoreFile. Backing up before regeneration..."
    Copy-Item -Path $KeystoreFile -Destination "$KeystoreFile.bak" -Force
    Remove-Item -Path $KeystoreFile -Force
}

Write-Host "`n[1/3] Generating RSA-2048 PKCS12 Release Keystore..." -ForegroundColor Yellow
& $KeytoolExe -genkeypair -v `
    -keystore $KeystoreFile `
    -storetype PKCS12 `
    -alias $KeyAlias `
    -keyalg RSA `
    -keysize 2048 `
    -validity $ValidityDays `
    -storepass $StorePassword `
    -keypass $KeyPassword `
    -dname $DistinguishedName

if (-not (Test-Path $KeystoreFile)) {
    Write-Error "Failed to generate keystore at $KeystoreFile"
    exit 1
}

Write-Host "`n[2/3] Writing app/android/key.properties..." -ForegroundColor Yellow
$KeyPropsContent = @"
storePassword=$StorePassword
keyPassword=$KeyPassword
keyAlias=$KeyAlias
storeFile=../keystore/anni-release-key.jks
"@
Set-Content -Path $KeyPropertiesFile -Value $KeyPropsContent -Encoding UTF8

Write-Host "`n[3/3] Encoding Keystore to Base64 for GitHub Actions..." -ForegroundColor Yellow
$KeystoreBytes = [System.IO.File]::ReadAllBytes($KeystoreFile)
$Base64String = [System.Convert]::ToBase64String($KeystoreBytes)
Set-Content -Path $Base64OutputFile -Value $Base64String -NoNewline -Encoding ASCII

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "  SUCCESS! Release Signing Configured                           " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "Keystore File   : $KeystoreFile"
Write-Host "Key Properties  : $KeyPropertiesFile"
Write-Host "Base64 Output   : $Base64OutputFile"
Write-Host ""
Write-Host "Configure these GitHub Repository Secrets (Settings -> Secrets -> Actions):" -ForegroundColor Cyan
Write-Host "  ANNI_KEY_ALIAS          = $KeyAlias"
Write-Host "  ANNI_KEYSTORE_PASSWORD  = $StorePassword"
Write-Host "  ANNI_KEY_PASSWORD       = $KeyPassword"
Write-Host "  ANNI_KEYSTORE_BASE64    = <contents of $Base64OutputFile>"
Write-Host "================================================================" -ForegroundColor Green
