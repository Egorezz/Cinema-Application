begin;
select plan(62);

-- TC1: table shape
select has_table('public', 'seasons', 'TC1: public.seasons exists');
select has_table('public', 'episodes', 'TC1: public.episodes exists');
select columns_are(
  'public', 'seasons',
  array['id', 'title_id', 'season_number', 'name', 'poster_path', 'created_at', 'updated_at'],
  'TC1: seasons has exactly the 7 expected columns'
);
select columns_are(
  'public', 'episodes',
  array[
    'id', 'season_id', 'episode_number', 'name', 'overview', 'air_date', 'still_path',
    'runtime', 'tmdb_episode_id', 'created_at', 'updated_at'
  ],
  'TC1: episodes has exactly the 11 expected columns'
);
select col_is_pk('public', 'seasons', 'id', 'TC1: seasons.id is the primary key');
select col_is_pk('public', 'episodes', 'id', 'TC1: episodes.id is the primary key');
select fk_ok('public', 'seasons', 'title_id', 'public', 'titles', 'id', 'TC1: seasons.title_id references titles.id');
select fk_ok('public', 'episodes', 'season_id', 'public', 'seasons', 'id', 'TC1: episodes.season_id references seasons.id');
select col_type_is('public', 'seasons', 'id', 'bigint', 'TC1: seasons.id is bigint');
select col_type_is('public', 'seasons', 'season_number', 'smallint', 'TC1: season_number is smallint');
select col_type_is('public', 'seasons', 'created_at', 'timestamp with time zone', 'TC1: seasons.created_at is timestamptz');
select col_type_is('public', 'seasons', 'updated_at', 'timestamp with time zone', 'TC1: seasons.updated_at is timestamptz');
select col_type_is('public', 'episodes', 'id', 'bigint', 'TC1: episodes.id is bigint');
select col_type_is('public', 'episodes', 'episode_number', 'smallint', 'TC1: episode_number is smallint');
select col_type_is('public', 'episodes', 'air_date', 'date', 'TC1: air_date is date');
select col_type_is('public', 'episodes', 'created_at', 'timestamp with time zone', 'TC1: episodes.created_at is timestamptz');
select col_type_is('public', 'episodes', 'updated_at', 'timestamp with time zone', 'TC1: episodes.updated_at is timestamptz');

-- Fixtures for TC2–TC7
insert into public.titles (type, title, tmdb_id) values
  ('series', 'UQ series A', 900000101),
  ('series', 'UQ series B', 900000102);

-- TC2: unique (title_id, season_number)
select lives_ok(
  $$insert into public.seasons (title_id, season_number, name)
    select id, 1, 'UQ A s1' from public.titles where type = 'series' and tmdb_id = 900000101$$,
  'TC2: season 1 of series A is inserted'
);
select throws_ok(
  $$insert into public.seasons (title_id, season_number, name)
    select id, 1, 'UQ A s1 dup' from public.titles where type = 'series' and tmdb_id = 900000101$$,
  '23505', null,
  'TC2: duplicate season 1 of series A is rejected'
);
select lives_ok(
  $$insert into public.seasons (title_id, season_number, name)
    select id, 2, 'UQ A s2' from public.titles where type = 'series' and tmdb_id = 900000101$$,
  'TC2: season 2 of series A is inserted'
);
select lives_ok(
  $$insert into public.seasons (title_id, season_number, name)
    select id, 1, 'UQ B s1' from public.titles where type = 'series' and tmdb_id = 900000102$$,
  'TC2: season 1 of series B is inserted'
);

-- TC3 (DoD): unique (season_id, episode_number)
select lives_ok(
  $$insert into public.episodes (season_id, episode_number, name)
    select id, 1, 'UQ A1 e1' from public.seasons where name = 'UQ A s1'$$,
  'TC3: episode 1 of season A1 is inserted'
);
select throws_ok(
  $$insert into public.episodes (season_id, episode_number, name)
    select id, 1, 'UQ A1 e1 dup' from public.seasons where name = 'UQ A s1'$$,
  '23505', null,
  'TC3: duplicate episode 1 of season A1 is rejected'
);
select lives_ok(
  $$insert into public.episodes (season_id, episode_number, name)
    select id, 2, 'UQ A1 e2' from public.seasons where name = 'UQ A s1'$$,
  'TC3: episode 2 of season A1 is inserted'
);
select lives_ok(
  $$insert into public.episodes (season_id, episode_number, name)
    select id, 1, 'UQ B1 e1' from public.seasons where name = 'UQ B s1'$$,
  'TC3: episode 1 of season B1 is inserted'
);

-- TC4: tmdb_episode_id unique when not null
select lives_ok(
  $$insert into public.episodes (season_id, episode_number, name, tmdb_episode_id)
    select id, 1, 'UQ A2 e1', 900000301 from public.seasons where name = 'UQ A s2'$$,
  'TC4: episode with tmdb_episode_id 900000301 is inserted'
);
select throws_ok(
  $$insert into public.episodes (season_id, episode_number, name, tmdb_episode_id)
    select id, 2, 'UQ A2 e2', 900000301 from public.seasons where name = 'UQ A s2'$$,
  '23505', null,
  'TC4: second episode with the same tmdb_episode_id is rejected'
);
select lives_ok(
  $$insert into public.episodes (season_id, episode_number, name, tmdb_episode_id)
    select id, 3, 'UQ A2 e3', null from public.seasons where name = 'UQ A s2'$$,
  'TC4: episode with null tmdb_episode_id is inserted'
);
select lives_ok(
  $$insert into public.episodes (season_id, episode_number, name, tmdb_episode_id)
    select id, 4, 'UQ A2 e4', null from public.seasons where name = 'UQ A s2'$$,
  'TC4: another episode with null tmdb_episode_id is inserted'
);

-- TC5: check and FK constraints
select throws_ok(
  $$insert into public.seasons (title_id, season_number)
    select id, -1 from public.titles where type = 'series' and tmdb_id = 900000102$$,
  '23514', null,
  'TC5: season_number -1 is rejected'
);
select lives_ok(
  $$insert into public.seasons (title_id, season_number, name)
    select id, 0, 'UQ B s0' from public.titles where type = 'series' and tmdb_id = 900000102$$,
  'TC5: season_number 0 (specials) is allowed'
);
select throws_ok(
  $$insert into public.episodes (season_id, episode_number)
    select id, 0 from public.seasons where name = 'UQ B s1'$$,
  '23514', null,
  'TC5: episode_number 0 is rejected'
);
select throws_ok(
  $$insert into public.episodes (season_id, episode_number, runtime)
    select id, 9, 0 from public.seasons where name = 'UQ B s1'$$,
  '23514', null,
  'TC5: runtime 0 is rejected'
);
select throws_ok(
  $$insert into public.seasons (title_id, season_number) values (-1, 1)$$,
  '23503', null,
  'TC5: season with a non-existent title_id is rejected'
);
select throws_ok(
  $$insert into public.episodes (season_id, episode_number) values (-1, 1)$$,
  '23503', null,
  'TC5: episode with a non-existent season_id is rejected'
);

-- TC6: on delete cascade
select is(
  (select count(*)::int from public.episodes where name like 'UQ A2 %'),
  3,
  'TC6: season A2 has 3 episodes before delete'
);
delete from public.seasons where name = 'UQ A s2';
select is(
  (select count(*)::int from public.episodes where name like 'UQ A2 %'),
  0,
  'TC6: deleting a season removes its episodes'
);
delete from public.titles where type = 'series' and tmdb_id = 900000101;
select is(
  (select count(*)::int from public.seasons where name like 'UQ A %'),
  0,
  'TC6: deleting a title removes its seasons'
);
select is(
  (select count(*)::int from public.episodes where name like 'UQ A%'),
  0,
  'TC6: deleting a title removes the episodes of its seasons'
);

-- TC7: updated_at triggers
select has_trigger('public', 'seasons', 'seasons_set_updated_at', 'TC7: seasons_set_updated_at trigger exists');
select has_trigger('public', 'episodes', 'episodes_set_updated_at', 'TC7: episodes_set_updated_at trigger exists');
insert into public.seasons (title_id, season_number, name, updated_at)
  select id, 7, 'UQ B s7 old', '2000-01-01' from public.titles where type = 'series' and tmdb_id = 900000102;
update public.seasons set name = 'UQ B s7 new' where name = 'UQ B s7 old';
select ok(
  (select updated_at > '2000-01-01'::timestamptz from public.seasons where name = 'UQ B s7 new'),
  'TC7: seasons.updated_at is refreshed on update'
);
insert into public.episodes (season_id, episode_number, name, updated_at)
  select id, 7, 'UQ B1 e7 old', '2000-01-01' from public.seasons where name = 'UQ B s1';
update public.episodes set name = 'UQ B1 e7 new' where name = 'UQ B1 e7 old';
select ok(
  (select updated_at > '2000-01-01'::timestamptz from public.episodes where name = 'UQ B1 e7 new'),
  'TC7: episodes.updated_at is refreshed on update'
);

-- TC8: RLS enabled, only select policies
select ok(
  (select relrowsecurity from pg_class where oid = 'public.seasons'::regclass),
  'TC8: RLS is enabled on public.seasons'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.episodes'::regclass),
  'TC8: RLS is enabled on public.episodes'
);
select policies_are('public', 'seasons', array['seasons_select_published'], 'TC8: only seasons_select_published policy exists');
select policies_are('public', 'episodes', array['episodes_select_published'], 'TC8: only episodes_select_published policy exists');

-- TC9: visibility follows the parent title's is_published
insert into public.titles (type, title, tmdb_id, is_published) values
  ('series', 'RLS published', 900000201, true),
  ('series', 'RLS draft', 900000202, false);
insert into public.seasons (title_id, season_number, name)
  select id, 1, case when is_published then 'RLS s published' else 'RLS s draft' end
  from public.titles where type = 'series' and tmdb_id in (900000201, 900000202);
insert into public.episodes (season_id, episode_number, name)
  select id, 1, case when name = 'RLS s published' then 'RLS ep published' else 'RLS ep draft' end
  from public.seasons where name in ('RLS s published', 'RLS s draft');

set local role anon;
select is(
  (select array_agg(name order by name) from public.seasons where name like 'RLS s %'),
  array['RLS s published'],
  'TC9: anon sees only seasons of published titles'
);
select is(
  (select array_agg(name order by name) from public.episodes where name like 'RLS ep %'),
  array['RLS ep published'],
  'TC9: anon sees only episodes of published titles'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(
  (select array_agg(name order by name) from public.seasons where name like 'RLS s %'),
  array['RLS s published'],
  'TC9: authenticated sees only seasons of published titles'
);
select is(
  (select array_agg(name order by name) from public.episodes where name like 'RLS ep %'),
  array['RLS ep published'],
  'TC9: authenticated sees only episodes of published titles'
);
reset role;

-- TC10: clients cannot write seasons/episodes (no write policies until is_admin() in 1.4/1.9)
set local role anon;
select throws_ok(
  $$insert into public.seasons (title_id, season_number, name)
    select id, 5, 'RLS anon season' from public.titles where type = 'series' and tmdb_id = 900000201$$,
  '42501', null,
  'TC10: anon insert into seasons is rejected by RLS'
);
select throws_ok(
  $$insert into public.episodes (season_id, episode_number, name)
    select id, 5, 'RLS anon episode' from public.seasons where name = 'RLS s published'$$,
  '42501', null,
  'TC10: anon insert into episodes is rejected by RLS'
);
update public.seasons set name = 'RLS anon hacked' where name = 'RLS s published';
update public.episodes set name = 'RLS anon hacked' where name = 'RLS ep published';
delete from public.episodes where name = 'RLS ep published';
delete from public.seasons where name = 'RLS s published';
reset role;
select is(
  (select count(*)::int from public.seasons where name = 'RLS s published'),
  1,
  'TC10: anon update/delete of a published season affects no rows'
);
select is(
  (select count(*)::int from public.episodes where name = 'RLS ep published'),
  1,
  'TC10: anon update/delete of a published episode affects no rows'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$insert into public.seasons (title_id, season_number, name)
    select id, 5, 'RLS user season' from public.titles where type = 'series' and tmdb_id = 900000201$$,
  '42501', null,
  'TC10: authenticated insert into seasons is rejected by RLS'
);
select throws_ok(
  $$insert into public.episodes (season_id, episode_number, name)
    select id, 5, 'RLS user episode' from public.seasons where name = 'RLS s published'$$,
  '42501', null,
  'TC10: authenticated insert into episodes is rejected by RLS'
);
update public.seasons set name = 'RLS user hacked' where name = 'RLS s published';
update public.episodes set name = 'RLS user hacked' where name = 'RLS ep published';
delete from public.episodes where name = 'RLS ep published';
delete from public.seasons where name = 'RLS s published';
reset role;
select is(
  (select count(*)::int from public.seasons where name = 'RLS s published'),
  1,
  'TC10: authenticated update/delete of a published season affects no rows'
);
select is(
  (select count(*)::int from public.episodes where name = 'RLS ep published'),
  1,
  'TC10: authenticated update/delete of a published episode affects no rows'
);

-- TC12: seasons only for series titles
insert into public.titles (type, title, tmdb_id) values ('movie', 'TC12 movie', 900000301);
select throws_ok(
  $$insert into public.seasons (title_id, season_number)
    select id, 1 from public.titles where title = 'TC12 movie'$$,
  '23514', null,
  'TC12: season for a movie title is rejected'
);
select throws_ok(
  $$update public.seasons set title_id = (select id from public.titles where title = 'TC12 movie')
    where title_id = (select id from public.titles where title = 'UQ series B') and season_number = 1$$,
  '23514', null,
  'TC12: moving a season to a movie title is rejected'
);
select has_trigger('public', 'seasons', 'seasons_check_series_title', 'TC12: seasons_check_series_title trigger exists');

select * from finish();
rollback;
