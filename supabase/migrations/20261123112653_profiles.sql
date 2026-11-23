-- 1.4: profiles table, signup trigger, is_admin()

create table public.profiles (
  id                     uuid primary key references auth.users (id) on delete cascade,
  display_name           text check (display_name = btrim(display_name) and char_length(display_name) between 1 and 50),
  avatar_url             text check (avatar_url ~* '^https?://\S+$'),
  role                   text not null default 'user' check (role in ('user', 'admin')),
  notifications_enabled  boolean not null default true,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

comment on table public.profiles is
  'App profile, 1:1 with auth.users; created by trigger on signup. role is changed only by service role / SQL.';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Signup trigger. security definer: runs as the auth admin role, which has no rights on public.profiles.
-- Only inserts the new user's own profile from NEW.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- display_name: signup form metadata, then OAuth provider name (full_name / name), then email local part.
  -- btrim after left(): a cut at 50 chars must not leave a trailing space (check constraint).
  insert into public.profiles (id, display_name)
  values (
    new.id,
    btrim(left(coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
      nullif(btrim(split_part(new.email, '@', 1)), '')
    ), 50))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill users that signed up before this migration (idempotent; no-op on a fresh db).
insert into public.profiles (id, display_name)
select u.id, btrim(left(coalesce(
  nullif(btrim(u.raw_user_meta_data ->> 'display_name'), ''),
  nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
  nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
  nullif(btrim(split_part(u.email, '@', 1)), '')
), 50))
from auth.users u
on conflict (id) do nothing;

-- Admin check for RLS / Edge Functions.
-- security definer: must read the caller's role even though profiles RLS is owner-only and to avoid
-- policy recursion when profiles/other policies call it. Reads only the caller's own row.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select p.role = 'admin' from public.profiles p where p.id = (select auth.uid())),
    false
  );
$$;

revoke execute on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated, service_role;

alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);

create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- No insert/delete policies: profiles are created by the trigger and removed by the auth.users cascade.
-- Column-level privileges: clients may update only these columns; role/id/created_at stay server-only.
-- truncate bypasses RLS, references/trigger are never needed by clients.
revoke insert, update, delete, truncate, references, trigger on public.profiles from anon, authenticated;
grant update (display_name, avatar_url, notifications_enabled) on public.profiles to authenticated;
