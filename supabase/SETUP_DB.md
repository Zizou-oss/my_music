# Setup Supabase DB (de 0 a prod)

Ce guide couvre la creation du projet Supabase et les reglages necessaires pour ton app mobile + admin web.

## 1. Creer le projet Supabase

1. Aller sur Supabase > `New project`
2. Choisir:
- `Project name`: `2block-music-prod` (ou staging/dev)
- Region proche de tes users
- DB password fort
3. Attendre la creation

## 2. Recuperer les credentials

Dans `Project Settings > API`:
- `Project URL` -> `SUPABASE_URL`
- `anon public key` -> `SUPABASE_ANON_KEY`

Utilisation Flutter:
```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Utilisation Web Admin React:
```env
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
```

## 3. Executer le schema SQL

1. Ouvrir `SQL Editor`
2. Coller le contenu de `supabase/001_init_schema.sql`
3. Executer
4. Coller ensuite `supabase/002_schema_extensions.sql`
5. Executer
6. Coller ensuite `supabase/012_security_hardening.sql`
7. Executer
8. Coller ensuite `supabase/013_mobile_release_distribution.sql`
9. Executer
10. (Validation) Executer `supabase/003_e2e_validation.sql`

Ce script cree:
- tables `profiles`, `songs`, `song_downloads`, `listening_events`
- index + contraintes + anti-doublons
- triggers auth->profiles
- RLS + policies
- bucket storage prive `songs-private`
- policies storage
- vues dashboard admin
- extensions:
- table `app_settings`
- table `admin_audit_logs`
- RPC `sync_listening_events(jsonb)` pour sync offline par lot
- RPC `admin_set_song_published(...)`
- materialized view `mv_song_stats_daily` + view `admin_song_stats_daily`

## 4. Promouvoir le premier admin

1. Creer un compte via Auth (email/password)
2. Dans `SQL Editor`, executer:

```sql
update public.profiles
set role = 'admin'
where email = 'ton-admin@email.com';
```

Verifier:
```sql
select id, email, role from public.profiles;
```

## 5. Reglages Auth (dashboard)

Dans `Authentication > Providers > Email`:
- `Enable Email provider`: ON
- `Confirm email`: ON (recommande prod)
- `Secure email change`: ON

Dans `Authentication > URL Configuration`:
- `Site URL`:
  - dev web: `http://localhost:5173`
  - prod web: URL finale du dashboard
- `Redirect URLs`:
  - dev web: `http://localhost:5173/**`
  - prod web: `https://ton-admin-web/**`

## 6. Reglages Security recommandes

Dans `Project Settings > API`:
- garder `anon` cote client uniquement
- ne jamais exposer `service_role` dans app mobile ou web

Dans `Auth > Rate Limits`:
- activer/renforcer limites sur sign-in/sign-up (anti-abus)

Dans `Logs`:
- activer surveillance des erreurs Auth et DB

## 7. Reglages Storage

Le script SQL cree deja le bucket prive `songs-private`.

Verification:
```sql
select id, name, public from storage.buckets where id = 'songs-private';
```

Attendu: `public = false`.

## 8. Tests de validation DB

### 8.1 Test user normal
- se connecter avec un user non admin
- verifier:
  - lecture `songs` seulement `is_published = true`
  - impossibilite de modifier `songs`
  - insertion de ses propres `listening_events` possible
  - lecture des events des autres impossible

### 8.2 Test admin
- se connecter admin
- verifier:
  - CRUD complet sur `songs`
  - acces dashboard (`admin_* views`)
  - upload storage bucket `songs-private`

## 9. Parametres DB importants (checklist)

- RLS active sur:
  - `profiles`
  - `songs`
  - `song_downloads`
  - `listening_events`
- Contrainte anti-doublon ecoutes:
  - unique `(user_id, song_id, session_id)`
- Contrainte anti-doublon downloads:
  - unique `(user_id, song_id)`
- Index presents:
  - dates ecoutes
  - filtres par song/user
  - songs publies

## 10. Requetes utiles dashboard

Top songs:
```sql
select * from public.admin_song_stats limit 20;
```

KPI globaux:
```sql
select * from public.admin_dashboard_kpis;
```

Traçabilite detail:
```sql
select * from public.admin_listening_events_detailed limit 100;
```

Refresh stats journalières:
```sql
select public.refresh_song_stats_daily();
```

Sync batch (exemple):
```sql
select public.sync_listening_events(
  '[{"song_id":1,"session_id":"abc","started_at":"2026-03-01T10:00:00Z","ended_at":"2026-03-01T10:00:20Z","seconds_listened":20,"is_offline":true}]'::jsonb
);
```

## 11. Notes importantes

- Le stockage "introuvable dans gestionnaire de fichiers" est gere cote app (sandbox mobile), pas cote Supabase.
- Sur appareil root/jailbreak, l'extraction reste possible: prevoir chiffrement local ulterieur.
- Pour securite maximale des downloads, tu peux migrer vers une Edge Function qui valide les droits avant URL signee.

## 12. Validation terrain

- Script SQL e2e: `supabase/003_e2e_validation.sql`
- Checklist QA mobile/web: `supabase/FIELD_TEST_CHECKLIST.md`
