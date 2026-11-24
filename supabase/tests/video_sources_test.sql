begin;
select plan(31);

-- TC1: table shape
select columns_are(
  'public', 'video_sources',
  array[
    'id', 'episode_id', 'title_id', 'url', 'format', 'quality', 'language',
    'priority', 'is_active', 'created_at', 'updated_at'
  ],
  'TC1: video_sources has exactly the 11 expected columns'
);
select col_is_pk('public', 'video_sources', 'id', 'TC1: video_sources.id is the primary key');
select fk_ok('public', 'video_sources', 'episode_id', 'public', 'episodes', 'id', 'TC1: video_sources.episode_id references episodes.id');
select fk_ok('public', 'video_sources', 'title_id', 'public', 'titles', 'id', 'TC1: video_sources.title_id references titles.id');

-- Fixtures
insert into public.titles (type, title, tmdb_id, is_published) values
  ('movie', 'VS movie published', 900000401, true),
  ('series', 'VS series published', 900000402, true),
  ('movie', 'VS movie draft', 900000403, false),
  ('movie', 'VS movie cascade', 900000404, true);
insert into public.seasons (title_id, season_number, name)
  select id, 1, 'VS s1' from public.titles where tmdb_id = 900000402;
insert into public.episodes (season_id, episode_number, name)
  select id, n, 'VS e' || n from public.seasons, generate_series(1, 2) n where name = 'VS s1';

-- TC2 (DoD): several sources per episode, ordered by priority then id
select lives_ok(
  $$insert into public.video_sources (episode_id, url, format, priority)
    select e.id, v.url, 'hls', v.priority
    from public.episodes e,
      (values ('https://tc2.test/p2', 2), ('https://tc2.test/p0', 0), ('https://tc2.test/p1', 1)) v(url, priority)
    where e.name = 'VS e1'$$,
  'TC2: three sources with priority 2, 0, 1 are inserted for one episode'
);
select is(
  (select array_agg(url order by priority, id) from public.video_sources where url like 'https://tc2.test/%'),
  array['https://tc2.test/p0', 'https://tc2.test/p1', 'https://tc2.test/p2'],
  'TC2: sources are read in priority order 0, 1, 2'
);
insert into public.video_sources (episode_id, url, format, priority)
  select id, 'https://tc2.test/p0-second', 'mp4', 0 from public.episodes where name = 'VS e1';
select is(
  (select array_agg(url order by priority, id) from public.video_sources where url like 'https://tc2.test/%'),
  array['https://tc2.test/p0', 'https://tc2.test/p0-second', 'https://tc2.test/p1', 'https://tc2.test/p2'],
  'TC2: a later source with the same priority sorts after the earlier one (tie-break by id)'
);

-- TC3: exactly one parent
select throws_ok(
  $$insert into public.video_sources (url, format) values ('https://tc3.test/none', 'hls')$$,
  '23514', null,
  'TC3: source without episode_id and title_id is rejected'
);
select throws_ok(
  $$insert into public.video_sources (episode_id, title_id, url, format)
    select e.id, t.id, 'https://tc3.test/both', 'hls'
    from public.episodes e, public.titles t
    where e.name = 'VS e1' and t.tmdb_id = 900000401$$,
  '23514', null,
  'TC3: source with both episode_id and title_id is rejected'
);

-- TC4: title_id only for movies
select lives_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'https://tc4.test/movie', 'mp4' from public.titles where tmdb_id = 900000401$$,
  'TC4: source for a movie title is inserted'
);
select throws_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'https://tc4.test/series', 'hls' from public.titles where tmdb_id = 900000402$$,
  '23514', null,
  'TC4: source for a series title is rejected'
);
select throws_ok(
  $$update public.video_sources
    set title_id = (select id from public.titles where tmdb_id = 900000402)
    where url = 'https://tc4.test/movie'$$,
  '23514', null,
  'TC4: moving a movie source to a series title is rejected'
);

-- TC5: check constraints and defaults
select throws_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'https://tc5.test/dash', 'dash' from public.titles where tmdb_id = 900000401$$,
  '23514', null,
  'TC5: format dash is rejected'
);
select throws_ok(
  $$insert into public.video_sources (title_id, url, format, priority)
    select id, 'https://tc5.test/neg', 'hls', -1 from public.titles where tmdb_id = 900000401$$,
  '23514', null,
  'TC5: priority -1 is rejected'
);
select throws_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'ftp://x', 'mp4' from public.titles where tmdb_id = 900000401$$,
  '23514', null,
  'TC5: ftp url is rejected'
);
insert into public.video_sources (title_id, url, format)
  select id, 'https://tc5.test/defaults', 'hls' from public.titles where tmdb_id = 900000401;
select is(
  (select priority || '/' || is_active from public.video_sources where url = 'https://tc5.test/defaults'),
  '0/true',
  'TC5: priority defaults to 0 and is_active to true'
);

-- TC6: no duplicate url per parent
select throws_ok(
  $$insert into public.video_sources (episode_id, url, format)
    select id, 'https://tc2.test/p1', 'hls' from public.episodes where name = 'VS e1'$$,
  '23505', null,
  'TC6: same url twice for the same episode is rejected'
);
select throws_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'https://tc4.test/movie', 'mp4' from public.titles where tmdb_id = 900000401$$,
  '23505', null,
  'TC6: same url twice for the same movie is rejected'
);

-- TC7: on delete cascade
insert into public.video_sources (episode_id, url, format)
  select id, 'https://tc7.test/episode', 'hls' from public.episodes where name = 'VS e2';
insert into public.video_sources (title_id, url, format)
  select id, 'https://tc7.test/movie', 'mp4' from public.titles where tmdb_id = 900000404;
delete from public.episodes where name = 'VS e2';
select is(
  (select count(*)::int from public.video_sources where url = 'https://tc7.test/episode'),
  0,
  'TC7: deleting an episode removes its sources'
);
delete from public.titles where tmdb_id = 900000404;
select is(
  (select count(*)::int from public.video_sources where url = 'https://tc7.test/movie'),
  0,
  'TC7: deleting a movie title removes its sources'
);

-- TC8: updated_at trigger
insert into public.video_sources (title_id, url, format, updated_at)
  select id, 'https://tc8.test/old', 'hls', '2000-01-01' from public.titles where tmdb_id = 900000401;
update public.video_sources set priority = 5 where url = 'https://tc8.test/old';
select ok(
  (select updated_at > '2000-01-01'::timestamptz from public.video_sources where url = 'https://tc8.test/old'),
  'TC8: video_sources.updated_at is refreshed on update'
);

-- TC9: RLS — non-admin authenticated sees only active sources of published titles, anon sees nothing
select ok(
  (select relrowsecurity from pg_class where oid = 'public.video_sources'::regclass),
  'TC9: RLS is enabled on public.video_sources'
);
select policies_are(
  'public', 'video_sources',
  array[
    'video_sources_select_published_or_admin', 'video_sources_insert_admin',
    'video_sources_update_admin', 'video_sources_delete_admin'
  ],
  'TC9: video_sources has the published-or-admin select policy and admin-only write policies'
);
insert into public.video_sources (title_id, url, format, is_active)
  select id, 'https://rls.test/movie', 'mp4', true from public.titles where tmdb_id = 900000401
  union all
  select id, 'https://rls.test/inactive', 'mp4', false from public.titles where tmdb_id = 900000401
  union all
  select id, 'https://rls.test/draft', 'mp4', true from public.titles where tmdb_id = 900000403;
insert into public.video_sources (episode_id, url, format)
  select id, 'https://rls.test/episode', 'hls' from public.episodes where name = 'VS e1';

set local role anon;
select throws_ok(
  $$select count(*) from public.video_sources$$,
  '42501', null,
  'TC9: anon cannot select sources (no privilege)'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(
  (select array_agg(url order by url) from public.video_sources where url like 'https://rls.test/%'),
  array['https://rls.test/episode', 'https://rls.test/movie'],
  'TC9: authenticated sees only active sources of published titles'
);
reset role;

-- TC10: non-admin clients cannot write video_sources (anon has no write grants; authenticated is filtered by admin-only policies)
set local role anon;
select throws_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'https://rls.test/anon', 'mp4' from public.titles where tmdb_id = 900000401$$,
  '42501', null,
  'TC10: anon insert into video_sources is rejected (no privilege)'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'https://rls.test/user', 'mp4' from public.titles where tmdb_id = 900000401$$,
  '42501', null,
  'TC10: authenticated insert into video_sources is rejected by RLS'
);
update public.video_sources set priority = 9 where url = 'https://rls.test/movie';
delete from public.video_sources where url = 'https://rls.test/movie';
reset role;
select is(
  (select count(*)::int from public.video_sources where url = 'https://rls.test/movie' and priority = 0),
  1,
  'TC10: authenticated update/delete of a visible source affects no rows'
);

-- TC12: a title's type cannot change while seasons or direct video sources depend on it
insert into public.titles (type, title, tmdb_id) values
  ('movie', 'TC12 movie with source', 900000405),
  ('series', 'TC12 series with season', 900000406),
  ('movie', 'TC12 bare movie', 900000407);
insert into public.video_sources (title_id, url, format)
  select id, 'https://example.com/tc11.mp4', 'mp4' from public.titles where title = 'TC12 movie with source';
insert into public.seasons (title_id, season_number)
  select id, 1 from public.titles where title = 'TC12 series with season';
select throws_ok(
  $$update public.titles set type = 'series' where title = 'TC12 movie with source'$$,
  '23514', null,
  'TC12: movie with a video source cannot become a series'
);
select throws_ok(
  $$update public.titles set type = 'movie' where title = 'TC12 series with season'$$,
  '23514', null,
  'TC12: series with a season cannot become a movie'
);
select lives_ok(
  $$update public.titles set type = 'series' where title = 'TC12 bare movie'$$,
  'TC12: title without dependants can change type'
);

select * from finish();
rollback;
