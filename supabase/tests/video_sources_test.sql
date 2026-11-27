begin;
select plan(40);

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

-- TC9: RLS — clients cannot read video_sources directly: no url column grant, select policy is admin-only
select ok(
  (select relrowsecurity from pg_class where oid = 'public.video_sources'::regclass),
  'TC9: RLS is enabled on public.video_sources'
);
select policies_are(
  'public', 'video_sources',
  array[
    'video_sources_select_admin', 'video_sources_insert_admin',
    'video_sources_update_admin', 'video_sources_delete_admin'
  ],
  'TC9: video_sources has the admin-only select policy and admin-only write policies'
);
insert into public.video_sources (title_id, url, format, is_active)
  select id, 'https://rls.test/movie', 'mp4', true from public.titles where tmdb_id = 900000401
  union all
  select id, 'https://rls.test/inactive', 'mp4', false from public.titles where tmdb_id = 900000401
  union all
  select id, 'https://rls.test/draft', 'mp4', true from public.titles where tmdb_id = 900000403;
insert into public.video_sources (episode_id, url, format)
  select id, 'https://rls.test/episode', 'hls' from public.episodes where name = 'VS e1';

-- Ids captured as postgres: clients cannot filter by url (no SELECT on video_sources.url).
create temporary table vs_ids as
  select url as key, id from public.video_sources where url like 'https://rls.test/%';
grant select on vs_ids to anon, authenticated;

set local role anon;
select throws_ok(
  $$select id from public.video_sources$$,
  '42501', null,
  'TC9: anon cannot select sources (no privilege)'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select url from public.video_sources$$,
  '42501', null,
  'TC9: authenticated cannot select video_sources.url (no column privilege)'
);
select is(
  (select count(*)::int from public.video_sources),
  0,
  'TC9: a regular user reads no video_sources rows directly'
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
update public.video_sources set priority = 9 where id = (select id from vs_ids where key = 'https://rls.test/movie');
delete from public.video_sources where id = (select id from vs_ids where key = 'https://rls.test/movie');
reset role;
select is(
  (select count(*)::int from public.video_sources where url = 'https://rls.test/movie' and priority = 0),
  1,
  'TC10: authenticated update/delete of a source by id affects no rows'
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

-- TC13 (regression): only https urls — http media is blocked as mixed content on the HTTPS app
select throws_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'http://example.com/a.m3u8', 'hls' from public.titles where tmdb_id = 900000401$$,
  '23514', null,
  'TC13: http url is rejected'
);
select lives_ok(
  $$insert into public.video_sources (title_id, url, format)
    select id, 'HTTPS://example.com/b.mp4', 'mp4' from public.titles where tmdb_id = 900000401$$,
  'TC13: https url is accepted case-insensitively'
);

-- Fixtures for get_video_sources: published series episode and published movie with
-- active p1, active p0, inactive sources; draft series with an active episode source
insert into public.titles (type, title, tmdb_id, is_published) values
  ('movie', 'VS rpc movie', 900000408, true),
  ('series', 'VS rpc draft series', 900000409, false);
insert into public.seasons (title_id, season_number, name)
  select id, 1, 'VS draft s1' from public.titles where tmdb_id = 900000409;
insert into public.episodes (season_id, episode_number, name)
  select id, 3, 'VS e3' from public.seasons where name = 'VS s1'
  union all
  select id, 1, 'VS draft e1' from public.seasons where name = 'VS draft s1';
insert into public.video_sources (episode_id, url, format, priority, is_active)
  select e.id, v.url, 'hls', v.priority, v.active
    from public.episodes e,
      (values ('https://rpc.test/ep-p1', 1, true), ('https://rpc.test/ep-p0', 0, true),
              ('https://rpc.test/ep-off', 0, false)) v(url, priority, active)
   where e.name = 'VS e3';
insert into public.video_sources (title_id, url, format, priority, is_active)
  select t.id, v.url, 'mp4', v.priority, v.active
    from public.titles t,
      (values ('https://rpc.test/mv-p1', 1, true), ('https://rpc.test/mv-p0', 0, true),
              ('https://rpc.test/mv-off', 0, false)) v(url, priority, active)
   where t.tmdb_id = 900000408;
insert into public.video_sources (episode_id, url, format)
  select id, 'https://rpc.test/draft-ep', 'hls' from public.episodes where name = 'VS draft e1';

insert into vs_ids
  select 'episode', id from public.episodes where name = 'VS e3'
  union all select 'draft episode', id from public.episodes where name = 'VS draft e1'
  union all select 'movie', id from public.titles where tmdb_id = 900000408
  union all select 'draft movie', id from public.titles where tmdb_id = 900000403
  union all select 'series', id from public.titles where tmdb_id = 900000402;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';

-- TC14: active sources of one published episode / movie, in priority order, with urls
select is(
  (select array_agg(g.url order by g.n)
     from public.get_video_sources(p_episode_id => (select id from vs_ids where key = 'episode'))
          with ordinality g(id, url, format, quality, language, priority, n)),
  array['https://rpc.test/ep-p0', 'https://rpc.test/ep-p1'],
  'TC14: get_video_sources returns the active episode sources ordered by priority'
);
select is(
  (select array_agg(g.url order by g.n)
     from public.get_video_sources(p_title_id => (select id from vs_ids where key = 'movie'))
          with ordinality g(id, url, format, quality, language, priority, n)),
  array['https://rpc.test/mv-p0', 'https://rpc.test/mv-p1'],
  'TC14: get_video_sources returns the active movie sources ordered by priority'
);

-- TC15: nothing playable → empty set
select is(
  array[
    (select count(*)::int from public.get_video_sources(p_episode_id => (select id from vs_ids where key = 'draft episode'))),
    (select count(*)::int from public.get_video_sources(p_title_id => (select id from vs_ids where key = 'draft movie'))),
    (select count(*)::int from public.get_video_sources(p_episode_id => -1)),
    (select count(*)::int from public.get_video_sources(p_title_id => (select id from vs_ids where key = 'series')))
  ],
  array[0, 0, 0, 0],
  'TC15: draft series episode, draft movie, unknown id and series id as p_title_id return no sources'
);

-- TC16: exactly one argument; anon cannot execute
select throws_ok(
  $$select * from public.get_video_sources()$$,
  '22023', null,
  'TC16: get_video_sources without arguments is rejected'
);
select throws_ok(
  $$select * from public.get_video_sources(
      p_episode_id => (select id from vs_ids where key = 'episode'),
      p_title_id => (select id from vs_ids where key = 'movie'))$$,
  '22023', null,
  'TC16: get_video_sources with both arguments is rejected'
);
reset role;
set local request.jwt.claims = '';

set local role anon;
select throws_ok(
  $$select * from public.get_video_sources(p_episode_id => (select id from vs_ids where key = 'episode'))$$,
  '42501', null,
  'TC16: anon cannot execute get_video_sources'
);
reset role;

select * from finish();
rollback;
