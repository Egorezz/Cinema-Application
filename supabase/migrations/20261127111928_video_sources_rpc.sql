-- video_sources: https only, URLs reachable by clients only through RPCs.

-- 1) https only: http media is blocked as mixed content on the HTTPS app.
alter table public.video_sources drop constraint video_sources_url_check;
alter table public.video_sources add constraint video_sources_url_check
  check (url ~* '^https://\S+$');   -- validates existing rows: fails the migration if any http row exists

-- 2) No direct URL reads by clients. Users read sources only via get_video_sources();
--    admin reads via admin_get_video_sources() and keeps direct writes.
drop policy "video_sources_select_published_or_admin" on public.video_sources;
-- Admin-only select: needed so admin update/delete can find rows (WHERE id = ...) under RLS.
create policy "video_sources_select_admin" on public.video_sources
  for select to authenticated using ((select public.is_admin()));

revoke select on public.video_sources from authenticated;
grant select (id, episode_id, title_id, format, quality, language, priority, is_active, created_at, updated_at)
  on public.video_sources to authenticated;
-- insert/update/delete table grants for authenticated stay (admin-only policies from 1.9).

-- 3) Playable sources of ONE episode (series) or ONE movie, for the player.
-- security definer: clients have no SELECT on video_sources.url; filters published/active explicitly
-- (definer bypasses RLS), so it returns exactly what a regular user may play, also for admins.
create or replace function public.get_video_sources(
  p_episode_id bigint default null,
  p_title_id   bigint default null
)
returns table (id bigint, url text, format text, quality text, language text, priority smallint)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- Defense in depth: execute is granted only to authenticated, so this fires only for direct SQL callers without a JWT.
  if (select auth.uid()) is null then
    raise exception 'not authenticated' using errcode = 'insufficient_privilege';
  end if;
  if num_nonnulls(p_episode_id, p_title_id) <> 1 then
    raise exception 'pass exactly one of p_episode_id, p_title_id' using errcode = 'invalid_parameter_value';
  end if;

  return query
  select v.id, v.url, v.format, v.quality, v.language, v.priority
    from public.video_sources v
   where v.is_active
     and (
       (p_episode_id is not null and v.episode_id = p_episode_id and exists (
          select 1 from public.episodes e
            join public.seasons s on s.id = e.season_id
            join public.titles t  on t.id = s.title_id
           where e.id = v.episode_id and t.is_published))
       or
       (p_title_id is not null and v.title_id = p_title_id and exists (
          select 1 from public.titles t
           where t.id = v.title_id and t.type = 'movie' and t.is_published))
     )
   order by v.priority, v.id;
end;
$$;

revoke execute on function public.get_video_sources(bigint, bigint) from public, anon, authenticated;
grant execute on function public.get_video_sources(bigint, bigint) to authenticated;

-- 4) All sources of one title for the admin editor (8.3): movie sources and every episode's sources,
-- incl. inactive ones and drafts. security definer: url is not selectable by clients; guarded by is_admin().
create or replace function public.admin_get_video_sources(p_title_id bigint)
returns table (
  id bigint, episode_id bigint, title_id bigint, url text, format text, quality text,
  language text, priority smallint, is_active boolean, created_at timestamptz, updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (select public.is_admin()) then
    raise exception 'admin only' using errcode = 'insufficient_privilege';
  end if;

  return query
  select v.id, v.episode_id, v.title_id, v.url, v.format, v.quality, v.language,
         v.priority, v.is_active, v.created_at, v.updated_at
    from public.video_sources v
    left join public.episodes e on e.id = v.episode_id
    left join public.seasons  s on s.id = e.season_id
   where v.title_id = p_title_id or s.title_id = p_title_id
   order by s.season_number nulls first, e.episode_number nulls first, v.priority, v.id;
end;
$$;

revoke execute on function public.admin_get_video_sources(bigint) from public, anon, authenticated;
grant execute on function public.admin_get_video_sources(bigint) to authenticated;
