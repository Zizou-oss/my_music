-- 2Block Music - add lyrics support on songs
-- Execute after 001_init_schema.sql

begin;

alter table public.songs
  add column if not exists lyrics text;

commit;

