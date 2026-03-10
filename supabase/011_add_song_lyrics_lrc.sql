-- 2Block Music - add synchronized lyrics (LRC) support
-- Execute after 001_init_schema.sql

begin;

alter table public.songs
  add column if not exists lyrics_lrc text;

commit;

