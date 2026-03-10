# Phase 2 Security Setup (Android)

## 1) Release signing (mandatory for production)

Create a keystore (once):

```powershell
keytool -genkeypair -v -storetype PKCS12 -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Move `upload-keystore.jks` to `android/` and create `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

Notes:
- `android/key.properties` is ignored by git.
- Without this file, release build falls back to debug signing (not for store release).

## 2) OAuth redirect (recommended config)

The app now supports a configurable redirect:

```bash
--dart-define=SUPABASE_EMAIL_REDIRECT_TO=https://2block-web-ctth.vercel.app/auth-callback
```

If not provided, it keeps:

```text
mymusic://auth-callback
```

## 3) App Links verification (for HTTPS redirect opening the app directly)

Android Manifest is ready for:

```text
https://2block-web-ctth.vercel.app/auth-callback
```

Now add `assetlinks.json` on your website:

`https://2block-web-ctth.vercel.app/.well-known/assetlinks.json`

Example content:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.my_music",
      "sha256_cert_fingerprints": [
        "AA:BB:CC:...:ZZ"
      ]
    }
  }
]
```

Use the SHA-256 fingerprint of the signing certificate used to install the app.

## 4) Supabase dashboard update

In `Authentication > URL Configuration > Redirect URLs`, add:

- `mymusic://auth-callback`
- `https://2block-web-ctth.vercel.app/auth-callback`

Keep both during transition to avoid login regressions.
