-- Genres reference table: TMDB genre ids with Russian display names.
-- titles.genres (localized text) is replaced by titles.genre_ids (TMDB ids).

create table public.genres (
  id          integer primary key,                      -- TMDB genre id (movie and tv lists share the id space)
  name        text not null unique check (name ~ '\S'), -- Russian display name
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger genres_set_updated_at before update on public.genres
  for each row execute function public.set_updated_at();

alter table public.genres enable row level security;

create policy "genres_select_all" on public.genres
  for select to anon, authenticated using (true);

revoke insert, update, delete, truncate, references, trigger on public.genres from anon, authenticated;

insert into public.genres (id, name) values
  -- movie
  (28, 'Боевик'),
  (12, 'Приключения'),
  (16, 'Мультфильм'),
  (35, 'Комедия'),
  (80, 'Криминал'),
  (99, 'Документальный'),
  (18, 'Драма'),
  (10751, 'Семейный'),
  (14, 'Фэнтези'),
  (36, 'История'),
  (27, 'Ужасы'),
  (10402, 'Музыка'),
  (9648, 'Детектив'),
  (10749, 'Мелодрама'),
  (878, 'Фантастика'),
  (10770, 'Телевизионный фильм'),
  (53, 'Триллер'),
  (10752, 'Военный'),
  (37, 'Вестерн'),
  -- tv only
  (10759, 'Боевик и приключения'),
  (10762, 'Детский'),
  (10763, 'Новости'),
  (10764, 'Реалити-шоу'),
  (10765, 'НФ и фэнтези'),
  (10766, 'Мыльная опера'),
  (10767, 'Ток-шоу'),
  (10768, 'Война и политика');

alter table public.titles add column genre_ids integer[] not null default '{}';

-- Convert existing rows in one statement (independent of how the runner batches transactions).
-- Lookup = genres.name (ru) + English names + ru aliases (temporary, not stored).
-- Names without a TMDB match are dropped for good (reported by a notice): the old column is removed below.
do $$
declare v_dropped text;
begin
  create temporary table genre_lookup (id integer, label text);
  insert into genre_lookup select id, name from public.genres;
  insert into genre_lookup values
    (28, 'Action'),
    (12, 'Adventure'),
    (16, 'Animation'),
    (35, 'Comedy'),
    (80, 'Crime'),
    (99, 'Documentary'),
    (18, 'Drama'),
    (10751, 'Family'),
    (14, 'Fantasy'),
    (36, 'History'),
    (27, 'Horror'),
    (10402, 'Music'),
    (9648, 'Mystery'),
    (10749, 'Romance'),
    (878, 'Science Fiction'),
    (10770, 'TV Movie'),
    (53, 'Thriller'),
    (10752, 'War'),
    (37, 'Western'),
    (10759, 'Action & Adventure'),
    (10762, 'Kids'),
    (10763, 'News'),
    (10764, 'Reality'),
    (10765, 'Sci-Fi & Fantasy'),
    (10766, 'Soap'),
    (10767, 'Talk'),
    (10768, 'War & Politics'),
    (16, 'Анимация');                                      -- ru alias used by the 1.11 seed

  update public.titles t
     set genre_ids = coalesce(array(
           select distinct l.id from unnest(t.genres) g(n)
             join genre_lookup l on lower(btrim(l.label)) = lower(btrim(g.n))
            order by l.id), '{}')
   where cardinality(t.genres) > 0;

  select string_agg(distinct g.n, ', ') into v_dropped
    from public.titles t, unnest(t.genres) g(n)
   where not exists (select 1 from genre_lookup l where lower(btrim(l.label)) = lower(btrim(g.n)));
  if v_dropped is not null then
    raise notice 'genres dropped during conversion (no TMDB match): %', v_dropped;
  end if;

  drop table genre_lookup;
end $$;

alter table public.titles drop column genres;

create index titles_genre_ids_idx on public.titles using gin (genre_ids);

-- Integrity: every id in titles.genre_ids must exist in genres (arrays cannot carry an FK).
-- security invoker is enough: genres is readable by every role that can write titles.
create or replace function public.titles_check_genre_ids()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if exists (select 1 from unnest(new.genre_ids) g(id)
             where not exists (select 1 from public.genres x where x.id = g.id)) then
    raise exception 'unknown genre id in %', new.genre_ids using errcode = 'foreign_key_violation';
  end if;
  return new;
end;
$$;

revoke execute on function public.titles_check_genre_ids() from public, anon, authenticated;

create trigger titles_check_genre_ids before insert or update of genre_ids on public.titles
  for each row execute function public.titles_check_genre_ids();

-- Integrity from the other side: a genre id still used by a title cannot be deleted or renumbered.
-- security invoker is enough: clients have no write grants on genres (only migrations / service role write it).
create or replace function public.genres_check_not_in_use()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.id = old.id then
    return new;
  end if;
  if exists (select 1 from public.titles t where t.genre_ids @> array[old.id]) then
    raise exception 'genre % is still used by titles', old.id using errcode = 'foreign_key_violation';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke execute on function public.genres_check_not_in_use() from public, anon, authenticated;

create trigger genres_check_not_in_use before delete or update of id on public.genres
  for each row execute function public.genres_check_not_in_use();
