-- Genres of a title: many-to-many titles ↔ genres (replaces titles.genre_ids from 20261124151304_genres.sql).
create table public.title_genres (
  title_id    bigint  not null references public.titles (id) on delete cascade,
  genre_id    integer not null references public.genres (id) on delete restrict on update restrict,
  primary key (title_id, genre_id)
);
-- Pure junction table: keys only, no created_at/updated_at (rows are never updated; see supabase-database.md).

-- title_id is leading in the PK; genre_id needs its own index (FK restrict checks, "titles by genre" lookups).
create index title_genres_genre_id_idx on public.title_genres (genre_id);

comment on table public.title_genres is
  'Genres of a title (TMDB genre ids). Replace a title''s set with set_title_genres(); PostgREST embed: titles?select=*,genres(id,name).';

-- Data: copy existing arrays (distinct, only ids known to genres — the old trigger guaranteed that).
insert into public.title_genres (title_id, genre_id)
select distinct t.id, g.id
  from public.titles t
  cross join lateral unnest(t.genre_ids) as g(id)
on conflict do nothing;

drop trigger titles_check_genre_ids on public.titles;
drop function public.titles_check_genre_ids();
drop trigger genres_check_not_in_use on public.genres;
drop function public.genres_check_not_in_use();
alter table public.titles drop column genre_ids;   -- drops titles_genre_ids_idx with it

alter table public.title_genres enable row level security;

create policy "title_genres_select_published_or_admin" on public.title_genres
  for select to anon, authenticated
  using (
    exists (select 1 from public.titles t where t.id = title_genres.title_id and t.is_published)
    or (select public.is_admin())
  );
-- Clients never write directly: every write goes through set_title_genres(), which serializes per title.
-- Direct writes would bypass that lock and could mix two genre sets. Truncate bypasses RLS.
revoke insert, update, delete, truncate, references, trigger on public.title_genres from anon, authenticated;

-- Atomically replaces the genre set of a title (import-title 2.1 / 2.6, admin UI 8.x). The only write path.
-- security definer: clients have no write grants on title_genres. Guard fails closed: only an admin session
-- or a service-role JWT may proceed (postgres without a JWT is rejected too; seed/migrations insert directly).
create or replace function public.set_title_genres(p_title_id bigint, p_genre_ids integer[])
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not (coalesce((select auth.role()) = 'service_role', false) or (select public.is_admin())) then
    raise exception 'only admins can change title genres' using errcode = 'insufficient_privilege';
  end if;

  if p_genre_ids is null or exists (select 1 from unnest(p_genre_ids) as g(id) where g.id is null) then
    raise exception 'genre ids must be a non-null array without nulls' using errcode = 'invalid_parameter_value';
  end if;

  -- Locks the title row: concurrent calls for the same title are serialized (no mixed sets).
  -- "no key update" does not block FK key-share locks from other child tables.
  perform 1 from public.titles t where t.id = p_title_id for no key update;
  if not found then
    raise exception 'title % not found', p_title_id using errcode = 'foreign_key_violation';
  end if;

  delete from public.title_genres tg
   where tg.title_id = p_title_id
     and tg.genre_id <> all (p_genre_ids);

  insert into public.title_genres (title_id, genre_id)
  select distinct p_title_id, g.id from unnest(p_genre_ids) as g(id)
  on conflict (title_id, genre_id) do nothing;
end;
$$;

revoke execute on function public.set_title_genres(bigint, integer[]) from public, anon, authenticated;
grant execute on function public.set_title_genres(bigint, integer[]) to authenticated, service_role;

comment on function public.set_title_genres(bigint, integer[]) is
  'Replaces the genre set of a title (dedupes; unknown genre id → 23503 and nothing changes). Admin / service role only.';
