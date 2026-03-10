-- 2Block Music - add full_name on profiles for signup
-- Execute after 001_init_schema.sql

begin;

alter table public.profiles
  add column if not exists full_name text;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role, full_name)
  values (
    new.id,
    coalesce(new.email, ''),
    'user',
    nullif(trim(coalesce(new.raw_user_meta_data->>'full_name', '')), '')
  )
  on conflict (id) do update
  set email = excluded.email,
      full_name = coalesce(excluded.full_name, public.profiles.full_name);

  return new;
end;
$$;

create or replace function public.handle_user_email_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set email = coalesce(new.email, ''),
      full_name = coalesce(
        nullif(trim(coalesce(new.raw_user_meta_data->>'full_name', '')), ''),
        public.profiles.full_name
      )
  where id = new.id;

  return new;
end;
$$;

commit;
