-- 1.2: seasons and episodes tables

create table public.seasons (
  id            bigint generated always as identity primary key,
  title_id      bigint not null references public.titles (id) on delete cascade,
  season_number smallint not null check (season_number >= 0),  -- 0 = TMDB "Specials"
  name          text,
  poster_path   text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint seasons_title_id_season_number_key unique (title_id, season_number)
);

create table public.episodes (
  id              bigint generated always as identity primary key,
  season_id       bigint not null references public.seasons (id) on delete cascade,
  episode_number  smallint not null check (episode_number >= 1),
  name            text,
  overview        text,
  air_date        date,
  still_path      text,
  runtime         smallint check (runtime > 0),                 -- minutes
  tmdb_episode_id integer unique,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint episodes_season_id_episode_number_key unique (season_id, episode_number)
);

-- FK indexes: title_id / season_id are the leading columns of the composite unique constraints above.

comment on table public.seasons  is 'Seasons of series titles. season_number 0 = specials (TMDB).';
comment on table public.episodes is 'Episodes of a season. runtime in minutes; tmdb_episode_id is globally unique in TMDB.';

-- Seasons may belong only to series titles.
-- security definer: the check must see the parent title regardless of the caller's RLS visibility
-- (e.g. a draft title); it only reads titles.type and raises, never returns data.
-- A missing title is left to the FK (23503).
create or replace function public.seasons_check_series_title()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.titles t
    where t.id = new.title_id and t.type <> 'series'
  ) then
    raise exception 'season % references title % which is not a series', new.season_number, new.title_id
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger seasons_check_series_title
  before insert or update of title_id on public.seasons
  for each row execute function public.seasons_check_series_title();

create trigger seasons_set_updated_at  before update on public.seasons
  for each row execute function public.set_updated_at();
create trigger episodes_set_updated_at before update on public.episodes
  for each row execute function public.set_updated_at();

alter table public.seasons  enable row level security;
alter table public.episodes enable row level security;

-- Write policies (admin only) are added in 1.4/1.9 once public.is_admin() exists.
create policy "seasons_select_published" on public.seasons
  for select to anon, authenticated
  using (exists (
    select 1 from public.titles t
    where t.id = seasons.title_id and t.is_published
  ));

create policy "episodes_select_published" on public.episodes
  for select to anon, authenticated
  using (exists (
    select 1 from public.seasons s
    join public.titles t on t.id = s.title_id
    where s.id = episodes.season_id and t.is_published
  ));
