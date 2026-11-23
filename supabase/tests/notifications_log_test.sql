begin;
select plan(26);

-- TC1: table shape
select columns_are(
  'public', 'notifications_log',
  array['id', 'user_id', 'episode_id', 'sent_at', 'status', 'error'],
  'TC1: notifications_log has exactly the 6 expected columns'
);
select col_is_pk('public', 'notifications_log', 'id', 'TC1: id is the primary key');
select has_index(
  'public', 'notifications_log', 'notifications_log_episode_id_idx', 'episode_id',
  'TC1: episode_id has its own index'
);

-- Fixtures
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a8', 'authenticated', 'authenticated', 'log-a@test.local'),
  ('00000000-0000-0000-0000-0000000000b8', 'authenticated', 'authenticated', 'log-b@test.local');
insert into public.titles (type, title, tmdb_id, is_published) values ('series', 'LOG series', 900000801, true);
insert into public.seasons (title_id, season_number, name)
  select id, 1, 'LOG s1' from public.titles where tmdb_id = 900000801;
insert into public.episodes (season_id, episode_number, name)
  select id, n, 'LOG e' || n from public.seasons, generate_series(1, 2) n where name = 'LOG s1';

-- TC2: status / error consistency
select throws_ok(
  $$insert into public.notifications_log (user_id, episode_id, status)
    select '00000000-0000-0000-0000-0000000000a8', id, 'queued' from public.episodes where name = 'LOG e1'$$,
  '23514', null, 'TC2: unknown status is rejected'
);
select throws_ok(
  $$insert into public.notifications_log (user_id, episode_id, status, error)
    select '00000000-0000-0000-0000-0000000000a8', id, 'failed', null from public.episodes where name = 'LOG e1'$$,
  '23514', null, 'TC2: failed without error is rejected'
);
select throws_ok(
  $$insert into public.notifications_log (user_id, episode_id, status, error)
    select '00000000-0000-0000-0000-0000000000a8', id, 'failed', E' \n\t' from public.episodes where name = 'LOG e1'$$,
  '23514', null, 'TC2: failed with whitespace-only error is rejected'
);
select throws_ok(
  $$insert into public.notifications_log (user_id, episode_id, status, error)
    select '00000000-0000-0000-0000-0000000000a8', id, 'sent', 'x' from public.episodes where name = 'LOG e1'$$,
  '23514', null, 'TC2: sent with error is rejected'
);

-- TC3: unique (user, episode)
insert into public.notifications_log (user_id, episode_id, status, sent_at)
  select '00000000-0000-0000-0000-0000000000a8', id, 'sent', now() - interval '1 day'
  from public.episodes where name = 'LOG e1';
insert into public.notifications_log (user_id, episode_id, status)
  select '00000000-0000-0000-0000-0000000000a8', id, 'sent' from public.episodes where name = 'LOG e2';
insert into public.notifications_log (user_id, episode_id, status)
  select '00000000-0000-0000-0000-0000000000b8', id, 'sent' from public.episodes where name = 'LOG e1';
select throws_ok(
  $$insert into public.notifications_log (user_id, episode_id, status)
    select '00000000-0000-0000-0000-0000000000a8', id, 'sent' from public.episodes where name = 'LOG e1'$$,
  '23505', null, 'TC3: second row for the same (user, episode) is rejected'
);
select is(
  (select count(*)::int from public.notifications_log
    where user_id in ('00000000-0000-0000-0000-0000000000a8', '00000000-0000-0000-0000-0000000000b8')),
  3,
  'TC3: service role reads the three fixture rows'
);

-- TC4: claim statement does nothing for an already-logged pair
with r as (
  insert into public.notifications_log (user_id, episode_id, status, error)
    select '00000000-0000-0000-0000-0000000000a8', id, 'sent', null from public.episodes where name = 'LOG e1'
  on conflict (user_id, episode_id) do nothing
  returning id
)
select is((select count(*)::int from r), 0, 'TC4: claim of an already-logged pair returns no row');
select ok(
  (select l.sent_at < now() - interval '23 hours' from public.notifications_log l
    join public.episodes e on e.id = l.episode_id
    where l.user_id = '00000000-0000-0000-0000-0000000000a8' and e.name = 'LOG e1'),
  'TC4: existing row is untouched'
);

-- TC5: retry never touches a sent row
with r as (
  insert into public.notifications_log (user_id, episode_id, status, error)
    select '00000000-0000-0000-0000-0000000000a8', id, 'failed', 'HTTP 500' from public.episodes where name = 'LOG e1'
  on conflict (user_id, episode_id) do update
    set status = excluded.status, error = excluded.error, sent_at = now()
    where public.notifications_log.status = 'failed'
  returning id
)
select is((select count(*)::int from r), 0, 'TC5: retry over a sent row returns no row');
select ok(
  (select l.status = 'sent' and l.error is null and l.sent_at < now() - interval '23 hours'
    from public.notifications_log l join public.episodes e on e.id = l.episode_id
    where l.user_id = '00000000-0000-0000-0000-0000000000a8' and e.name = 'LOG e1'),
  'TC5: sent row stays sent, error null, sent_at unchanged'
);

-- TC6: retry turns a failed row into sent
insert into public.notifications_log (user_id, episode_id, status, error, sent_at)
  select '00000000-0000-0000-0000-0000000000b8', id, 'failed', 'HTTP 500', now() - interval '1 day'
  from public.episodes where name = 'LOG e2';
with r as (
  insert into public.notifications_log (user_id, episode_id, status, error)
    select '00000000-0000-0000-0000-0000000000b8', id, 'sent', null from public.episodes where name = 'LOG e2'
  on conflict (user_id, episode_id) do update
    set status = excluded.status, error = excluded.error, sent_at = now()
    where public.notifications_log.status = 'failed'
  returning id
)
select is((select count(*)::int from r), 1, 'TC6: retry over a failed row returns one row');
select ok(
  (select l.status = 'sent' and l.error is null and l.sent_at > now() - interval '1 hour'
    from public.notifications_log l join public.episodes e on e.id = l.episode_id
    where l.user_id = '00000000-0000-0000-0000-0000000000b8' and e.name = 'LOG e2'),
  'TC6: row is sent, error cleared, sent_at bumped'
);
select is(
  (select count(*)::int from public.notifications_log l join public.episodes e on e.id = l.episode_id
    where l.user_id = '00000000-0000-0000-0000-0000000000b8' and e.name = 'LOG e2'),
  1,
  'TC6: still one row for (B, E2)'
);

-- TC7: clients have no access at all
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a8","role":"authenticated"}';
select throws_ok($$select * from public.notifications_log$$, '42501', null, 'TC7: authenticated cannot select');
select throws_ok(
  $$insert into public.notifications_log (user_id, episode_id, status) values ('00000000-0000-0000-0000-0000000000a8', 1, 'sent')$$,
  '42501', null, 'TC7: authenticated cannot insert'
);
select throws_ok($$update public.notifications_log set status = 'sent'$$, '42501', null, 'TC7: authenticated cannot update');
select throws_ok($$delete from public.notifications_log$$, '42501', null, 'TC7: authenticated cannot delete');

reset role;
set local role anon;
select throws_ok($$select * from public.notifications_log$$, '42501', null, 'TC7: anon cannot select');
select throws_ok(
  $$insert into public.notifications_log (user_id, episode_id, status) values ('00000000-0000-0000-0000-0000000000a8', 1, 'sent')$$,
  '42501', null, 'TC7: anon cannot insert'
);
select throws_ok($$update public.notifications_log set status = 'sent'$$, '42501', null, 'TC7: anon cannot update');
select throws_ok($$delete from public.notifications_log$$, '42501', null, 'TC7: anon cannot delete');
reset role;

-- TC8: cascades
delete from public.episodes where name = 'LOG e1';
select is(
  (select count(*)::int from public.notifications_log l
    where l.user_id in ('00000000-0000-0000-0000-0000000000a8', '00000000-0000-0000-0000-0000000000b8')
      and l.episode_id not in (select id from public.episodes)),
  0,
  'TC8: deleting an episode removes its log rows'
);
delete from auth.users where id = '00000000-0000-0000-0000-0000000000b8';
select is(
  (select count(*)::int from public.notifications_log where user_id = '00000000-0000-0000-0000-0000000000b8'),
  0,
  'TC8: deleting a user removes their log rows'
);

select * from finish();
rollback;
