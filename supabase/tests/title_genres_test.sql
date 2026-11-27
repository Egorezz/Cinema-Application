begin;
select plan(31);

-- TC1: table shape (pure junction: keys only, no timestamps)
select columns_are(
  'public', 'title_genres',
  array['title_id', 'genre_id'],
  'TC1: title_genres has exactly the 2 key columns'
);
select col_is_pk('public', 'title_genres', array['title_id', 'genre_id'], 'TC1: primary key is (title_id, genre_id)');
select fk_ok('public', 'title_genres', 'title_id', 'public', 'titles', 'id', 'TC1: title_id references titles');
select fk_ok('public', 'title_genres', 'genre_id', 'public', 'genres', 'id', 'TC1: genre_id references genres');
select has_index('public', 'title_genres', 'title_genres_genre_id_idx', 'TC1: title_genres_genre_id_idx exists');

-- TC2: no duplicates; deleting a title removes its genre rows
insert into public.titles (type, title) values ('movie', 'TG cascade');
insert into public.title_genres (title_id, genre_id)
select id, 16 from public.titles where title = 'TG cascade';
select throws_ok(
  $$insert into public.title_genres (title_id, genre_id)
    select id, 16 from public.titles where title = 'TG cascade'$$,
  '23505', null,
  'TC2: the same (title, genre) pair cannot be inserted twice'
);
create temporary table tg_cascade_id as select id from public.titles where title = 'TG cascade';
delete from public.titles where title = 'TG cascade';
select is(
  (select count(*)::int from public.title_genres where title_id = (select id from tg_cascade_id)),
  0,
  'TC2: deleting a title removes its title_genres rows'
);

-- TC3: the array column's trigger functions are gone
select hasnt_function('public', 'titles_check_genre_ids', 'TC3: titles_check_genre_ids() is dropped');
select hasnt_function('public', 'genres_check_not_in_use', 'TC3: genres_check_not_in_use() is dropped');

-- Fixtures: published P with genre 16, draft D with genre 35; admin and regular user
insert into public.titles (type, title, is_published) values
  ('movie', 'TG P', true),
  ('movie', 'TG D', false);
insert into public.title_genres (title_id, genre_id)
select t.id, g.genre_id
  from (values ('TG P', 16), ('TG D', 35)) as g(title, genre_id)
  join public.titles t on t.title = g.title;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000007a1', 'tg-admin@test.local'),
  ('00000000-0000-0000-0000-0000000007a2', 'tg-user@test.local');
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000007a1';

-- Fixture ids in a temp table, so visibility checks depend only on title_genres RLS (not on titles RLS).
create temporary table tg_ids as select id, title from public.titles where title in ('TG P', 'TG D');
grant select on tg_ids to anon, authenticated;
create temporary view tg_rows with (security_invoker = true) as
  select i.title || ':' || tg.genre_id as label
    from public.title_genres tg
    join tg_ids i on i.id = tg.title_id;
grant select on tg_rows to anon, authenticated;
create temporary view tg_p_genres with (security_invoker = true) as
  select array_agg(tg.genre_id order by tg.genre_id) as ids
    from public.title_genres tg
    join public.titles t on t.id = tg.title_id
   where t.title = 'TG P';
grant select on tg_p_genres to authenticated;

-- TC4: read access — anon and regular user see only the published title's genres, admin sees all
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select is(
  (select array_agg(label order by label) from tg_rows),
  array['TG P:16'],
  'TC4: anon sees only genres of published titles'
);
-- TC5: anon cannot write
select throws_ok(
  $$insert into public.title_genres (title_id, genre_id)
    select id, 14 from public.titles where title = 'TG P'$$,
  '42501', null,
  'TC5: anon insert into title_genres is rejected'
);
-- TC9: anon cannot call set_title_genres
select throws_ok(
  $$select public.set_title_genres((select id from public.titles where title = 'TG P'), '{}')$$,
  '42501', null,
  'TC9: anon call of set_title_genres is rejected'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000007a2","role":"authenticated"}';
select is(
  (select array_agg(label order by label) from tg_rows),
  array['TG P:16'],
  'TC4: regular user sees only genres of published titles'
);
-- TC5: regular user cannot write directly
select throws_ok(
  $$insert into public.title_genres (title_id, genre_id)
    select id, 14 from public.titles where title = 'TG P'$$,
  '42501', null,
  'TC5: regular user insert into title_genres is rejected (no privilege)'
);
select throws_ok(
  $$delete from public.title_genres where genre_id = 16
    and title_id = (select id from public.titles where title = 'TG P')$$,
  '42501', null,
  'TC5: regular user delete from title_genres is rejected (no privilege)'
);
-- TC9: regular user cannot call set_title_genres (even with an empty set)
select throws_ok(
  $$select public.set_title_genres((select id from public.titles where title = 'TG P'), '{}')$$,
  '42501', null,
  'TC9: regular user call of set_title_genres is rejected'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000007a1","role":"authenticated"}';
select is(
  (select array_agg(label order by label) from tg_rows),
  array['TG D:35', 'TG P:16'],
  'TC4: admin sees genres of published and draft titles'
);
-- TC5: even an admin cannot write directly (only via set_title_genres)
select throws_ok(
  $$insert into public.title_genres (title_id, genre_id)
    select id, 14 from public.titles where title = 'TG P'$$,
  '42501', null,
  'TC5: admin direct insert into title_genres is rejected'
);
select throws_ok(
  $$delete from public.title_genres
    where title_id = (select id from public.titles where title = 'TG P')$$,
  '42501', null,
  'TC5: admin direct delete from title_genres is rejected'
);

-- TC6: set_title_genres replaces the set (dedupes) and clears it
select public.set_title_genres((select id from public.titles where title = 'TG P'), '{14,16,16}');
select is((select ids from tg_p_genres), array[14, 16], 'TC6: set_title_genres sets exactly {14,16} (deduped)');
select public.set_title_genres((select id from public.titles where title = 'TG P'), '{}');
select is((select ids from tg_p_genres), null::integer[], 'TC6: set_title_genres with an empty array clears the set');

-- TC7: unknown genre id fails the whole call, the previous set stays
select public.set_title_genres((select id from public.titles where title = 'TG P'), '{14,16}');
select throws_ok(
  $$select public.set_title_genres((select id from public.titles where title = 'TG P'), '{14,999999}')$$,
  '23503', null,
  'TC7: set_title_genres with an unknown genre id is rejected'
);
select is((select ids from tg_p_genres), array[14, 16], 'TC7: the previous genre set is unchanged');

-- TC8: invalid arguments
select throws_ok(
  $$select public.set_title_genres((select id from public.titles where title = 'TG P'), null)$$,
  '22023', null,
  'TC8: null genre array is rejected'
);
select throws_ok(
  $$select public.set_title_genres((select id from public.titles where title = 'TG P'), '{16,null}')$$,
  '22023', null,
  'TC8: a null element in the genre array is rejected'
);
select throws_ok(
  $$select public.set_title_genres(-1, '{16}')$$,
  '23503', null,
  'TC8: a missing title id is rejected'
);
reset role;

-- TC9: the guard fails closed — postgres without a JWT is rejected; a service-role JWT may call it
-- (reset role keeps the admin claims set above, so clear them first)
select set_config('request.jwt.claims', '', true);
select throws_ok(
  $$select public.set_title_genres((select id from public.titles where title = 'TG D'), '{35,18}')$$,
  '42501', null,
  'TC9: a caller without an admin session or service-role JWT is rejected'
);
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
select lives_ok(
  $$select public.set_title_genres((select id from public.titles where title = 'TG D'), '{35,18}')$$,
  'TC9: service_role can call set_title_genres'
);
reset role;
select ok(
  has_function_privilege('service_role', 'public.set_title_genres(bigint,integer[])', 'execute'),
  'TC9: service_role can execute set_title_genres'
);

-- TC5: grants
select table_privs_are('public', 'title_genres', 'anon', array['SELECT'], 'TC5: anon has only SELECT on title_genres');
select table_privs_are(
  'public', 'title_genres', 'authenticated', array['SELECT'],
  'TC5: authenticated has only SELECT on title_genres'
);

select * from finish();
rollback;
