-- 2Block Music - security hardening (RPC permissions + guardrails)
-- Execute after 001_init_schema.sql ... 011_add_song_lyrics_lrc.sql

begin;

-- ---------------------------------------------------------------------------
-- Restrict RPC execution to authenticated users only
-- ---------------------------------------------------------------------------
revoke execute on function public.register_song_download(bigint, text, text) from public;
revoke execute on function public.sync_listening_events(jsonb) from public;
revoke execute on function public.admin_set_song_published(bigint, boolean) from public;
revoke execute on function public.refresh_song_stats_daily() from public;
revoke execute on function public.register_push_token(text, text, text) from public;
revoke execute on function public.unregister_push_token(text) from public;
revoke execute on function public.admin_set_latest_mobile_release(text, text) from public;

grant execute on function public.register_song_download(bigint, text, text) to authenticated;
grant execute on function public.sync_listening_events(jsonb) to authenticated;
grant execute on function public.admin_set_song_published(bigint, boolean) to authenticated;
grant execute on function public.refresh_song_stats_daily() to authenticated;
grant execute on function public.register_push_token(text, text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;
grant execute on function public.admin_set_latest_mobile_release(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Harden refresh RPC: deny anon/no-JWT calls, keep SQL editor/service access
-- ---------------------------------------------------------------------------
create or replace function public.refresh_song_stats_daily()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  v_role := current_setting('request.jwt.claim.role', true);

  -- Direct SQL editor / service context can have no JWT claims.
  if v_role is null then
    if session_user not in (
      'postgres',
      'service_role',
      'supabase_admin',
      'supabase_functions_admin',
      'supabase_auth_admin'
    ) then
      raise exception 'Forbidden';
    end if;
  elsif not public.is_admin() then
    raise exception 'Forbidden';
  end if;

  refresh materialized view concurrently public.mv_song_stats_daily;
end;
$$;

-- ---------------------------------------------------------------------------
-- Push token validation hardening
-- ---------------------------------------------------------------------------
alter table public.push_tokens
  drop constraint if exists push_tokens_token_length_check;

alter table public.push_tokens
  add constraint push_tokens_token_length_check
  check (length(trim(token)) between 32 and 4096);

alter table public.push_tokens
  drop constraint if exists push_tokens_platform_check;

alter table public.push_tokens
  add constraint push_tokens_platform_check
  check (platform in ('android', 'ios', 'web', 'unknown'));

create or replace function public.register_push_token(
  p_token text,
  p_platform text default 'unknown',
  p_app_version text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
  v_platform text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_token := trim(coalesce(p_token, ''));
  if length(v_token) < 32 or length(v_token) > 4096 then
    raise exception 'Invalid token format';
  end if;

  v_platform := lower(trim(coalesce(p_platform, 'unknown')));
  if v_platform = '' then
    v_platform := 'unknown';
  end if;
  if v_platform not in ('android', 'ios', 'web', 'unknown') then
    v_platform := 'unknown';
  end if;

  insert into public.push_tokens (
    user_id,
    token,
    platform,
    app_version,
    is_active,
    updated_at
  )
  values (
    auth.uid(),
    v_token,
    v_platform,
    p_app_version,
    true,
    now()
  )
  on conflict (token)
  do update set
    user_id = auth.uid(),
    platform = excluded.platform,
    app_version = excluded.app_version,
    is_active = true,
    updated_at = now();
end;
$$;

grant execute on function public.register_push_token(text, text, text) to authenticated;

commit;
