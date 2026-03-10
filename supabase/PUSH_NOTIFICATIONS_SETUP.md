# Push Notifications Setup (Firebase + Supabase)

## 1) Run SQL migration
Execute in Supabase SQL editor:

- `008_push_notifications.sql` (if not already done)
- `009_admin_set_latest_mobile_release.sql`
- `012_security_hardening.sql`

## 2) Deploy Edge Function
From `my_music/`:

```bash
supabase login
supabase link --project-ref yrlxuxpbgazqgdxwvpme
supabase functions deploy push-broadcast
```

## 3) Set required secrets
In Supabase Dashboard -> Edge Functions -> Secrets, add:

- `FCM_PROJECT_ID` = your Firebase project id (example: `block-music-c9930`)
- `FCM_CLIENT_EMAIL` = service account `client_email`
- `FCM_PRIVATE_KEY` = service account `private_key` (keep line breaks as `\n`)
- `ALLOWED_ORIGINS` = comma-separated allowed front origins  
  example: `http://localhost:5173,http://localhost:5174,https://2block-web-ctth.vercel.app`

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically by Supabase.

## 4) Quick test from admin web
1. Login as admin in `music-admin`
2. Create a published song
3. Verify push is received on mobile

## 5) App update flow
In `Settings` page:

1. Enter version (example `1.3.0+3`)
2. Optional notes
3. Click `Publier la mise a jour mobile`

This updates `app_settings.latest_mobile_release` and sends push on topic `app_updates`.
