-- 2Block Music - realtime play counters on songs
-- Execute after 001_init_schema.sql and 002_schema_extensions.sql

begin;

alter table public.songs
  add column if not exists plays_count bigint not null default 0
  check (plays_count >= 0);

update public.songs s
set plays_count = coalesce(t.plays_count, 0)
from (
  select song_id, count(*)::bigint as plays_count
  from public.listening_events
  group by song_id
) t
where s.id = t.song_id;

create or replace function public.tg_increment_song_plays_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.songs
  set plays_count = coalesce(plays_count, 0) + 1,
      updated_at = now()
  where id = new.song_id;
  return new;
end;
$$;

drop trigger if exists trg_increment_song_plays_count on public.listening_events;
create trigger trg_increment_song_plays_count
after insert on public.listening_events
for each row execute procedure public.tg_increment_song_plays_count();

commit;
