-- 2Block Music - keep plays after user deletion
-- Execute after 010_add_song_plays_count.sql (and 022 if already run)

begin;

-- Preserve listening events when a profile is deleted
alter table public.listening_events
  alter column user_id drop not null;

alter table public.listening_events
  drop constraint if exists listening_events_user_id_fkey;

alter table public.listening_events
  add constraint listening_events_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

-- Ensure plays_count is not decremented on delete
drop trigger if exists trg_decrement_song_plays_count on public.listening_events;
drop function if exists public.tg_decrement_song_plays_count();

commit;
