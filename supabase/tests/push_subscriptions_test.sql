begin;
select plan(23);

-- TC1: table shape
select columns_are(
  'public', 'push_subscriptions',
  array['id', 'user_id', 'endpoint', 'p256dh', 'auth', 'user_agent', 'created_at', 'last_seen_at'],
  'TC1: push_subscriptions has exactly the 8 expected columns'
);
select col_is_pk('public', 'push_subscriptions', 'id', 'TC1: id is the primary key');
select has_index(
  'public', 'push_subscriptions', 'push_subscriptions_user_id_idx', 'user_id',
  'TC1: user_id has its own index'
);

-- Fixtures
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a7', 'authenticated', 'authenticated', 'push-a@test.local'),
  ('00000000-0000-0000-0000-0000000000b7', 'authenticated', 'authenticated', 'push-b@test.local');

-- Ids returned by the RPC, compared across cases.
create temp table push_ids (label text primary key, id bigint);
grant select, insert on push_ids to authenticated;

-- TC2: one user, several devices
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a7","role":"authenticated"}';
insert into push_ids
  select 'e1_first', public.register_push_subscription('https://fcm.googleapis.com/fcm/send/e1', 'k1', 'a1', 'ua1');
insert into push_ids
  select 'e2', public.register_push_subscription('https://fcm.googleapis.com/fcm/send/e2', 'k1', 'a1', 'ua1');
select is(
  (select count(*)::int from public.push_subscriptions),
  2,
  'TC2: user A has two devices'
);

-- TC3: re-register the same endpoint refreshes the row in place
reset role;
update public.push_subscriptions set last_seen_at = now() - interval '1 day'
  where endpoint = 'https://fcm.googleapis.com/fcm/send/e1';
set local role authenticated;
insert into push_ids
  select 'e1_again', public.register_push_subscription('https://fcm.googleapis.com/fcm/send/e1', 'k2', 'a2', 'ua2');
select is(
  (select id from push_ids where label = 'e1_again'),
  (select id from push_ids where label = 'e1_first'),
  'TC3: re-register returns the same id'
);
select is(
  (select count(*)::int from public.push_subscriptions where endpoint = 'https://fcm.googleapis.com/fcm/send/e1'),
  1,
  'TC3: re-register keeps one row for the endpoint'
);
select is(
  (select p256dh || '/' || auth || '/' || user_agent from public.push_subscriptions
    where endpoint = 'https://fcm.googleapis.com/fcm/send/e1'),
  'k2/a2/ua2',
  'TC3: re-register updates keys and user agent'
);
select ok(
  (select last_seen_at > now() - interval '1 day' from public.push_subscriptions
    where endpoint = 'https://fcm.googleapis.com/fcm/send/e1'),
  'TC3: re-register bumps last_seen_at'
);

-- TC4: another user registering the same endpoint takes the row over
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b7","role":"authenticated"}';
insert into push_ids
  select 'e1_by_b', public.register_push_subscription('https://fcm.googleapis.com/fcm/send/e1', 'k3', 'a3', 'ua3');
reset role;
select is(
  (select array_agg(user_id) from public.push_subscriptions where endpoint = 'https://fcm.googleapis.com/fcm/send/e1'),
  array['00000000-0000-0000-0000-0000000000b7']::uuid[],
  'TC4: endpoint row is moved to user B (still one row)'
);
select is(
  (select array_agg(endpoint) from public.push_subscriptions
    where user_id = '00000000-0000-0000-0000-0000000000a7'),
  array['https://fcm.googleapis.com/fcm/send/e2'],
  'TC4: user A keeps only E2'
);

-- TC5: integrity checks
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a7","role":"authenticated"}';
select throws_ok(
  $$select public.register_push_subscription('http://fcm.googleapis.com/fcm/send/x', 'k', 'a')$$,
  '23514', null,
  'TC5: non-https endpoint is rejected'
);
select throws_ok(
  $$select public.register_push_subscription('https://fcm.googleapis.com/fcm/send/e3', '', 'a')$$,
  '23514', null,
  'TC5: empty p256dh is rejected'
);
select throws_ok(
  $$select public.register_push_subscription('https://evil.test/hook', 'k', 'a')$$,
  '23514', null,
  'TC5: endpoint outside known push services is rejected'
);
select throws_ok(
  $$select public.register_push_subscription('https://fcm.googleapis.com/fcm/send/e3', 'k', 'a', repeat('x', 513))$$,
  '23514', null,
  'TC5: too long user_agent is rejected'
);

-- TC6: owner only, no direct writes
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b7","role":"authenticated"}';
select is(
  (select array_agg(endpoint) from public.push_subscriptions),
  array['https://fcm.googleapis.com/fcm/send/e1'],
  'TC6: user B sees only own row'
);
delete from public.push_subscriptions where endpoint = 'https://fcm.googleapis.com/fcm/send/e2';
reset role;
select ok(
  exists (select 1 from public.push_subscriptions
    where endpoint = 'https://fcm.googleapis.com/fcm/send/e2' and user_id = '00000000-0000-0000-0000-0000000000a7'),
  'TC6: user B delete left A row untouched'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a7","role":"authenticated"}';
select throws_ok(
  $$insert into public.push_subscriptions (user_id, endpoint, p256dh, auth)
    values ('00000000-0000-0000-0000-0000000000a7', 'https://fcm.googleapis.com/fcm/send/e3', 'k', 'a')$$,
  '42501', null,
  'TC6: direct insert is rejected'
);
select throws_ok(
  $$update public.push_subscriptions set last_seen_at = now()$$,
  '42501', null,
  'TC6: direct update is rejected'
);

-- TC7: own delete (logout)
delete from public.push_subscriptions where endpoint = 'https://fcm.googleapis.com/fcm/send/e2';
select is(
  (select count(*)::int from public.push_subscriptions),
  0,
  'TC7: user A can delete own row'
);

-- TC8: anon and calls without a user
reset role;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select throws_ok(
  $$select count(*) from public.push_subscriptions$$,
  '42501', null,
  'TC8: anon select is rejected'
);
select throws_ok(
  $$select public.register_push_subscription('https://fcm.googleapis.com/fcm/send/e3', 'k', 'a')$$,
  '42501', null,
  'TC8: anon cannot call register_push_subscription'
);
reset role;
set local role authenticated;
set local request.jwt.claims = '{"role":"authenticated"}';
select throws_ok(
  $$select public.register_push_subscription('https://fcm.googleapis.com/fcm/send/e3', 'k', 'a')$$,
  '42501', null,
  'TC8: register without auth.uid() is rejected'
);
reset role;

-- TC9: cascade on user delete
delete from auth.users where id = '00000000-0000-0000-0000-0000000000b7';
select is(
  (select count(*)::int from public.push_subscriptions where user_id = '00000000-0000-0000-0000-0000000000b7'),
  0,
  'TC9: deleting a user removes their push subscriptions'
);

select * from finish();
rollback;
