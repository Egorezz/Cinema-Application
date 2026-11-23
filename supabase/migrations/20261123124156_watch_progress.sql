-- 1.5: watch_progress table

create table public.watch_progress (
  id            bigint generated always as identity primary key,
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  episode_id    bigint references public.episodes (id) on delete cascade,
  title_id      bigint references public.titles (id) on delete cascade,   -- movies only (trigger below)
  position_sec  integer not null default 0 check (position_sec >= 0),
  duration_sec  integer not null check (duration_sec > 0),
  is_finished   boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint watch_progress_exactly_one_target check (num_nonnulls(episode_id, title_id) = 1),
  constraint watch_progress_position_within_duration check (position_sec <= duration_sec),
  -- Upsert conflict targets (NULLs are distinct, so each constraint only binds rows of its kind).
  constraint watch_progress_user_id_episode_id_key unique (user_id, episode_id),
  constraint watch_progress_user_id_title_id_key   unique (user_id, title_id)
);

-- FK indexes: user_id is leading in the unique constraints; episode_id / title_id need their own for cascades.
create index watch_progress_episode_id_idx on public.watch_progress (episode_id);
create index watch_progress_title_id_idx   on public.watch_progress (title_id);

comment on table public.watch_progress is
  'Playback position per user and episode (series) or title (movie). Upsert on (user_id, episode_id) / (user_id, title_id).';

-- Progress may target only a published episode (series) or a published movie title.
-- Missing / draft / non-movie targets raise one and the same error, so a draft's existence or type is not revealed.
-- Also clamps position_sec to duration_sec (the CHECK stays as a safety net).
-- security definer: must see parent titles regardless of caller RLS (draft titles); only reads and raises.
create or replace function public.watch_progress_check_target()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.position_sec := least(new.position_sec, new.duration_sec);

  if new.episode_id is not null and not exists (
    select 1 from public.episodes e
    join public.seasons s on s.id = e.season_id
    join public.titles t on t.id = s.title_id
    where e.id = new.episode_id and t.is_published
  ) then
    raise exception 'watch progress target is not available' using errcode = 'foreign_key_violation';
  end if;

  if new.title_id is not null and not exists (
    select 1 from public.titles t
    where t.id = new.title_id and t.type = 'movie' and t.is_published
  ) then
    raise exception 'watch progress target is not available' using errcode = 'foreign_key_violation';
  end if;

  return new;
end;
$$;

revoke execute on function public.watch_progress_check_target() from public, anon, authenticated;

create trigger watch_progress_check_target
  before insert or update on public.watch_progress
  for each row execute function public.watch_progress_check_target();

-- A title's type may not change while children depend on it: seasons need a series (1.2),
-- direct video sources (1.3) and watch progress (1.5) need a movie. Otherwise those rows would silently become unreachable.
-- security definer: must see child rows regardless of caller RLS (draft titles); only checks existence and raises.
create or replace function public.titles_check_type_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.type is distinct from old.type and (
    exists (select 1 from public.seasons s where s.title_id = new.id)
    or exists (select 1 from public.video_sources v where v.title_id = new.id)
    or exists (select 1 from public.watch_progress w where w.title_id = new.id)
  ) then
    raise exception 'title % type cannot change while it has seasons, video sources or watch progress', new.id
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger watch_progress_set_updated_at before update on public.watch_progress
  for each row execute function public.set_updated_at();

alter table public.watch_progress enable row level security;

create policy "watch_progress_select_own" on public.watch_progress
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "watch_progress_insert_own" on public.watch_progress
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "watch_progress_update_own" on public.watch_progress
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "watch_progress_delete_own" on public.watch_progress
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Clients write only the progress columns; id/created_at/updated_at stay server-managed.
-- PostgREST upsert (merge-duplicates) sets every payload column in DO UPDATE, so update is granted on the same set.
revoke insert, update, truncate, references, trigger on public.watch_progress from anon, authenticated;
revoke select, delete on public.watch_progress from anon;
grant insert (user_id, episode_id, title_id, position_sec, duration_sec, is_finished) on public.watch_progress to authenticated;
grant update (user_id, episode_id, title_id, position_sec, duration_sec, is_finished) on public.watch_progress to authenticated;
