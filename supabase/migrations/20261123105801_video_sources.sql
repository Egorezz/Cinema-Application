-- 1.3: video_sources table

create table public.video_sources (
  id          bigint generated always as identity primary key,
  episode_id  bigint references public.episodes (id) on delete cascade,
  title_id    bigint references public.titles (id) on delete cascade,  -- movies only (trigger below)
  url         text not null check (url ~* '^https?://\S+$'),
  format      text not null check (format in ('hls', 'mp4')),
  quality     text check (quality ~ '\S'),                 -- free label: '1080p', '720p', 'auto'
  language    text check (language ~ '^[a-z]{2,3}$'),      -- ISO 639-1/2 audio language: 'ru', 'en'
  priority    smallint not null default 0 check (priority >= 0),  -- lower = tried first
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint video_sources_exactly_one_parent check (num_nonnulls(episode_id, title_id) = 1),
  constraint video_sources_episode_id_url_key unique (episode_id, url),
  constraint video_sources_title_id_url_key   unique (title_id, url)
);

-- FK indexes: episode_id / title_id are the leading columns of the unique constraints above.

comment on table public.video_sources is
  'Playable links of an episode (series) or a title (movie). Player tries active sources by priority asc, then id asc.';

-- Movie sources may reference only movie titles (series sources go via episode_id).
-- security definer: must see the parent title regardless of caller RLS (draft titles); only reads titles.type and raises.
-- A missing title is left to the FK (23503).
create or replace function public.video_sources_check_movie_title()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.title_id is not null and exists (
    select 1 from public.titles t
    where t.id = new.title_id and t.type <> 'movie'
  ) then
    raise exception 'video source references title % which is not a movie', new.title_id
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger video_sources_check_movie_title
  before insert or update of title_id on public.video_sources
  for each row execute function public.video_sources_check_movie_title();

-- A title's type may not change while children depend on it: seasons need a series (1.2),
-- direct video sources need a movie (above). Otherwise those rows would silently become unreachable.
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
  ) then
    raise exception 'title % type cannot change while it has seasons or video sources', new.id
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger titles_check_type_change
  before update of type on public.titles
  for each row execute function public.titles_check_type_change();

create trigger video_sources_set_updated_at before update on public.video_sources
  for each row execute function public.set_updated_at();

alter table public.video_sources enable row level security;

-- Write policies (admin only) are added in 1.4/1.9 once public.is_admin() exists.
-- Anon never sees links (card 1.9 DoD); inactive sources are hidden from users.
create policy "video_sources_select_published" on public.video_sources
  for select to authenticated
  using (
    is_active
    and (
      exists (
        select 1 from public.titles t
        where t.id = video_sources.title_id and t.is_published
      )
      or exists (
        select 1 from public.episodes e
        join public.seasons s on s.id = e.season_id
        join public.titles t on t.id = s.title_id
        where e.id = video_sources.episode_id and t.is_published
      )
    )
  );
