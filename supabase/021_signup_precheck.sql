-- 2Block Music - signup availability precheck (email + full_name)
-- Execute after 001_init_schema.sql and 006_add_profile_full_name.sql

begin;

create or replace function public.check_signup_availability(
  p_email text,
  p_full_name text default null
)
returns table (
  email_taken boolean,
  full_name_taken boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_full_name text;
begin
  v_email := lower(trim(coalesce(p_email, '')));
  v_full_name := nullif(trim(coalesce(p_full_name, '')), '');

  email_taken := false;
  full_name_taken := false;

  if v_email <> '' then
    email_taken := exists (
      select 1
      from public.profiles p
      where lower(p.email) = v_email
    );
  end if;

  if v_full_name is not null then
    full_name_taken := exists (
      select 1
      from public.profiles p
      where lower(p.full_name) = lower(v_full_name)
    );
  end if;

  return next;
end;
$$;

revoke execute on function public.check_signup_availability(text, text) from public;
grant execute on function public.check_signup_availability(text, text) to anon, authenticated;

commit;
