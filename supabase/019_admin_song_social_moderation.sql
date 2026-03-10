-- 2Block Music - admin moderation access for song social data
-- Execute after 018_song_likes_comments.sql

begin;

drop policy if exists "song_comments_admin_select" on public.song_comments;
create policy "song_comments_admin_select"
on public.song_comments
for select
to authenticated
using (public.is_admin());

drop policy if exists "song_likes_admin_select" on public.song_likes;
create policy "song_likes_admin_select"
on public.song_likes
for select
to authenticated
using (public.is_admin());

commit;
