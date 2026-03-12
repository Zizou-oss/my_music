-- 2Block Music - keep plays_count in sync on listening_events delete
-- Execute after 010_add_song_plays_count.sql

begin;

create or replace function public.tg_decrement_song_plays_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.songs
  set plays_count = greatest(coalesce(plays_count, 0) - 1, 0),
      updated_at = now()
  where id = old.song_id;
  return old;
end;
$$;

drop trigger if exists trg_decrement_song_plays_count on public.listening_events;
create trigger trg_decrement_song_plays_count
after delete on public.listening_events
for each row execute procedure public.tg_decrement_song_plays_count();

-- Resync counts for existing data
update public.songs s
set plays_count = coalesce(t.plays_count, 0),
    updated_at = now()
from (
  select song_id, count(*)::bigint as plays_count
  from public.listening_events
  group by song_id
) t
where s.id = t.song_id;

update public.songs
set plays_count = 0,
    updated_at = now()
where id not in (select distinct song_id from public.listening_events);

commit;
