begin;
select plan(18);

-- TC1: table shape
select columns_are(
  'public', 'subscriptions',
  array['user_id', 'title_id', 'is_muted', 'created_at'],
  'TC1: subscriptions has exactly the 4 expected columns'
);

-- Fixtures
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a6', 'authenticated', 'authenticated', 'sub-a@test.local'),
  ('00000000-0000-0000-0000-0000000000b6', 'authenticated', 'authenticated', 'sub-b@test.local');
insert into public.titles (type, title, tmdb_id, is_published) values
  ('series', 'SUB series 1', 900000601, true),
  ('series', 'SUB series 2', 900000602, true),
  ('movie', 'SUB movie 1', 900000603, true),
  ('series', 'SUB draft series', 900000604, false);

-- Drafts are invisible to authenticated (RLS), so their ids are resolved up front.
create temp table sub_draft_ids as
  select (select id from public.titles where tmdb_id = 900000604) as draft_series_id;
grant select on sub_draft_ids to authenticated;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a6","role":"authenticated"}';

-- TC2: only published series; one and the same error
select throws_ok(
  $$insert into public.subscriptions (title_id)
    select id from public.titles where tmdb_id = 900000603$$,
  '23503', null,
  'TC2: subscription to a published movie is rejected'
);
select throws_ok(
  $$insert into public.subscriptions (title_id)
    select draft_series_id from sub_draft_ids$$,
  '23503', null,
  'TC2: subscription to a draft series is rejected'
);
select throws_ok(
  $$insert into public.subscriptions (title_id) values (999999999)$$,
  '23503', null,
  'TC2: subscription to a non-existent title is rejected'
);

-- TC3: re-subscribe creates no duplicate
insert into public.subscriptions (title_id)
  select id from public.titles where tmdb_id = 900000601
  on conflict (user_id, title_id) do nothing;
insert into public.subscriptions (title_id)
  select id from public.titles where tmdb_id = 900000601
  on conflict (user_id, title_id) do nothing;
select is(
  (select count(*)::int from public.subscriptions
    where title_id = (select id from public.titles where tmdb_id = 900000601)),
  1,
  'TC3: repeated do-nothing subscribe keeps exactly one row'
);
select throws_ok(
  $$insert into public.subscriptions (title_id)
    select id from public.titles where tmdb_id = 900000601$$,
  '23505', null,
  'TC3: plain duplicate subscribe is rejected'
);

-- TC4: mute, re-subscribe keeps the mute, key columns are not updatable
update public.subscriptions set is_muted = true
  where title_id = (select id from public.titles where tmdb_id = 900000601);
select is(
  (select is_muted from public.subscriptions
    where title_id = (select id from public.titles where tmdb_id = 900000601)),
  true,
  'TC4: user A can mute own subscription'
);
insert into public.subscriptions (title_id)
  select id from public.titles where tmdb_id = 900000601
  on conflict (user_id, title_id) do nothing;
select is(
  (select count(*)::int || '/' || bool_and(is_muted) from public.subscriptions
    where title_id = (select id from public.titles where tmdb_id = 900000601)),
  '1/true',
  'TC4: re-subscribe keeps one row and does not reset is_muted'
);
select throws_ok(
  $$update public.subscriptions
    set title_id = (select id from public.titles where tmdb_id = 900000602)
    where title_id = (select id from public.titles where tmdb_id = 900000601)$$,
  '42501', null,
  'TC4: title_id cannot be updated'
);

-- TC5: owner only
insert into public.subscriptions (title_id)
  select id from public.titles where tmdb_id = 900000602
  on conflict (user_id, title_id) do nothing;
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b6","role":"authenticated"}';
select is(
  (select count(*)::int from public.subscriptions),
  0,
  'TC5: user B sees none of A rows'
);
update public.subscriptions set is_muted = not is_muted;
delete from public.subscriptions;
select throws_ok(
  $$insert into public.subscriptions (user_id, title_id)
    select '00000000-0000-0000-0000-0000000000a6', id from public.titles where tmdb_id = 900000602$$,
  '42501', null,
  'TC5: user B cannot insert a row for user A'
);
reset role;
select is(
  (select array_agg(is_muted order by title_id)
    from public.subscriptions where user_id = '00000000-0000-0000-0000-0000000000a6'),
  array[true, false],
  'TC5: user B update/delete left A rows untouched'
);

-- TC6: own delete, anon has no access
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a6","role":"authenticated"}';
delete from public.subscriptions
  where title_id = (select id from public.titles where tmdb_id = 900000602);
select is(
  (select count(*)::int from public.subscriptions),
  1,
  'TC6: user A can delete own subscription'
);
reset role;
set local role anon;
select throws_ok(
  $$select count(*) from public.subscriptions$$,
  '42501', null,
  'TC6: anon select is rejected'
);
select throws_ok(
  $$insert into public.subscriptions (user_id, title_id)
    select '00000000-0000-0000-0000-0000000000a6', id from public.titles where tmdb_id = 900000601$$,
  '42501', null,
  'TC6: anon insert is rejected'
);
reset role;

-- TC7: series type cannot change while only subscriptions reference it
select throws_ok(
  $$update public.titles set type = 'movie' where tmdb_id = 900000601$$,
  '23514', null,
  'TC7: series type change is rejected while it has subscriptions'
);

-- TC8: cascades
insert into public.subscriptions (user_id, title_id)
  select '00000000-0000-0000-0000-0000000000b6', id from public.titles where tmdb_id = 900000602;
delete from public.titles where tmdb_id = 900000602;
select is(
  (select count(*)::int from public.subscriptions where user_id = '00000000-0000-0000-0000-0000000000b6'),
  0,
  'TC8: deleting a title removes its subscriptions'
);
delete from auth.users where id = '00000000-0000-0000-0000-0000000000a6';
select is(
  (select count(*)::int from public.subscriptions where user_id = '00000000-0000-0000-0000-0000000000a6'),
  0,
  'TC8: deleting a user removes their subscriptions'
);

select * from finish();
rollback;
