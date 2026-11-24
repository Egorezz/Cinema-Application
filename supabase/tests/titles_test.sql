begin;
select plan(39);

-- TC1: table shape
select has_table('public', 'titles', 'TC1: public.titles exists');
select columns_are(
  'public', 'titles',
  array[
    'id', 'tmdb_id', 'tvmaze_id', 'type', 'title', 'original_title', 'overview',
    'poster_path', 'backdrop_path', 'year', 'genres', 'rating', 'status',
    'is_published', 'created_at', 'updated_at'
  ],
  'TC1: titles has exactly the 16 card columns'
);
select col_type_is('public', 'titles', 'id', 'bigint', 'TC1: id is bigint');
select col_type_is('public', 'titles', 'genres', 'text[]', 'TC1: genres is text[]');
select col_type_is('public', 'titles', 'rating', 'numeric(3,1)', 'TC1: rating is numeric(3,1)');
select col_type_is('public', 'titles', 'year', 'smallint', 'TC1: year is smallint');
select col_type_is('public', 'titles', 'created_at', 'timestamp with time zone', 'TC1: created_at is timestamptz');
select col_type_is('public', 'titles', 'updated_at', 'timestamp with time zone', 'TC1: updated_at is timestamptz');
select col_is_pk('public', 'titles', 'id', 'TC1: id is the primary key');

-- TC2: tmdb_id unique per type
select lives_ok(
  $$insert into public.titles (type, title, tmdb_id) values ('movie', 'TC2 movie', 900000100)$$,
  'TC2: movie with tmdb_id 900000100 is inserted'
);
select throws_ok(
  $$insert into public.titles (type, title, tmdb_id) values ('movie', 'TC2 movie dup', 900000100)$$,
  '23505', null,
  'TC2: second movie with the same tmdb_id is rejected'
);
select lives_ok(
  $$insert into public.titles (type, title, tmdb_id) values ('series', 'TC2 series', 900000100)$$,
  'TC2: series with the same tmdb_id as a movie is allowed'
);
select throws_ok(
  $$insert into public.titles (type, title, tmdb_id) values ('series', 'TC2 series dup', 900000100)$$,
  '23505', null,
  'TC2: second series with the same tmdb_id is rejected'
);

-- TC3: check constraints
select throws_ok(
  $$insert into public.titles (type, title) values ('cartoon', 'TC3 bad type')$$,
  '23514', null,
  'TC3: unknown type is rejected'
);
select throws_ok(
  $$insert into public.titles (type, title) values ('movie', '  ')$$,
  '23514', null,
  'TC3: blank title is rejected'
);
select throws_ok(
  $$insert into public.titles (type, title) values ('movie', E'\t\n')$$,
  '23514', null,
  'TC3: whitespace-only title (tabs/newlines) is rejected'
);
select lives_ok(
  $$insert into public.titles (type, title, status) values ('series', 'TC3 pilot', 'pilot')$$,
  'TC3: status pilot is allowed'
);
select throws_ok(
  $$insert into public.titles (type, title, rating) values ('movie', 'TC3 bad rating', 11)$$,
  '23514', null,
  'TC3: rating above 10 is rejected'
);
select throws_ok(
  $$insert into public.titles (type, title, status) values ('movie', 'TC3 bad status', 'Released')$$,
  '23514', null,
  'TC3: status outside the allowed set is rejected'
);

-- TC4: tvmaze_id only for series, unique
select throws_ok(
  $$insert into public.titles (type, title, tvmaze_id) values ('movie', 'TC4 movie', 900000005)$$,
  '23514', null,
  'TC4: movie with tvmaze_id is rejected'
);
select lives_ok(
  $$insert into public.titles (type, title, tvmaze_id) values ('series', 'TC4 series', 900000005)$$,
  'TC4: series with tvmaze_id 900000005 is inserted'
);
select throws_ok(
  $$insert into public.titles (type, title, tvmaze_id) values ('series', 'TC4 series dup', 900000005)$$,
  '23505', null,
  'TC4: second series with the same tvmaze_id is rejected'
);

-- TC5: defaults
select lives_ok(
  $$insert into public.titles (type, title) values ('movie', 'TC5 defaults')$$,
  'TC5: row with only type and title is inserted'
);
select is(
  (select is_published from public.titles where title = 'TC5 defaults'),
  false,
  'TC5: is_published defaults to false'
);
select is(
  (select genres from public.titles where title = 'TC5 defaults'),
  '{}'::text[],
  'TC5: genres defaults to an empty array'
);
select ok(
  (select created_at is not null and updated_at is not null
     from public.titles where title = 'TC5 defaults'),
  'TC5: created_at and updated_at are set'
);
select ok(
  (select id is not null from public.titles where title = 'TC5 defaults'),
  'TC5: id is generated'
);

-- TC6: updated_at trigger
select has_trigger('public', 'titles', 'titles_set_updated_at', 'TC6: titles_set_updated_at trigger exists');
insert into public.titles (type, title, updated_at) values ('movie', 'TC6 old', '2000-01-01');
update public.titles set title = 'TC6 new' where title = 'TC6 old';
select ok(
  (select updated_at > '2000-01-01'::timestamptz from public.titles where title = 'TC6 new'),
  'TC6: updated_at is refreshed on update'
);

-- TC7: RLS for anon
select ok(
  (select relrowsecurity from pg_class where oid = 'public.titles'::regclass),
  'TC7: RLS is enabled on public.titles'
);
select policies_are(
  'public', 'titles',
  array['titles_select_published_or_admin', 'titles_insert_admin', 'titles_update_admin', 'titles_delete_admin'],
  'TC7: titles has the published-or-admin select policy and admin-only write policies'
);

insert into public.titles (type, title, is_published) values
  ('movie', 'RLS published', true),
  ('movie', 'RLS draft', false);

set local role anon;
select is(
  (select array_agg(title order by title) from public.titles where title like 'RLS %'),
  array['RLS published'],
  'TC7: anon sees only published titles'
);
reset role;

-- TC9: RLS for authenticated
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(
  (select array_agg(title order by title) from public.titles where title like 'RLS %'),
  array['RLS published'],
  'TC9: authenticated sees only published titles'
);
reset role;

-- TC10: non-admin clients cannot write titles (anon has no write grants; authenticated is filtered by admin-only policies)
set local role anon;
select throws_ok(
  $$insert into public.titles (type, title) values ('movie', 'RLS anon insert')$$,
  '42501', null,
  'TC10: anon insert is rejected'
);
select throws_ok(
  $$update public.titles set title = 'RLS anon hacked' where title = 'RLS published'$$,
  '42501', null,
  'TC10: anon update of titles is denied'
);
select throws_ok(
  $$delete from public.titles where title = 'RLS published'$$,
  '42501', null,
  'TC10: anon delete of titles is denied'
);
reset role;
select is(
  (select count(*)::int from public.titles where title = 'RLS published'),
  1,
  'TC10: anon update/delete of a published title affects no rows'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$insert into public.titles (type, title) values ('movie', 'RLS user insert')$$,
  '42501', null,
  'TC10: authenticated insert is rejected by RLS'
);
update public.titles set title = 'RLS user hacked' where title = 'RLS published';
delete from public.titles where title = 'RLS published';
reset role;
select is(
  (select count(*)::int from public.titles where title = 'RLS published'),
  1,
  'TC10: authenticated update/delete of a published title affects no rows'
);

select * from finish();
rollback;
