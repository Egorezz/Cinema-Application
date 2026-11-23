-- 1.1: titles table + shared updated_at trigger function

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create table public.titles (
  id             bigint generated always as identity primary key,
  tmdb_id        integer,
  tvmaze_id      integer unique,
  type           text not null check (type in ('movie', 'series')),
  title          text not null check (title ~ '\S'),
  original_title text,
  overview       text,
  poster_path    text,
  backdrop_path  text,
  year           smallint check (year between 1888 and 2100),
  genres         text[] not null default '{}',
  rating         numeric(3, 1) check (rating between 0 and 10),
  status         text check (status in (
                   'rumored', 'planned', 'pilot', 'in_production', 'post_production',
                   'released', 'returning', 'ended', 'canceled')),
  is_published   boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint titles_type_tmdb_id_key unique (type, tmdb_id),
  constraint titles_tvmaze_only_series check (tvmaze_id is null or type = 'series')
);

comment on table public.titles is 'Catalog titles (movies and series). Metadata from TMDB, episode schedule from TVMaze.';
comment on column public.titles.tmdb_id is 'TMDB id; movie and tv ids are separate namespaces in TMDB, hence unique per type.';

create trigger titles_set_updated_at
  before update on public.titles
  for each row execute function public.set_updated_at();

alter table public.titles enable row level security;

-- Write policies (admin only) are added in 1.4/1.9 once public.is_admin() exists.
create policy "titles_select_published" on public.titles
  for select to anon, authenticated
  using (is_published);
