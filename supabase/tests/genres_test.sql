begin;
select plan(8);

-- TC1: table shape
select columns_are(
  'public', 'genres',
  array['id', 'name', 'created_at', 'updated_at'],
  'TC1: genres has exactly the 4 expected columns'
);
select has_trigger('public', 'genres', 'genres_set_updated_at', 'TC1: genres_set_updated_at trigger exists');

-- TC2: the TMDB movie + TV genre lists (27 ids) with Russian names
select is((select count(*)::int from public.genres), 27, 'TC2: genres holds the 27 TMDB movie and TV genres');
select is(
  (select name from public.genres where id = 16),
  'Мультфильм',
  'TC2: TMDB id 16 has the Russian name'
);

-- TC3: readable by anon and authenticated
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000006e1', 'genres-admin@test.local');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000006e1';

set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select is((select count(*)::int from public.genres), 27, 'TC3: anon reads all genres');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000006e1","role":"authenticated"}';
select is((select count(*)::int from public.genres), 27, 'TC3: authenticated reads all genres');

-- TC4: not writable by clients, not even by an admin
select throws_ok(
  $$insert into public.genres (id, name) values (999999, 'Тестовый жанр')$$,
  '42501', null,
  'TC4: admin insert into genres is rejected (no privilege)'
);
reset role;
select table_privs_are(
  'public', 'genres', 'anon', array['SELECT'],
  'TC4: anon has only SELECT on genres'
);

select * from finish();
rollback;
