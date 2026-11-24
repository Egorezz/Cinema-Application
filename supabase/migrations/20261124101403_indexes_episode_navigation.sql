-- 1.10: air_date index + next/prev episode RPC
-- All FKs in public are already covered (see supabase/tests/episode_navigation_test.sql TC1 guard).

create index episodes_air_date_idx on public.episodes (air_date);

-- Neighbour episode within the same title, ordered by (season_number, episode_number), crossing season
-- boundaries. Specials (season 0) and regular seasons (>= 1) are navigated separately.
-- Returns null for the last/first episode, unknown ids and unpublished titles.
create or replace function public.get_next_episode(p_episode_id bigint)
returns bigint
language sql
stable
security invoker
set search_path = ''
as $$
  select e2.id
    from public.episodes e
    join public.seasons s   on s.id = e.season_id
    join public.titles t    on t.id = s.title_id and t.is_published
    join public.seasons s2  on s2.title_id = s.title_id
                           and (s2.season_number = 0) = (s.season_number = 0)
    join public.episodes e2 on e2.season_id = s2.id
   where e.id = p_episode_id
     and (s2.season_number, e2.episode_number) > (s.season_number, e.episode_number)
   order by s2.season_number, e2.episode_number
   limit 1;
$$;

create or replace function public.get_prev_episode(p_episode_id bigint)
returns bigint
language sql
stable
security invoker
set search_path = ''
as $$
  select e2.id
    from public.episodes e
    join public.seasons s   on s.id = e.season_id
    join public.titles t    on t.id = s.title_id and t.is_published
    join public.seasons s2  on s2.title_id = s.title_id
                           and (s2.season_number = 0) = (s.season_number = 0)
    join public.episodes e2 on e2.season_id = s2.id
   where e.id = p_episode_id
     and (s2.season_number, e2.episode_number) < (s.season_number, e.episode_number)
   order by s2.season_number desc, e2.episode_number desc
   limit 1;
$$;

revoke execute on function public.get_next_episode(bigint) from public, anon, authenticated;
revoke execute on function public.get_prev_episode(bigint) from public, anon, authenticated;
grant execute on function public.get_next_episode(bigint) to authenticated;
grant execute on function public.get_prev_episode(bigint) to authenticated;

comment on function public.get_next_episode(bigint) is
  'Next episode id of the same published series across season boundaries (specials navigated separately); null if none.';
comment on function public.get_prev_episode(bigint) is
  'Previous episode id of the same published series across season boundaries (specials navigated separately); null if none.';
