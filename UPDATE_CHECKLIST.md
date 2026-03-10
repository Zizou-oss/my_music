# Checklist mise a jour mobile

Cette checklist sert pour chaque nouvelle version Android de 2Block Musique.

## Une seule fois

Executer dans Supabase SQL Editor :

- `supabase/014_public_site_metrics.sql`
- `supabase/015_public_mobile_release_info.sql`
- `supabase/016_release_asset_url.sql`

## A chaque nouvelle mise a jour

1. Modifier la version dans `pubspec.yaml`

Exemple :

```yaml
version: 1.2.2+4
```

Regle rapide :

- correction / petit bug : `1.2.1 -> 1.2.2`
- nouvelle fonctionnalite : `1.2.1 -> 1.3.0`
- le `+build` augmente toujours de `1`

2. Generer l'APK release

Depuis le dossier `my_music` :

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release_apk_with_metadata.ps1 -DownloadUrl "https://github.com/Zizou-oss/2block-web/releases/download/v1.2.2/2block-musique.apk"
```

3. Recuperer dans le dossier `release/`

- le fichier APK
- le fichier `.sha256.txt`
- le fichier `mobile-release.json`

4. Creer une nouvelle GitHub Release

- tag exemple : `v1.2.2`
- uploader le nouvel APK

5. Copier l'URL directe du nouvel APK

Exemple :

```text
https://github.com/Zizou-oss/2block-web/releases/download/v1.2.2/2block-musique.apk
```

6. Ouvrir le web admin > `Parametres`

Remplir :

- `Version`
- `Notes`
- `URL directe du fichier APK`
- `SHA-256`
- `Taille APK`

Le lien public stable reste toujours :

```text
https://2block-web-ctth.vercel.app/telecharger/android
```

7. Cliquer sur `Publier la mise a jour mobile`

8. Verifier

- `https://2block-web-ctth.vercel.app/`
- `https://2block-web-ctth.vercel.app/telecharger/android`

## Resume ultra court

1. changer la version
2. build l'APK
3. creer la release GitHub
4. copier l'URL directe APK
5. coller dans le web admin
6. publier la mise a jour
