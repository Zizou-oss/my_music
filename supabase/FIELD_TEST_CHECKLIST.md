# 2Block Music - Checklist tests terrain (offline/online)

Ce plan valide le flux réel: login, téléchargement, écoute offline, synchronisation et dashboard.

## Pré-requis

- DB appliquée:
  - `001_init_schema.sql`
  - `002_schema_extensions.sql`
- App lancée avec:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- Au moins 1 son publié en DB (`songs.is_published=true`)
- 2 comptes:
  - 1 admin
  - 1 user standard

## Test 1 - Auth user

1. Ouvrir l’app mobile.
2. Aller dans le menu compte.
3. Se connecter avec compte user.

Résultat attendu:
- Connexion réussie.
- Session persistée après relance app.

## Test 2 - Catalogue distant

1. Avec réseau actif, ouvrir la liste des sons.
2. Vérifier qu’un son ajouté via admin web apparaît.

Résultat attendu:
- Le son est visible sans recompiler l’app.

## Test 3 - Téléchargement protégé

1. Déconnecter le compte.
2. Tenter téléchargement d’un son.
3. Reconnecter user, retenter.

Résultat attendu:
- Sans login: téléchargement refusé.
- Avec login: téléchargement réussi.
- Icône/état “téléchargé” visible.

## Test 4 - Lecture sans streaming

1. Choisir un son non téléchargé.
2. Tenter lecture.
3. Choisir un son téléchargé.
4. Lancer lecture.

Résultat attendu:
- Son non téléchargé: lecture bloquée + message.
- Son téléchargé: lecture OK.

## Test 5 - Offline pur

1. Mettre téléphone en mode avion.
2. Ouvrir app.
3. Vérifier catalogue (cache).
4. Lire un son déjà téléchargé.
5. Lire 10-30 secondes, pause/stop.

Résultat attendu:
- Catalogue affiché depuis cache local.
- Lecture locale OK sans réseau.
- Pas de crash.

## Test 6 - Sync écoute au retour réseau

1. Sortir du mode avion.
2. Attendre la sync auto (quelques secondes) ou relancer app.
3. Vérifier DB:
   - `listening_events`
   - `admin_dashboard_kpis`
   - `admin_song_stats`

Résultat attendu:
- Les écoutes offline sont remontées.
- `is_offline=true` pour ces events.
- Pas de doublons de session.

## Test 7 - Sync download différé

1. Couper réseau.
2. Simuler cas où RPC download ne passe pas (download déjà local).
3. Revenir online.
4. Vérifier `song_downloads`.

Résultat attendu:
- Les enregistrements en attente sont synchronisés.

## Test 8 - Dashboard admin

1. Ouvrir web admin avec compte admin.
2. Vérifier:
   - KPI événements
   - top songs
   - activité “qui écoute quoi”
3. Rafraîchir stats journalières si nécessaire:
   - `select public.refresh_song_stats_daily();`

Résultat attendu:
- Les chiffres reflètent les actions des tests précédents.

## Test 9 - RLS sécurité

1. Avec compte user:
   - tenter modification `songs`
   - tenter lecture events d’un autre user
2. Avec compte admin:
   - accès complet songs et vues admin

Résultat attendu:
- User limité à ses droits.
- Admin accès global.

## Requêtes de vérification rapide

```sql
select * from public.admin_dashboard_kpis;
select * from public.admin_song_stats limit 20;
select * from public.admin_listening_events_detailed limit 50;
select * from public.song_downloads order by downloaded_at desc limit 50;
```

## Critères de GO

- Auth stable.
- Download protégé par login.
- Lecture uniquement depuis local téléchargé.
- Écoutes offline synchronisées automatiquement.
- Dashboard cohérent avec la réalité.
- RLS validé (pas de fuite de données user).
