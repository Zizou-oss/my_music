# 2Block Music - Plateforme complète (App mobile + Web Admin)

Application mobile Flutter avec back-office web admin, base de données Supabase, téléchargement de morceaux (pas de streaming), écoute offline, et traçabilité complète des écoutes.

Version mobile actuelle: 1.3.1+4

## 0. Fonctionnalités mobiles actuelles

- Auth email (session persistée)
- Catalogue dynamique des sons publiés
- Téléchargement privé (pas d’accès fichier utilisateur)
- Lecture offline
- Sync des écoutes offline
- Likes (coeur = favoris)
- Commentaires sur les sons
- Notifications push (nouveau son + mise à jour)
- Écran "Soutenir l’artiste" (USSD) + déclaration en base
- Tutoriel lecteur (première ouverture)

## 1. Objectif

Plateforme dynamique en production:
- Admin ajoute les sons depuis un web admin
- Les sons sont stockés et indexés côté Supabase
- L'app affiche automatiquement les nouveaux sons publiés
- L'utilisateur doit créer un compte (email) avant de télécharger
- Le son téléchargé reste dans l'app (hors gestionnaire de fichiers)
- L'app fonctionne offline pour l'écoute
- Les vues/écoutes sont suivies en ligne et hors ligne, puis synchronisées

## 2. Contraintes produit

- Pas de streaming: la lecture se fait uniquement après téléchargement local.
- Fichier audio non exposé à l'utilisateur: stockage dans le sandbox privé de l'app.
- Téléchargement réservé aux utilisateurs authentifiés.
- Traçabilité admin: qui écoute quoi, quand, combien de temps, et cumul par son.

## 3. Architecture

Composants:
- App mobile: Flutter
- Backend: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- Web Admin: React (Vite), connecté à Supabase
- Stockage audio: Supabase Storage (bucket privé)
- Edge Functions: URL signées + push-broadcast

Flux global:
1. Admin upload un son dans le Web Admin
2. Le son est stocké en bucket privé + métadonnées en DB
3. L'app récupère la liste des sons publiés
4. User authentifié télécharge un son
5. Le fichier est enregistré dans le dossier privé de l'app
6. Écoutes trackées localement et envoyées au backend à la reconnexion
7. Dashboard admin affiche stats temps réel + cumulées

## 4. Authentification

- Méthode: email + mot de passe (Supabase Auth)
- Inscription obligatoire avant téléchargement
- Session persistée localement
- Vérification email recommandée en production

Rôles:
- `admin`: accès Web Admin complet
- `user`: accès app mobile (catalogue + téléchargement + lecture)

## 5. Modèle de données (Supabase)

Tables recommandées:

### `profiles`
- `id uuid pk` (lié à `auth.users.id`)
- `email text`
- `role text check in ('admin','user')`
- `created_at timestamptz`

### `songs`
- `id uuid pk`
- `title text not null`
- `artist text not null`
- `cover_url text`
- `storage_path text not null` (chemin objet audio dans bucket)
- `duration_seconds int`
- `size_bytes bigint`
- `is_published bool default false`
- `created_by uuid` (admin)
- `created_at timestamptz`
- `updated_at timestamptz`

### `song_downloads`
- `id uuid pk`
- `user_id uuid`
- `song_id uuid`
- `downloaded_at timestamptz`
- `app_version text`
- `device_id text`

### `listening_events`
- `id uuid pk`
- `user_id uuid`
- `song_id uuid`
- `started_at timestamptz`
- `ended_at timestamptz`
- `seconds_listened int`
- `is_offline bool`
- `synced_at timestamptz`
- `device_id text`
- `session_id text`
- `created_at timestamptz`

### `song_stats_daily` (optionnel, agrégats)
- `day date`
- `song_id uuid`
- `plays_count int`
- `listeners_count int`
- `seconds_total bigint`

### Tables sociales & support
- `song_likes` (favoris/likes)
- `song_comments` (commentaires)
- `support_declarations` (déclarations de soutien)

### Config & métriques publiques
- `app_settings` (release mobile, notes, urls)
- `push_tokens` (FCM tokens)
- `site_download_events` (téléchargements via site)
- `listening_events_daily` (agrégats journaliers)

## 6. Storage audio (sécurité)

Bucket:
- `songs-private` en privé (non public)

Règles:
- Seul `admin` peut upload/supprimer
- `user` ne peut obtenir qu'une URL signée pour un son autorisé

Téléchargement côté app:
- URL signée courte durée via Edge Function
- téléchargement binaire en HTTPS
- stockage dans répertoire privé app (`getApplicationSupportDirectory`)

Important:
- Le sandbox empêche l'accès via gestionnaire de fichiers classique.
- Sur appareil rooté/jailbreaké, le risque zéro n'existe pas.
- Recommandé: chiffrement local des fichiers audio + clé stockée via keystore/keychain.

## 7. App mobile: logique fonctionnelle

### Catalogue
- L'app charge les `songs` publiés depuis Supabase.
- Affiche état par son:
- non téléchargé
- téléchargement en cours
- téléchargé (offline ready)

### Téléchargement
- Action autorisée seulement si user connecté.
- Le fichier est enregistré dans stockage privé app.
- Enregistrer une ligne dans `song_downloads`.

### Lecture
- Lecture uniquement depuis fichier local téléchargé.
- Si non téléchargé: proposer "Télécharger".
- Aucun flux distant en direct.

### Social & soutien
- Likes = favoris (coeur).
- Commentaires disponibles dans le lecteur.
- Écran "Soutenir l'artiste" (USSD) + déclaration en base.

### Notifications push
- Topics: `song_updates`, `app_updates`
- Envoi depuis le Web Admin (Edge Function `push-broadcast`)

### Offline
- Si fichier local présent: écoute possible sans réseau.
- Les événements d'écoute sont mis en queue locale.

## 8. Tracking des écoutes (online + offline)

Événement minimal à envoyer:
- `user_id`, `song_id`, `session_id`, `seconds_listened`, `started_at`, `ended_at`, `is_offline`

Mode offline:
1. L'app écrit les événements dans une table locale (SQLite)
2. Un déclencheur de sync se lance quand internet revient
3. Les événements non sync sont envoyés en batch à Supabase
4. Si succès: marquer `synced_at` local

Déclencheurs de synchronisation:
- retour réseau
- ouverture app
- fin d'écoute
- job périodique en foreground

Anti-doublons:
- `session_id` unique par session d'écoute
- contrainte d'unicité côté serveur sur `(user_id, song_id, session_id)`

Agrégats:
- `songs.plays_count` consolidé côté backend
- `listening_events_daily` pour les graphiques journaliers

## 9. Web Admin

Fonctions minimales:
- Login admin
- CRUD songs (titre, artiste, cover, audio)
- Publication/dépublication
- Vue des téléchargements
- Vue des écoutes détaillées
- Modération des commentaires/likes
- Envoi des notifications push
- Publication de la release mobile
 - KPIs + graphiques (journaliers + top songs)

Dashboard recommandé:
- KPIs globaux:
- écoutes totales
- utilisateurs actifs (jour/semaine/mois)
- top songs
- taux download -> écoute
- Graphiques:
- écoutes par jour
- écoutes par son
- temps moyen écouté
- Table traçabilité:
- user (email)
- son
- date/heure
- durée écoutée
- source online/offline sync

## 10. Sécurité et conformité

- Activer RLS sur toutes les tables sensibles
- Policy stricte par rôle (`admin` vs `user`)
- Jamais exposer bucket audio en public
- Logs d'accès admin (audit)
- Rotation des clés et tokens signés courts
- Limitation de débit sur endpoints de download/sync

## 11. RLS (règles de base à appliquer)

- `songs`: lecture des lignes `is_published=true` pour users, full accès admin
- `song_downloads`: insert/read seulement par le propriétaire (`user_id = auth.uid()`)
- `listening_events`: insert/read seulement par propriétaire, read global admin
- `profiles`: user lit son profil, admin lit tous

## 12. Plan d'implémentation (ordre conseillé)

1. Mettre en place Supabase (Auth, DB, Storage, RLS)
2. Créer Web Admin upload + publication des sons
3. Brancher app Flutter au catalogue distant
4. Implémenter login email obligatoire avant download
5. Implémenter download sécurisé vers stockage privé
6. Bloquer la lecture si fichier non téléchargé
7. Implémenter queue offline des écoutes
8. Implémenter synchronisation automatique des écoutes
9. Construire dashboard admin détaillé
10. Ajouter monitoring et logs d'audit

## 13. Critères d'acceptation

- Un admin peut ajouter un son et le publier depuis le web.
- Le son publié apparaît dans l'app sans update binaire.
- Un user non connecté ne peut pas télécharger.
- Un user connecté peut télécharger et écouter offline.
- Le fichier audio n'apparaît pas dans le gestionnaire de fichiers standard.
- Les écoutes offline sont synchronisées automatiquement quand le réseau revient.
- Le dashboard admin affiche les vues cumulées par son et le détail par utilisateur.

## 14. Commandes utiles (Flutter)

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

## 15. État actuel vs cible

État actuel:
- Catalogue Supabase + publication depuis Web Admin
- Téléchargement offline + tracking sync
- Likes/Commentaires + Soutien artiste
- Push notifications (FCM)
- Dashboard admin (KPIs + graphiques)

Cible:
- Améliorer cache audio et monitoring
- Optimiser encore les temps de téléchargement

---

Si besoin, la prochaine étape est de produire le schéma SQL Supabase complet (tables, index, contraintes, RLS policies, fonctions de sync) et la checklist de dev par sprint.

## Fichiers DB générés

- Schéma SQL complet: `supabase/001_init_schema.sql`
- Guide de création + réglages Supabase: `supabase/SETUP_DB.md`
