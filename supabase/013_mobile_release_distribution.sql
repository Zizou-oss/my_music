-- 2Block Music - mobile release distribution metadata
-- Execute after 009_admin_set_latest_mobile_release.sql and 012_security_hardening.sql

begin;

drop function if exists public.admin_set_mobile_release_distribution(text, text, text, text, bigint);

create or replace function public.admin_set_mobile_release_distribution(
  p_version text,
  p_notes text default null,
  p_download_url text default null,
  p_apk_sha256 text default null,
  p_apk_size_bytes bigint default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_version text;
  v_notes text;
  v_download_url text;
  v_apk_sha256 text;
begin
  if not public.is_admin() then
    raise exception 'Forbidden';
  end if;

  v_version := trim(coalesce(p_version, ''));
  if v_version = '' then
    raise exception 'Version is required';
  end if;

  v_notes := nullif(trim(coalesce(p_notes, '')), '');
  v_download_url := nullif(trim(coalesce(p_download_url, '')), '');
  if v_download_url is not null and v_download_url !~* '^https://.+' then
    raise exception 'download_url must start with https://';
  end if;

  v_apk_sha256 := lower(nullif(trim(coalesce(p_apk_sha256, '')), ''));
  if v_apk_sha256 is not null and v_apk_sha256 !~ '^[a-f0-9]{64}$' then
    raise exception 'apk_sha256 must be a 64-char hex sha256';
  end if;

  if p_apk_size_bytes is not null and p_apk_size_bytes <= 0 then
    raise exception 'apk_size_bytes must be positive';
  end if;

  insert into public.app_settings(key, value, updated_at)
  values (
    'latest_mobile_release',
    jsonb_build_object(
      'version', v_version,
      'notes', v_notes,
      'download_url', v_download_url,
      'apk_sha256', v_apk_sha256,
      'apk_size_bytes', p_apk_size_bytes,
      'updated_at', now()
    ),
    now()
  )
  on conflict (key)
  do update set
    value = excluded.value,
    updated_at = now();
end;
$$;

revoke execute on function public.admin_set_mobile_release_distribution(text, text, text, text, bigint) from public;
grant execute on function public.admin_set_mobile_release_distribution(text, text, text, text, bigint) to authenticated;

commit;
