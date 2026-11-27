begin;
select plan(34);

-- Fixtures: A (metadata display_name), B (email only), admin (role set by SQL as postgres)
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', '{"display_name":"Alice"}'),
  ('00000000-0000-0000-0000-00000000000b', 'bob@test.local', null),
  ('00000000-0000-0000-0000-00000000000c', 'admin@test.local', null);
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-00000000000c';

-- TC1: table shape
select columns_are(
  'public', 'profiles',
  array['id', 'display_name', 'avatar_url', 'role', 'notifications_enabled', 'created_at', 'updated_at'],
  'TC1: profiles has exactly the 7 planned columns'
);
select col_is_pk('public', 'profiles', 'id', 'TC1: id is the primary key');
select fk_ok('public', 'profiles', 'id', 'auth', 'users', 'id', 'TC1: profiles.id references auth.users.id');

-- TC2: signup trigger creates exactly one profile per user
select is(
  (select count(*)::int from public.profiles
    where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b')),
  2,
  'TC2: exactly one profile per signed-up user'
);
select results_eq(
  $$select display_name, role, notifications_enabled from public.profiles
     where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b')
     order by id$$,
  $$values ('Alice'::text, 'user'::text, true), ('bob'::text, 'user'::text, true)$$,
  'TC2: display_name from metadata else email local part, role user, notifications on'
);
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000e', 'jdoe123@test.local', '{"full_name":"  John Doe  "}'),
  ('00000000-0000-0000-0000-00000000000f', 'long@test.local',
   jsonb_build_object('display_name', repeat('x', 49) || ' tail'));
select results_eq(
  $$select display_name from public.profiles
     where id in ('00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000f')
     order by id$$,
  $$values ('John Doe'::text), (repeat('x', 49))$$,
  'TC2: OAuth full_name is used (trimmed); a name cut at 50 chars has no trailing space'
);

-- TC10–TC13: avatar_url from OAuth metadata (avatar_url, else picture); invalid values never break signup
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000001a1', 'g@test.local',
   '{"full_name":"G User","avatar_url":"https://lh3.googleusercontent.com/a/1","picture":"https://lh3.googleusercontent.com/a/1"}'),
  ('00000000-0000-0000-0000-0000000001a2', 'p@test.local', '{"name":"P","picture":"https://p.test/pic.jpg"}'),
  ('00000000-0000-0000-0000-0000000001a3', 'both@test.local',
   '{"avatar_url":"https://a.test/1.png","picture":"https://p.test/2.png"}'),
  ('00000000-0000-0000-0000-0000000001a4', 'pad@test.local', '{"avatar_url":"  https://a.test/x.png  "}'),
  ('00000000-0000-0000-0000-0000000001a5', 'js@test.local', '{"avatar_url":"javascript:alert(1)"}'),
  ('00000000-0000-0000-0000-0000000001a6', 'ftp@test.local', '{"avatar_url":"ftp://x"}'),
  ('00000000-0000-0000-0000-0000000001a7', 'blank@test.local', '{"avatar_url":"   "}'),
  ('00000000-0000-0000-0000-0000000001a8', 'num@test.local', '{"avatar_url":123}'),
  ('00000000-0000-0000-0000-0000000001a9', 'obj@test.local', '{"avatar_url":{"x":1}}'),
  ('00000000-0000-0000-0000-0000000001aa', 'mix@test.local',
   '{"avatar_url":"ftp://x","picture":"https://p.test/ok.png"}');

select results_eq(
  $$select avatar_url, display_name from public.profiles where id = '00000000-0000-0000-0000-0000000001a1'$$,
  $$values ('https://lh3.googleusercontent.com/a/1'::text, 'G User'::text)$$,
  'TC10: Google-like metadata fills avatar_url and display_name from full_name'
);

select is(
  (select avatar_url from public.profiles where id = '00000000-0000-0000-0000-0000000001a2'),
  'https://p.test/pic.jpg',
  'TC11: only picture -> avatar_url = picture'
);
select is(
  (select avatar_url from public.profiles where id = '00000000-0000-0000-0000-0000000001a3'),
  'https://a.test/1.png',
  'TC11: avatar_url wins over picture'
);
select is(
  (select avatar_url from public.profiles where id = '00000000-0000-0000-0000-0000000001a4'),
  'https://a.test/x.png',
  'TC11: padded avatar_url is trimmed'
);

select results_eq(
  $$select avatar_url is null, display_name is not null from public.profiles
     where id in ('00000000-0000-0000-0000-0000000001a5', '00000000-0000-0000-0000-0000000001a6',
                  '00000000-0000-0000-0000-0000000001a7', '00000000-0000-0000-0000-0000000001a8',
                  '00000000-0000-0000-0000-0000000001a9')
     order by id$$,
  $$values (true, true), (true, true), (true, true), (true, true), (true, true)$$,
  'TC12: invalid avatar values -> profile created with null avatar_url and a display_name'
);

select is(
  (select avatar_url is null from public.profiles where id = '00000000-0000-0000-0000-0000000001aa'),
  true,
  'TC13: invalid avatar_url + valid picture -> profile exists, avatar_url null (first candidate decides)'
);

-- TC3: is_admin()
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select is(public.is_admin(), true, 'TC3: is_admin() is true for admin');
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select is(public.is_admin(), false, 'TC3: is_admin() is false for a regular user');
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}';
select is(public.is_admin(), false, 'TC3: is_admin() is false for an authenticated user without a profile');
reset role;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select is(public.is_admin(), false, 'TC3: is_admin() is false for anon');
reset role;

-- TC4: select only own profile
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select results_eq(
  $$select id from public.profiles$$,
  $$values ('00000000-0000-0000-0000-00000000000a'::uuid)$$,
  'TC4: user A sees only own profile'
);
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select results_eq(
  $$select id from public.profiles$$,
  $$values ('00000000-0000-0000-0000-00000000000c'::uuid)$$,
  'TC4: admin sees only own profile (no admin bypass yet)'
);
reset role;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select throws_ok(
  $$select count(*) from public.profiles$$,
  '42501', null,
  'TC4: anon cannot select profiles (no privilege)'
);
reset role;

-- TC5: privilege errors (column/table grants), not RLS
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select throws_ok(
  $$update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-00000000000a'$$,
  '42501', null,
  'TC5: user cannot change own role (no column privilege)'
);
select throws_ok(
  $$insert into public.profiles (id) values ('00000000-0000-0000-0000-00000000000d')$$,
  '42501', null,
  'TC5: user cannot insert a profile (no insert privilege)'
);
select throws_ok(
  $$delete from public.profiles where id = '00000000-0000-0000-0000-00000000000a'$$,
  '42501', null,
  'TC5: user cannot delete own profile (no delete privilege)'
);

-- TC6: update of another user's profile affects no rows
select lives_ok(
  $$update public.profiles set display_name = 'X' where id = '00000000-0000-0000-0000-00000000000b'$$,
  'TC6: update of another profile does not raise'
);
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select lives_ok(
  $$update public.profiles set display_name = 'Y' where id = '00000000-0000-0000-0000-00000000000b'$$,
  'TC6: admin update of another profile does not raise (no admin bypass yet)'
);
reset role;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select throws_ok(
  $$update public.profiles set display_name = 'Z' where id = '00000000-0000-0000-0000-00000000000b'$$,
  '42501', null,
  'TC6: anon cannot update profiles (no update privilege)'
);
reset role;
select is(
  (select display_name from public.profiles where id = '00000000-0000-0000-0000-00000000000b'),
  'bob',
  'TC6: other user''s profile is unchanged'
);

-- TC7: own update of allowed columns succeeds and bumps updated_at (no column grant on updated_at needed)
-- Backdate with the trigger off, otherwise set_updated_at() would overwrite the value with now().
alter table public.profiles disable trigger profiles_set_updated_at;
update public.profiles set updated_at = '2000-01-01' where id = '00000000-0000-0000-0000-00000000000a';
alter table public.profiles enable trigger profiles_set_updated_at;
select is(
  (select updated_at from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  '2000-01-01'::timestamptz,
  'TC7: fixture backdated updated_at'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select lives_ok(
  $$update public.profiles set display_name = 'Alice2', notifications_enabled = false
     where id = '00000000-0000-0000-0000-00000000000a'$$,
  'TC7: user updates own display_name and notifications_enabled'
);
select ok(
  (select display_name = 'Alice2' and notifications_enabled = false and updated_at > '2000-01-01'::timestamptz
     from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  'TC7: values changed and updated_at refreshed by trigger'
);
reset role;

-- TC8: check constraints
select throws_ok(
  $$update public.profiles set role = 'owner' where id = '00000000-0000-0000-0000-00000000000a'$$,
  '23514', null,
  'TC8: unknown role is rejected'
);
select throws_ok(
  $$update public.profiles set display_name = '   ' where id = '00000000-0000-0000-0000-00000000000a'$$,
  '23514', null,
  'TC8: blank display_name is rejected'
);
select throws_ok(
  $$update public.profiles set display_name = '  Bob  ' where id = '00000000-0000-0000-0000-00000000000a'$$,
  '23514', null,
  'TC8: display_name with surrounding spaces is rejected'
);
select throws_ok(
  $$update public.profiles set avatar_url = 'ftp://x' where id = '00000000-0000-0000-0000-00000000000a'$$,
  '23514', null,
  'TC8: non-http(s) avatar_url is rejected'
);

-- TC9: deleting the auth user cascades to the profile
delete from auth.users where id = '00000000-0000-0000-0000-00000000000b';
select is(
  (select count(*)::int from public.profiles where id = '00000000-0000-0000-0000-00000000000b'),
  0,
  'TC9: profile is deleted with its auth user'
);

select * from finish();
rollback;
