begin;
select plan(18);

-- TC1: guard — every FK in public has an index whose leading columns are the FK columns
select is(
  (select array_agg(c.conrelid::regclass::text || '.' || c.conname order by c.conrelid::regclass::text, c.conname)
     from pg_constraint c
    where c.contype = 'f'
      and c.connamespace = 'public'::regnamespace
      and not exists (
        select 1 from pg_index i
         where i.indrelid = c.conrelid
           and i.indpred is null
           and i.indisvalid
           and array(select unnest((i.indkey::int2[])[0:cardinality(c.conkey) - 1]))
             = array(select unnest(c.conkey))
      )),
  null,
  'TC1: every foreign key in public has an index with the FK columns as leading columns'
);

-- TC2: air_date index for the daily digest
select has_index(
  'public', 'episodes', 'episodes_air_date_idx', array['air_date'],
  'TC2: episodes.air_date is indexed'
);

-- Fixtures: admin (0a10a) and regular user (0a10b); published series P with S2 inserted before S1
-- (ids do not follow the order) and specials S0; draft series D with S1
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a10a', 'nav-admin@test.local'),
  ('00000000-0000-0000-0000-00000000a10b', 'nav-user@test.local');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-00000000a10a';

insert into public.titles (type, title, tmdb_id, is_published) values
  ('series', 'NAV published series', 900001001, true),
  ('series', 'NAV draft series', 900001002, false);

insert into public.seasons (title_id, season_number)
  select t.id, n.season_number
    from public.titles t
    cross join (values (2), (1), (0)) as n (season_number)
   where t.tmdb_id = 900001001;
insert into public.seasons (title_id, season_number)
  select id, 1 from public.titles where tmdb_id = 900001002;

insert into public.episodes (season_id, episode_number)
  select s.id, g.n
    from public.seasons s
    join public.titles t on t.id = s.title_id
    cross join lateral generate_series(1, case when t.tmdb_id = 900001001 and s.season_number = 1 then 3 else 2 end) as g (n)
   where t.tmdb_id in (900001001, 900001002)
   order by s.id, g.n;

-- Episode ids keyed by "<tmdb_id>:<season>:<episode>", readable by the test roles
create temp table nav_ids as
  select t.tmdb_id || ':' || s.season_number || ':' || e.episode_number as k, e.id
    from public.episodes e
    join public.seasons s on s.id = e.season_id
    join public.titles t on t.id = s.title_id
   where t.tmdb_id in (900001001, 900001002);
grant select on nav_ids to authenticated;

-- Regular user
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000a10b","role":"authenticated"}';

-- TC3: last episode of season 1 → first episode of season 2
select is(
  public.get_next_episode((select id from nav_ids where k = '900001001:1:3')),
  (select id from nav_ids where k = '900001001:2:1'),
  'TC3: next of S1E3 is S2E1 (crosses season boundary)'
);

-- TC4: within a season
select is(
  public.get_next_episode((select id from nav_ids where k = '900001001:1:1')),
  (select id from nav_ids where k = '900001001:1:2'),
  'TC4: next of S1E1 is S1E2'
);

-- TC5: last episode of the series
select is(
  public.get_next_episode((select id from nav_ids where k = '900001001:2:2')),
  null,
  'TC5: next of the last episode of the series is null'
);

-- TC6: prev is symmetric and does not jump into specials
select is(
  public.get_prev_episode((select id from nav_ids where k = '900001001:2:1')),
  (select id from nav_ids where k = '900001001:1:3'),
  'TC6: prev of S2E1 is S1E3'
);
select is(
  public.get_prev_episode((select id from nav_ids where k = '900001001:1:1')),
  null,
  'TC6: prev of S1E1 is null (specials are not entered)'
);

-- TC7: specials are navigated within season 0 only
select is(
  public.get_next_episode((select id from nav_ids where k = '900001001:0:1')),
  (select id from nav_ids where k = '900001001:0:2'),
  'TC7: next of S0E1 is S0E2'
);
select is(
  public.get_next_episode((select id from nav_ids where k = '900001001:0:2')),
  null,
  'TC7: next of the last special is null (regular seasons are not entered)'
);
select is(
  public.get_prev_episode((select id from nav_ids where k = '900001001:0:2')),
  (select id from nav_ids where k = '900001001:0:1'),
  'TC7: prev of S0E2 is S0E1'
);

-- TC8: unknown id and draft series
select is(
  public.get_next_episode(-1),
  null,
  'TC8: unknown episode id returns null'
);
select is(
  public.get_next_episode((select id from nav_ids where k = '900001002:1:1')),
  null,
  'TC8: regular user gets null for an episode of a draft series'
);

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000a10a","role":"authenticated"}';
select is(
  public.get_next_episode((select id from nav_ids where k = '900001002:1:1')),
  null,
  'TC8: admin gets null for an episode of a draft series (explicit is_published filter)'
);
select is(
  public.get_prev_episode((select id from nav_ids where k = '900001002:1:2')),
  null,
  'TC8: admin gets null from prev for an episode of a draft series (explicit is_published filter)'
);

reset role;

-- TC9: execute only for authenticated
select ok(
  not has_function_privilege('anon', 'public.get_next_episode(bigint)', 'execute'),
  'TC9: anon cannot execute get_next_episode'
);
select ok(
  has_function_privilege('authenticated', 'public.get_next_episode(bigint)', 'execute'),
  'TC9: authenticated can execute get_next_episode'
);
select ok(
  not has_function_privilege('anon', 'public.get_prev_episode(bigint)', 'execute'),
  'TC9: anon cannot execute get_prev_episode'
);
select ok(
  has_function_privilege('authenticated', 'public.get_prev_episode(bigint)', 'execute'),
  'TC9: authenticated can execute get_prev_episode'
);

select * from finish();
rollback;
