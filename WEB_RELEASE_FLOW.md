# Web Release Flow

This flow is for distributing the Android app from your website instead of Play Store.

## 1) Build the signed APK

Prerequisites:
- `android/key.properties` exists
- release keystore exists in `android/`

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release_apk_with_metadata.ps1 -DownloadUrl "https://2block-web-ctth.vercel.app/downloads/app-release.apk"
```

Generated files:
- `release/2block-music-<version>.apk`
- `release/2block-music-<version>.apk.sha256.txt`
- `release/mobile-release.json`

## 2) Upload to your website

Upload:
- the APK file
- optionally the `.sha256.txt`

Recommended public URL format:

```text
https://2block-web-ctth.vercel.app/downloads/2block-music-1.2.1_3.apk
```

## 3) Publish the release in admin

In admin `Settings`:
- version
- notes
- direct HTTPS APK file URL
- SHA-256
- APK size in bytes

The public landing page stays fixed on:

```text
https://2block-web-ctth.vercel.app/telecharger/android
```

You only change the direct APK file URL for each release.

This writes release metadata into `app_settings.latest_mobile_release` and sends the push.

## 4) Mobile behavior

- push update opens the website/APK link
- fallback local announcement also opens the release URL
- version comparison prevents duplicate notices for same release

## 5) Minimum security rules

- never publish debug-signed APKs
- always keep HTTPS download URLs
- publish SHA-256 for each release
- keep the same signing key for all future updates
