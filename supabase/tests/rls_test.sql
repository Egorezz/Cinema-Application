begin;
select plan(42);

-- TC1: RLS is enabled on every table in schema public (a future table without RLS fails here)
select is(
  (select array_agg(c.relname::text order by c.relname)
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  null,
  'TC1: every table in schema public has RLS enabled'
);

-- Fixtures: admin (c9a) and regular user (c9b); draft series with season/episode/source,
-- published movie with an inactive source, published series for the non-admin insert attempt
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000c9a', 'rls-admin@test.local'),
  ('00000000-0000-0000-0000-000000000c9b', 'rls-user@test.local');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-000000000c9a';

insert into public.titles (type, title, tmdb_id, is_published) values
  ('series', 'RLS9 draft series', 900000901, false),
  ('movie', 'RLS9 published movie', 900000902, true),
  ('series', 'RLS9 published series', 900000904, true);
insert into public.seasons (title_id, season_number, name)
  select id, 1, 'RLS9 s1' from public.titles where type = 'series' and tmdb_id = 900000901;
insert into public.episodes (season_id, episode_number, name)
  select id, 1, 'RLS9 e1' from public.seasons where name = 'RLS9 s1';
insert into public.seasons (title_id, season_number, name)
  select id, 1, 'RLS9 pub s1' from public.titles where type = 'series' and tmdb_id = 900000904;
insert into public.episodes (season_id, episode_number, name)
  select id, 1, 'RLS9 pub e1' from public.seasons where name = 'RLS9 pub s1';
insert into public.video_sources (episode_id, url, format)
  select id, 'https://rls9.test/draft', 'hls' from public.episodes where name = 'RLS9 e1';
insert into public.video_sources (title_id, url, format, is_active)
  select id, 'https://rls9.test/inactive', 'mp4', false from public.titles where type = 'movie' and tmdb_id = 900000902;
-- Ids captured as postgres: clients cannot filter video_sources by url (no SELECT on url).
create temporary table rls_vs_ids as
  select id from public.video_sources where url like 'https://rls9.test/%';
grant select on rls_vs_ids to authenticated;

-- TC2: admin sees drafts and inactive sources; a non-admin user sees none of them
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000c9a","role":"authenticated"}';
select is(
  (select count(*)::int from public.titles where tmdb_id in (900000901, 900000902)),
  2,
  'TC2: admin sees the draft and the published title'
);
select is(
  (select count(*)::int from public.seasons where name = 'RLS9 s1'),
  1,
  'TC2: admin sees the season of a draft title'
);
select is(
  (select count(*)::int from public.episodes where name = 'RLS9 e1'),
  1,
  'TC2: admin sees the episode of a draft title'
);
select is(
  (select array_agg(url) from public.admin_get_video_sources((select id from public.titles where tmdb_id = 900000901))),
  array['https://rls9.test/draft'],
  'TC2: admin reads the source of a draft series via admin_get_video_sources'
);
select is(
  (select array_agg(url || ':' || is_active) from public.admin_get_video_sources((select id from public.titles where tmdb_id = 900000902))),
  array['https://rls9.test/inactive:false'],
  'TC2: admin reads the inactive movie source via admin_get_video_sources'
);

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000c9b","role":"authenticated"}';
select is(
  (select count(*)::int from public.titles where tmdb_id = 900000901),
  0,
  'TC2: non-admin user does not see the draft title'
);
select is(
  (select count(*)::int from public.video_sources where id in (select id from rls_vs_ids)),
  0,
  'TC2: non-admin user sees neither the draft nor the inactive source'
);

-- TC3: admin can insert (with returning), update and delete catalog rows and video sources
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000c9a","role":"authenticated"}';
select lives_ok(
  $$insert into public.titles (type, title, tmdb_id) values ('series', 'RLS9 admin series', 900000903) returning id$$,
  'TC3: admin inserts a draft title with returning'
);
update public.titles set title = 'RLS9 admin series edited' where type = 'series' and tmdb_id = 900000903;
select is(
  (select title from public.titles where type = 'series' and tmdb_id = 900000903),
  'RLS9 admin series edited',
  'TC3: admin updates a draft title'
);
select lives_ok(
  $$insert into public.seasons (title_id, season_number, name)
    select id, 1, 'RLS9 admin s1' from public.titles where type = 'series' and tmdb_id = 900000903
    returning id$$,
  'TC3: admin inserts a season under a draft title'
);
select lives_ok(
  $$insert into public.episodes (season_id, episode_number, name)
    select id, 1, 'RLS9 admin e1' from public.seasons where name = 'RLS9 admin s1'
    returning id$$,
  'TC3: admin inserts an episode under a draft title'
);
select lives_ok(
  $$insert into public.video_sources (episode_id, url, format)
    select id, 'https://rls9.test/admin', 'hls' from public.episodes where name = 'RLS9 admin e1'
    returning id$$,
  'TC3: admin inserts a video source under a draft title'
);
update public.seasons set name = 'RLS9 admin s1 edited' where name = 'RLS9 admin s1';
select is(
  (select count(*)::int from public.seasons where name = 'RLS9 admin s1 edited'),
  1,
  'TC3: admin updates a season'
);
update public.episodes set name = 'RLS9 admin e1 edited' where name = 'RLS9 admin e1';
select is(
  (select count(*)::int from public.episodes where name = 'RLS9 admin e1 edited'),
  1,
  'TC3: admin updates an episode'
);
-- Admin edits a source by id (url is write-only for clients); results are checked as postgres.
update public.video_sources set url = 'https://rls9.test/admin2', is_active = false
 where id = (select v.id from public.video_sources v
               join public.episodes e on e.id = v.episode_id
              where e.name = 'RLS9 admin e1 edited');
reset role;
select is(
  (select url || ':' || is_active from public.video_sources v
     join public.episodes e on e.id = v.episode_id
    where e.name = 'RLS9 admin e1 edited'),
  'https://rls9.test/admin2:false',
  'TC3: admin changes the url of a video source and deactivates it'
);
set local role authenticated;
delete from public.video_sources
 where id = (select v.id from public.video_sources v
               join public.episodes e on e.id = v.episode_id
              where e.name = 'RLS9 admin e1 edited');
reset role;
select is(
  (select count(*)::int from public.video_sources where url like 'https://rls9.test/admin%'),
  0,
  'TC3: admin deletes a video source'
);
set local role authenticated;
delete from public.episodes where name = 'RLS9 admin e1 edited';
select is(
  (select count(*)::int from public.episodes where name = 'RLS9 admin e1 edited'),
  0,
  'TC3: admin deletes an episode'
);
delete from public.seasons where name = 'RLS9 admin s1 edited';
select is(
  (select count(*)::int from public.seasons where name = 'RLS9 admin s1 edited'),
  0,
  'TC3: admin deletes a season'
);
delete from public.titles where type = 'series' and tmdb_id = 900000903;
reset role;
select is(
  (select count(*)::int from public.titles where type = 'series' and tmdb_id = 900000903),
  0,
  'TC3: admin deletes a draft title'
);

-- TC4: a non-admin user cannot write the catalog
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000c9b","role":"authenticated"}';
update public.titles set title = 'RLS9 hacked' where type = 'movie' and tmdb_id = 900000902;
delete from public.titles where type = 'movie' and tmdb_id = 900000902;
update public.seasons set name = 'RLS9 hacked' where name = 'RLS9 pub s1';
delete from public.seasons where name = 'RLS9 pub s1';
update public.episodes set name = 'RLS9 hacked' where name = 'RLS9 pub e1';
delete from public.episodes where name = 'RLS9 pub e1';
select throws_ok(
  $$insert into public.titles (type, title, tmdb_id) values ('movie', 'RLS9 user movie', 900000905)$$,
  '42501', null,
  'TC4: non-admin insert into titles is rejected by RLS'
);
select throws_ok(
  $$insert into public.seasons (title_id, season_number, name)
    select id, 2, 'RLS9 user s2' from public.titles where type = 'series' and tmdb_id = 900000904$$,
  '42501', null,
  'TC4: non-admin insert into seasons is rejected by RLS'
);
select throws_ok(
  $$insert into public.episodes (season_id, episode_number, name)
    select id, 2, 'RLS9 user e2' from public.seasons where name = 'RLS9 pub s1'$$,
  '42501', null,
  'TC4: non-admin insert into episodes is rejected by RLS'
);
reset role;
select is(
  (select title from public.titles where type = 'movie' and tmdb_id = 900000902),
  'RLS9 published movie',
  'TC4: non-admin update/delete of a published title affects no rows'
);
select is(
  (select count(*)::int from public.seasons where name = 'RLS9 pub s1'),
  1,
  'TC4: non-admin update/delete of a published season affects no rows'
);
select is(
  (select count(*)::int from public.episodes where name = 'RLS9 pub e1'),
  1,
  'TC4: non-admin update/delete of a published episode affects no rows'
);

-- TC5: anon is read-only; authenticated has no truncate/references/trigger
select table_privs_are('public', 'titles', 'anon', array['SELECT'], 'TC5: anon has only SELECT on titles');
select table_privs_are('public', 'seasons', 'anon', array['SELECT'], 'TC5: anon has only SELECT on seasons');
select table_privs_are('public', 'episodes', 'anon', array['SELECT'], 'TC5: anon has only SELECT on episodes');
select table_privs_are('public', 'video_sources', 'anon', array[]::text[], 'TC5: anon has no privileges on video_sources');
select table_privs_are('public', 'profiles', 'anon', array[]::text[], 'TC5: anon has no privileges on profiles');
select table_privs_are(
  'public', 'titles', 'authenticated', array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'TC5: authenticated has only SELECT/INSERT/UPDATE/DELETE on titles'
);
select table_privs_are(
  'public', 'seasons', 'authenticated', array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'TC5: authenticated has only SELECT/INSERT/UPDATE/DELETE on seasons'
);
select table_privs_are(
  'public', 'episodes', 'authenticated', array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'TC5: authenticated has only SELECT/INSERT/UPDATE/DELETE on episodes'
);
select table_privs_are(
  'public', 'video_sources', 'authenticated', array['INSERT', 'UPDATE', 'DELETE'],
  'TC5: authenticated has only INSERT/UPDATE/DELETE on video_sources (SELECT is per column)'
);
select column_privs_are(
  'public', 'video_sources', 'url', 'authenticated', array['INSERT', 'UPDATE'],
  'TC5: authenticated cannot SELECT video_sources.url'
);
select column_privs_are(
  'public', 'video_sources', 'id', 'authenticated', array['SELECT', 'INSERT', 'UPDATE'],
  'TC5: authenticated can SELECT video_sources.id'
);

-- TC6: trigger functions are not callable by clients
select is(
  (select array_agg(r.role || ':' || f.fn order by r.role, f.fn)
     from unnest(array['anon', 'authenticated']) r(role),
          unnest(array[
            'public.seasons_check_series_title()',
            'public.set_updated_at()',
            'public.titles_check_type_change()',
            'public.video_sources_check_movie_title()',
            'public.watch_progress_check_finished()'
          ]) f(fn)
    where has_function_privilege(r.role, f.fn, 'execute')),
  null,
  'TC6: anon and authenticated cannot execute the trigger functions'
);

-- TC9: guard — no security definer function in public is client-callable unless allow-listed.
-- A new client-callable definer function must be added to the allow-list below.
select is(
  (select array_agg(p.oid::regprocedure::text || ' -> ' || r.role order by p.oid::regprocedure::text, r.role)
     from pg_proc p
     cross join unnest(array['anon', 'authenticated']) r(role)
    where p.pronamespace = 'public'::regnamespace
      and p.prosecdef
      and not exists (
        select 1 from pg_depend d
         where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e'
      )
      and has_function_privilege(r.role, p.oid, 'execute')
      and (p.oid, r.role) not in (
        ('public.is_admin()'::regprocedure::oid, 'anon'),
        ('public.is_admin()'::regprocedure::oid, 'authenticated'),
        ('public.register_push_subscription(text,text,text,text)'::regprocedure::oid, 'authenticated'),
        ('public.set_title_genres(bigint,integer[])'::regprocedure::oid, 'authenticated'),
        ('public.get_video_sources(bigint,bigint)'::regprocedure::oid, 'authenticated'),
        ('public.admin_get_video_sources(bigint)'::regprocedure::oid, 'authenticated')
      )),
  null,
  'TC9: security definer functions in public are not executable by anon/authenticated unless allow-listed'
);

-- TC10: admin cannot read video_sources.url from the table either (reads go through admin_get_video_sources)
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000c9a","role":"authenticated"}';
select throws_ok(
  $$select url from public.video_sources$$,
  '42501', null,
  'TC10: admin select of video_sources.url is rejected (no column privilege)'
);
select throws_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'https://rls9.test/returning', 'mp4' from public.titles where type = 'movie' and tmdb_id = 900000902
    returning url$$,
  '42501', null,
  'TC10: admin insert returning url is rejected (no column privilege)'
);

-- TC11: a non-admin user cannot call admin_get_video_sources
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000c9b","role":"authenticated"}';
select throws_ok(
  $$select * from public.admin_get_video_sources((select id from public.titles where type = 'movie' and tmdb_id = 900000902))$$,
  '42501', null,
  'TC11: non-admin admin_get_video_sources is rejected'
);
reset role;

select * from finish();
rollback;
