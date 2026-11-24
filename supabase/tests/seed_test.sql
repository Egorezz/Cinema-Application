begin;
select plan(14);

-- Every check is scoped to the seed fixtures, so the suite stays green after local
-- imports / edits. Seed titles: movies by tmdb_id, draft and series by title.
create temporary view seed_titles as
  select t.* from public.titles t
  where t.tmdb_id in (10378, 45745, 133701)
     or (t.tmdb_id is null and t.title in ('Черновик: тестовый поток', 'Тестовые потоки', 'Открытые фильмы Blender'));
grant select on seed_titles to anon, authenticated;

-- TC1: published movies with active sources, draft movie exists
select is(
  (select array_agg(t.tmdb_id order by t.tmdb_id) from seed_titles t
    where t.type = 'movie' and t.is_published),
  array[10378, 45745, 133701],
  'TC1: the 3 seeded movies are published'
);
select is(
  (select count(*)::int from seed_titles t
    where t.type = 'movie' and t.is_published
      and not exists (select 1 from public.video_sources v where v.title_id = t.id and v.is_active)),
  0,
  'TC1: every published seed movie has an active source'
);
select is(
  (select count(*)::int from seed_titles where type = 'movie' and not is_published),
  1,
  'TC1: the seed draft movie is unpublished'
);

-- TC2: each seed series = seasons 1..2 x 3 episodes, every episode has an active source
select is(
  (select count(*)::int from seed_titles where type = 'series' and is_published),
  2,
  'TC2: 2 published seed series'
);
select is(
  (select array_agg(x.label order by x.label) from (
     select t.title || ' S' || s.season_number || ':' || count(e.id) as label
       from seed_titles t
       join public.seasons s on s.title_id = t.id
       left join public.episodes e on e.season_id = s.id
      where t.type = 'series'
      group by t.title, s.season_number
   ) x),
  array[
    'Открытые фильмы Blender S1:3', 'Открытые фильмы Blender S2:3',
    'Тестовые потоки S1:3', 'Тестовые потоки S2:3'
  ],
  'TC2: each seed series has seasons 1 and 2 with 3 episodes each'
);
select is(
  (select count(*)::int from seed_titles t
     join public.seasons s on s.title_id = t.id
     join public.episodes e on e.season_id = s.id
    where not exists (select 1 from public.video_sources v where v.episode_id = e.id and v.is_active)),
  0,
  'TC2: every seed episode has an active source'
);

-- TC3: https urls, format matches extension (seed sources only)
select is(
  (select count(*)::int from public.video_sources v
    where (v.title_id in (select id from seed_titles)
           or v.episode_id in (select e.id from public.episodes e
                                 join public.seasons s on s.id = e.season_id
                                 join seed_titles t on t.id = s.title_id))
      and (v.url !~ '^https://'
           or (v.url ~ '\.m3u8$' and v.format <> 'hls')
           or (v.url ~ '\.mp4$' and v.format <> 'mp4')
           or (v.url !~ '\.m3u8$' and v.url !~ '\.mp4$'))),
  0,
  'TC3: seed source urls are https and format matches the extension'
);

-- TC4: admin vs user
select ok(
  (select u.email_confirmed_at is not null
      and exists (select 1 from auth.identities i where i.user_id = u.id)
     from auth.users u where u.id = '00000000-0000-0000-0000-5eed00000001'),
  'TC4: admin seed user is confirmed and has an identity'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-5eed00000001","role":"authenticated"}';
select ok(public.is_admin(), 'TC4: admin seed user is_admin()');

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-5eed00000002","role":"authenticated"}';
select ok(not public.is_admin(), 'TC4: regular seed user is not admin');

-- TC5: visibility for a regular user (draft checked by title_id: its url is shared with an episode)
select is(
  (select count(*)::int from public.video_sources v
    join seed_titles t on t.id = v.title_id
   where t.type = 'movie' and t.is_published),
  4,
  'TC5: user sees the active sources of the 3 published seed movies'
);
select is(
  (select count(*)::int from public.video_sources v
    join seed_titles t on t.id = v.title_id
   where not t.is_published),
  0,
  'TC5: user does not see the draft movie sources'
);

reset role;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select is(
  (select count(*)::int from public.titles t
    where t.id in (select id from seed_titles)),
  5,
  'TC5: anon sees the 5 published seed titles'
);
select is(
  (select count(*)::int from public.video_sources),
  0,
  'TC5: anon sees no video_sources'
);

select * from finish();
rollback;
