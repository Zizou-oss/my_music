-- 2Block Music - admin RPC to publish latest mobile release metadata
-- Execute after 001_init_schema.sql and 002_schema_extensions.sql

begin;

create or replace function public.admin_set_latest_mobile_release(
  p_version text,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_version text;
  v_notes text;
begin
  if not public.is_admin() then
    raise exception 'Forbidden';
  end if;

  v_version := trim(coalesce(p_version, ''));
  if v_version = '' then
    raise exception 'Version is required';
  end if;

  v_notes := nullif(trim(coalesce(p_notes, '')), '');

  insert into public.app_settings(key, value, updated_at)
  values (
    'latest_mobile_release',
    jsonb_build_object(
      'version', v_version,
      'notes', v_notes,
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

grant execute on function public.admin_set_latest_mobile_release(text, text) to authenticated;

commit;
