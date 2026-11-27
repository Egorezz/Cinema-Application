-- Signup trigger: also takes the avatar from OAuth metadata (Google/GitHub: avatar_url, Google also: picture).
-- The avatar is best effort: if it violates the avatar_url check, the profile is created without it
-- (signup must never fail because of a photo URL). The check itself stays the single source of truth.
-- security definer: runs as the auth admin role, which has no rights on public.profiles.
-- Only inserts the new user's own profile from NEW.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_display_name text;
  v_avatar_url   text;
begin
  -- display_name: signup form metadata, then OAuth provider name (full_name / name), then email local part.
  -- btrim after left(): a cut at 50 chars must not leave a trailing space (check constraint).
  v_display_name := btrim(left(coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(btrim(split_part(new.email, '@', 1)), '')
  ), 50));

  v_avatar_url := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'avatar_url'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'picture'), '')
  );

  begin
    insert into public.profiles (id, display_name, avatar_url)
    values (new.id, v_display_name, v_avatar_url)
    on conflict (id) do nothing;
  exception when check_violation then
    -- Most likely the avatar URL; retry without it. A second failure (display_name) propagates as before.
    insert into public.profiles (id, display_name)
    values (new.id, v_display_name)
    on conflict (id) do nothing;
  end;

  return new;
end;
$$;

-- create or replace keeps existing privileges and the trigger; re-assert the revoke for clarity.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
