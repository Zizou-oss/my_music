-- 2Block Music - align admin views with persistent plays_count
-- Execute after 001_init_schema.sql and 010_add_song_plays_count.sql

begin;

create or replace view public.admin_dashboard_kpis as
select
  (select coalesce(sum(s.plays_count), 0)::bigint from public.songs s where public.is_admin()) as total_events,
  (select count(distinct user_id) from public.listening_events where public.is_admin()) as unique_users,
  (select coalesce(sum(seconds_listened), 0) from public.listening_events where public.is_admin()) as total_seconds,
  (select count(*) from public.song_downloads where public.is_admin()) as total_downloads;

create or replace view public.admin_song_stats as
select
  s.id as song_id,
  s.title,
  s.artist,
  coalesce(s.plays_count, 0) as plays_count,
  count(distinct le.user_id) as listeners_count,
  coalesce(sum(le.seconds_listened), 0) as seconds_total
from public.songs s
left join public.listening_events le on le.song_id = s.id
where public.is_admin()
group by s.id, s.title, s.artist, s.plays_count
order by plays_count desc, seconds_total desc;

create or replace view public.admin_listening_events_detailed as
select
  le.id,
  le.user_id,
  coalesce(p.email, 'Compte supprim\u00e9') as user_email,
  le.song_id,
  s.title as song_title,
  s.artist as song_artist,
  le.session_id,
  le.started_at,
  le.ended_at,
  le.seconds_listened,
  le.is_offline,
  le.created_at
from public.listening_events le
left join public.profiles p on p.id = le.user_id
join public.songs s on s.id = le.song_id
where public.is_admin()
order by le.started_at desc;

commit;
