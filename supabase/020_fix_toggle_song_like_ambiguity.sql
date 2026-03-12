-- 2Block Music - fix ambiguous song_id reference in toggle_song_like
-- Execute after 018_song_likes_comments.sql

begin;

drop function if exists public.toggle_song_like(bigint);
create or replace function public.toggle_song_like(
  p_song_id bigint
)
returns table (
  song_id bigint,
  liked boolean,
  likes_count bigint,
  comments_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_liked boolean;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.songs s
    where s.id = p_song_id
      and (s.is_published = true or public.is_admin())
  ) then
    raise exception 'Song not found';
  end if;

  if exists (
    select 1
    from public.song_likes sl
    where sl.song_id = p_song_id
      and sl.user_id = v_user_id
  ) then
    delete from public.song_likes sl
    where sl.song_id = p_song_id
      and sl.user_id = v_user_id;
    v_liked := false;
  else
    insert into public.song_likes (song_id, user_id)
    values (p_song_id, v_user_id);
    v_liked := true;
  end if;

  return query
  select
    p_song_id,
    v_liked,
    (
      select count(*)::bigint
      from public.song_likes sl
      where sl.song_id = p_song_id
    ),
    (
      select count(*)::bigint
      from public.song_comments sc
      where sc.song_id = p_song_id
    );
end;
$$;

revoke execute on function public.toggle_song_like(bigint) from public;
grant execute on function public.toggle_song_like(bigint) to authenticated;

commit;
