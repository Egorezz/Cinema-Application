begin;
select plan(13);

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

-- TC3: readable by anon, a regular user and an admin
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000006e1', 'genres-admin@test.local'),
  ('00000000-0000-0000-0000-0000000006e2', 'genres-user@test.local');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000006e1';

set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select is((select count(*)::int from public.genres), 27, 'TC3: anon reads all genres');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000006e2","role":"authenticated"}';
select is((select count(*)::int from public.genres), 27, 'TC3: regular user reads all genres');

-- TC4: not writable by clients, neither by a regular user nor by an admin
select throws_ok(
  $$insert into public.genres (id, name) values (999998, 'Жанр пользователя')$$,
  '42501', null,
  'TC4: regular user insert into genres is rejected (no privilege)'
);

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000006e1","role":"authenticated"}';
select is((select count(*)::int from public.genres), 27, 'TC3: admin reads all genres');
select throws_ok(
  $$insert into public.genres (id, name) values (999999, 'Тестовый жанр')$$,
  '42501', null,
  'TC4: admin insert into genres is rejected (no privilege)'
);
reset role;
select table_privs_are('public', 'genres', 'anon', array['SELECT'], 'TC4: anon has only SELECT on genres');
select table_privs_are('public', 'genres', 'authenticated', array['SELECT'], 'TC4: authenticated has only SELECT on genres');

-- TC5: a genre id used by a title cannot be deleted or renumbered (FK from title_genres, service-role / migration path)
insert into public.titles (type, title) values ('movie', 'TC5 genre in use');
insert into public.title_genres (title_id, genre_id)
select id, 10770 from public.titles where title = 'TC5 genre in use';
select throws_ok(
  $$delete from public.genres where id = 10770$$,
  '23503', null,
  'TC5: deleting a genre used by a title is rejected'
);
select throws_ok(
  $$update public.genres set id = 10771 where id = 10770$$,
  '23503', null,
  'TC5: renumbering a genre used by a title is rejected'
);

select * from finish();
rollback;
