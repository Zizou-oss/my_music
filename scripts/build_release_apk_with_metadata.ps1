param(
  [string]$DownloadUrl = "",
  [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
  $OutputDir = Join-Path $root "release"
}

$pubspecPath = Join-Path $root "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
  throw "pubspec.yaml introuvable: $pubspecPath"
}

$pubspecContent = Get-Content -Raw -Path $pubspecPath
$versionMatch = [regex]::Match($pubspecContent, "(?m)^version:\s*([^\r\n]+)\s*$")
if (-not $versionMatch.Success) {
  throw "Version introuvable dans pubspec.yaml"
}

$version = $versionMatch.Groups[1].Value.Trim()
$safeVersion = ($version -replace "[^0-9A-Za-z._-]", "_")

Push-Location $root
try {
  flutter build apk --release
} finally {
  Pop-Location
}

$apkPath = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkPath)) {
  throw "APK release introuvable: $apkPath"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$copiedApkName = "2block-music-$safeVersion.apk"
$copiedApkPath = Join-Path $OutputDir $copiedApkName
Copy-Item -Force -Path $apkPath -Destination $copiedApkPath

$hash = (Get-FileHash -Algorithm SHA256 -Path $copiedApkPath).Hash.ToLowerInvariant()
$sizeBytes = (Get-Item $copiedApkPath).Length

$hashFilePath = Join-Path $OutputDir "$copiedApkName.sha256.txt"
Set-Content -Path $hashFilePath -Value $hash

$metadata = [ordered]@{
  version = $version
  file_name = $copiedApkName
  apk_sha256 = $hash
  apk_size_bytes = $sizeBytes
  built_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  download_url = $DownloadUrl.Trim()
}

$metadataPath = Join-Path $OutputDir "mobile-release.json"
$metadata | ConvertTo-Json -Depth 4 | Set-Content -Path $metadataPath

Write-Host ""
Write-Host "Release APK genere:"
Write-Host "APK        : $copiedApkPath"
Write-Host "SHA-256    : $hash"
Write-Host "Taille     : $sizeBytes bytes"
Write-Host "Metadata   : $metadataPath"
Write-Host ""
