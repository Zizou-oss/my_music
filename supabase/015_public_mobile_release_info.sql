-- 2Block Music - public mobile release info
-- Execute after 013_mobile_release_distribution.sql

begin;

create or replace function public.get_public_mobile_release_info()
returns table (
  version text,
  notes text,
  published_at timestamptz,
  apk_size_bytes bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    value->>'version' as version,
    value->>'notes' as notes,
    coalesce(
      (value->>'updated_at')::timestamptz,
      updated_at
    ) as published_at,
    nullif(value->>'apk_size_bytes', '')::bigint as apk_size_bytes
  from public.app_settings
  where key = 'latest_mobile_release'
  limit 1;
$$;

revoke execute on function public.get_public_mobile_release_info() from public;
grant execute on function public.get_public_mobile_release_info() to anon, authenticated;

commit;
