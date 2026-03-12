-- 2Block Music - daily aggregates for listening events (stable charts)
-- Execute after 001_init_schema.sql and 010_add_song_plays_count.sql

begin;

create table if not exists public.listening_events_daily (
  day date not null,
  song_id bigint not null references public.songs(id) on delete cascade,
  plays_count bigint not null default 0,
  seconds_total bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (day, song_id)
);

create index if not exists idx_listening_events_daily_day
  on public.listening_events_daily(day desc);

create or replace function public.tg_upsert_listening_events_daily()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day date;
begin
  v_day := (new.started_at at time zone 'utc')::date;
  insert into public.listening_events_daily (
    day, song_id, plays_count, seconds_total, updated_at
  )
  values (
    v_day, new.song_id, 1, new.seconds_listened, now()
  )
  on conflict (day, song_id)
  do update set
    plays_count = public.listening_events_daily.plays_count + 1,
    seconds_total = public.listening_events_daily.seconds_total + excluded.seconds_total,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_upsert_listening_events_daily on public.listening_events;
create trigger trg_upsert_listening_events_daily
after insert on public.listening_events
for each row execute procedure public.tg_upsert_listening_events_daily();

-- Backfill from existing listening_events
insert into public.listening_events_daily (
  day, song_id, plays_count, seconds_total, created_at, updated_at
)
select
  (le.started_at at time zone 'utc')::date as day,
  le.song_id,
  count(*)::bigint as plays_count,
  coalesce(sum(le.seconds_listened), 0)::bigint as seconds_total,
  now(),
  now()
from public.listening_events le
group by (le.started_at at time zone 'utc')::date, le.song_id
on conflict (day, song_id)
do update set
  plays_count = excluded.plays_count,
  seconds_total = excluded.seconds_total,
  updated_at = now();

create or replace view public.admin_listening_events_daily as
select
  led.day,
  led.song_id,
  s.title as song_title,
  s.artist as song_artist,
  led.plays_count,
  led.seconds_total
from public.listening_events_daily led
join public.songs s on s.id = led.song_id
where public.is_admin()
order by led.day desc;

commit;
