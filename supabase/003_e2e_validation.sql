-- 2Block Music - E2E validation SQL
-- Run after:
--   001_init_schema.sql
--   002_schema_extensions.sql
--
-- IMPORTANT:
-- 1) Replace placeholders before execution:
--    :ADMIN_EMAIL
--    :USER_EMAIL
-- 2) This script is READ/VALIDATION oriented (no destructive actions).

-- ---------------------------------------------------------------------------
-- A. Pre-checks schema objects
-- ---------------------------------------------------------------------------
select 'A1_tables' as check_name, t.table_name
from information_schema.tables t
where t.table_schema = 'public'
  and t.table_name in ('profiles', 'songs', 'song_downloads', 'listening_events', 'app_settings', 'admin_audit_logs')
order by t.table_name;

select 'A2_rpcs' as check_name, p.proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('register_song_download', 'sync_listening_events', 'admin_set_song_published', 'refresh_song_stats_daily')
order by p.proname;

select 'A3_views' as check_name, v.table_name
from information_schema.views v
where v.table_schema = 'public'
  and v.table_name in (
    'admin_dashboard_kpis',
    'admin_song_stats',
    'admin_user_activity',
    'admin_listening_events_detailed',
    'admin_song_stats_daily'
  )
order by v.table_name;

select 'A4_mv_exists' as check_name, matviewname
from pg_matviews
where schemaname = 'public'
  and matviewname = 'mv_song_stats_daily';

select 'A5_bucket' as check_name, id, name, public
from storage.buckets
where id = 'songs-private';

-- ---------------------------------------------------------------------------
-- B. Role and profile checks
-- ---------------------------------------------------------------------------
select 'B1_profiles' as check_name, p.id, p.email, p.role, p.created_at
from public.profiles p
where p.email in (':ADMIN_EMAIL', ':USER_EMAIL')
order by p.role desc, p.created_at;

-- Expectation:
-- - ADMIN_EMAIL => role='admin'
-- - USER_EMAIL  => role='user'

-- ---------------------------------------------------------------------------
-- C. Data visibility sanity (run with ADMIN session)
-- ---------------------------------------------------------------------------
select 'C1_songs_count' as check_name, count(*) as total_songs
from public.songs;

select 'C2_downloads_count' as check_name, count(*) as total_downloads
from public.song_downloads;

select 'C3_listening_count' as check_name, count(*) as total_listening_events
from public.listening_events;

select 'C4_kpis' as check_name, *
from public.admin_dashboard_kpis;

select 'C5_top_songs' as check_name, *
from public.admin_song_stats
limit 20;

select 'C6_activity' as check_name, *
from public.admin_listening_events_detailed
limit 50;

-- ---------------------------------------------------------------------------
-- D. RPC functional test (run with USER session)
-- ---------------------------------------------------------------------------
-- 1) Pick an existing published song id (or insert one from admin panel first):
-- select id, title from public.songs where is_published = true order by id limit 5;

-- 2) Register download:
-- select public.register_song_download(1, '1.2.0+2', 'test-device');

-- 3) Sync listening events batch (simulate offline sync):
-- select public.sync_listening_events(
--   '[
--      {
--        "song_id": 1,
--        "session_id": "manual-test-session-001",
--        "started_at": "2026-03-02T12:00:00Z",
--        "ended_at": "2026-03-02T12:00:20Z",
--        "seconds_listened": 20,
--        "is_offline": true
--      }
--    ]'::jsonb
-- );

-- ---------------------------------------------------------------------------
-- E. Post-RPC assertions (run with ADMIN session)
-- ---------------------------------------------------------------------------
select 'E1_downloads_latest' as check_name, d.*
from public.song_downloads d
join public.profiles p on p.id = d.user_id
where p.email = ':USER_EMAIL'
order by d.downloaded_at desc
limit 20;

select 'E2_events_latest' as check_name, le.*
from public.listening_events le
join public.profiles p on p.id = le.user_id
where p.email = ':USER_EMAIL'
order by le.started_at desc
limit 20;

-- Check anti-duplicate constraint by session:
select 'E3_duplicate_sessions' as check_name, le.user_id, le.song_id, le.session_id, count(*) as c
from public.listening_events le
group by le.user_id, le.song_id, le.session_id
having count(*) > 1;

-- ---------------------------------------------------------------------------
-- F. Daily stats refresh and verification (ADMIN)
-- ---------------------------------------------------------------------------
select public.refresh_song_stats_daily();

select 'F1_daily_stats' as check_name, *
from public.admin_song_stats_daily
limit 30;

-- ---------------------------------------------------------------------------
-- G. Audit logs verification (ADMIN)
-- ---------------------------------------------------------------------------
select 'G1_audit_logs' as check_name, *
from public.admin_audit_logs
order by created_at desc
limit 50;

-- ---------------------------------------------------------------------------
-- H. RLS smoke tests (manual)
-- ---------------------------------------------------------------------------
-- Run these manually in SQL editor with user JWT context or from app/web:
-- - USER must NOT insert/update/delete songs
-- - USER must see only own downloads/events
-- - ADMIN sees all.
