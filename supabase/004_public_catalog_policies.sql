-- 2Block Music - public catalog read policies
-- Execute after 001_init_schema.sql and 002_schema_extensions.sql

begin;

-- Replace old policy (authenticated only)
drop policy if exists "songs_select_published_or_admin" on public.songs;

-- Unauthenticated users can browse published songs only.
drop policy if exists "songs_select_published_anon" on public.songs;
create policy "songs_select_published_anon"
on public.songs
for select
to anon
using (is_published = true);

-- Authenticated users can browse published songs; admins can see all songs.
drop policy if exists "songs_select_published_or_admin_auth" on public.songs;
create policy "songs_select_published_or_admin_auth"
on public.songs
for select
to authenticated
using (is_published = true or public.is_admin());

commit;

