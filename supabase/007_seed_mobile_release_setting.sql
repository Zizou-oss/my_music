-- 2Block Music - seed app update notification setting
-- Execute after 001_init_schema.sql and 002_schema_extensions.sql

begin;

insert into public.app_settings (key, value)
values (
  'latest_mobile_release',
  jsonb_build_object(
    'version', '1.2.0+2',
    'title', 'Mise a jour disponible',
    'message', 'Une nouvelle version de 2Block Music est disponible.'
  )
)
on conflict (key) do nothing;

commit;

