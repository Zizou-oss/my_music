-- 2Block Music - rebuild plays_count from listening_events
-- Execute after 010_add_song_plays_count.sql

begin;

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
