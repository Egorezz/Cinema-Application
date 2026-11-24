-- 1.9: RLS — admin read/write on catalog and video_sources, grant hardening, trigger fn execute revokes

-- Catalog read: published for everyone, everything for admin.
-- One select policy per table (no second permissive select policy → no advisor warning).
-- (select public.is_admin()) is wrapped in a sub-select so it is evaluated once per statement (initPlan).
drop policy "titles_select_published" on public.titles;
create policy "titles_select_published_or_admin" on public.titles
  for select to anon, authenticated
  using (is_published or (select public.is_admin()));

drop policy "seasons_select_published" on public.seasons;
create policy "seasons_select_published_or_admin" on public.seasons
  for select to anon, authenticated
  using (
    exists (select 1 from public.titles t where t.id = seasons.title_id and t.is_published)
    or (select public.is_admin())
  );

drop policy "episodes_select_published" on public.episodes;
create policy "episodes_select_published_or_admin" on public.episodes
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.seasons s
      join public.titles t on t.id = s.title_id
      where s.id = episodes.season_id and t.is_published
    )
    or (select public.is_admin())
  );

drop policy "video_sources_select_published" on public.video_sources;
create policy "video_sources_select_published_or_admin" on public.video_sources
  for select to authenticated
  using (
    (
      is_active
      and (
        exists (select 1 from public.titles t where t.id = video_sources.title_id and t.is_published)
        or exists (
          select 1 from public.episodes e
          join public.seasons s on s.id = e.season_id
          join public.titles t on t.id = s.title_id
          where e.id = video_sources.episode_id and t.is_published
        )
      )
    )
    or (select public.is_admin())
  );

-- Admin writes (12 policies, identical predicate on every table).
create policy "titles_insert_admin" on public.titles
  for insert to authenticated with check ((select public.is_admin()));
create policy "titles_update_admin" on public.titles
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "titles_delete_admin" on public.titles
  for delete to authenticated using ((select public.is_admin()));

create policy "seasons_insert_admin" on public.seasons
  for insert to authenticated with check ((select public.is_admin()));
create policy "seasons_update_admin" on public.seasons
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "seasons_delete_admin" on public.seasons
  for delete to authenticated using ((select public.is_admin()));

create policy "episodes_insert_admin" on public.episodes
  for insert to authenticated with check ((select public.is_admin()));
create policy "episodes_update_admin" on public.episodes
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "episodes_delete_admin" on public.episodes
  for delete to authenticated using ((select public.is_admin()));

create policy "video_sources_insert_admin" on public.video_sources
  for insert to authenticated with check ((select public.is_admin()));
create policy "video_sources_update_admin" on public.video_sources
  for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "video_sources_delete_admin" on public.video_sources
  for delete to authenticated using ((select public.is_admin()));

-- Grant hardening: anon is read-only; truncate bypasses RLS; references/trigger never needed by clients.
revoke insert, update, delete, truncate, references, trigger
  on public.titles, public.seasons, public.episodes, public.video_sources from anon;
revoke truncate, references, trigger
  on public.titles, public.seasons, public.episodes, public.video_sources from authenticated;

-- Trigger functions must not be callable as RPC (security definer; advisor finding from 1.4).
revoke execute on function public.seasons_check_series_title() from public, anon, authenticated;
revoke execute on function public.titles_check_type_change() from public, anon, authenticated;
revoke execute on function public.video_sources_check_movie_title() from public, anon, authenticated;
