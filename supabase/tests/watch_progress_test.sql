begin;
select plan(40);

-- TC1: table shape
select columns_are(
  'public', 'watch_progress',
  array[
    'id', 'user_id', 'episode_id', 'title_id', 'position_sec', 'duration_sec',
    'is_finished', 'created_at', 'updated_at'
  ],
  'TC1: watch_progress has exactly the 9 expected columns'
);

-- Fixtures
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'authenticated', 'authenticated', 'wp-a@test.local'),
  ('00000000-0000-0000-0000-0000000000b1', 'authenticated', 'authenticated', 'wp-b@test.local');
insert into public.titles (type, title, tmdb_id, is_published) values
  ('movie', 'WP movie 1', 900000501, true),
  ('movie', 'WP movie 2', 900000502, true),
  ('series', 'WP series 1', 900000503, true),
  ('movie', 'WP draft movie', 900000504, false),
  ('series', 'WP draft series', 900000505, false);
insert into public.seasons (title_id, season_number, name)
  select id, 1, 'WP s1' from public.titles where tmdb_id = 900000503;
insert into public.seasons (title_id, season_number, name)
  select id, 1, 'WP s2' from public.titles where tmdb_id = 900000505;
insert into public.episodes (season_id, episode_number, name)
  select id, 1, 'WP e1' from public.seasons where name = 'WP s1';
insert into public.episodes (season_id, episode_number, name)
  select id, 1, 'WP e2' from public.seasons where name = 'WP s2';

-- Drafts are invisible to authenticated (RLS), so their ids are resolved up front.
create temp table wp_draft_ids as
  select (select id from public.titles where tmdb_id = 900000504) as draft_movie_id,
         (select id from public.episodes where name = 'WP e2') as draft_episode_id;
grant select on wp_draft_ids to authenticated;

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';

-- TC2: exactly one target
select throws_ok(
  $$insert into public.watch_progress (duration_sec) values (100)$$,
  '23514', null,
  'TC2: progress without episode_id and title_id is rejected'
);
select throws_ok(
  $$insert into public.watch_progress (episode_id, title_id, duration_sec)
    select e.id, t.id, 100
    from public.episodes e, public.titles t
    where e.name = 'WP e1' and t.tmdb_id = 900000501$$,
  '23514', null,
  'TC2: progress with both episode_id and title_id is rejected'
);

-- TC3: only published movies / episodes of published titles; one and the same error
select throws_ok(
  $$insert into public.watch_progress (title_id, duration_sec)
    select id, 100 from public.titles where tmdb_id = 900000503$$,
  '23503', null,
  'TC3: progress for a published series title is rejected'
);
select throws_ok(
  $$insert into public.watch_progress (title_id, duration_sec)
    select draft_movie_id, 100 from wp_draft_ids$$,
  '23503', null,
  'TC3: progress for a draft movie is rejected'
);
select throws_ok(
  $$insert into public.watch_progress (episode_id, duration_sec)
    select draft_episode_id, 100 from wp_draft_ids$$,
  '23503', null,
  'TC3: progress for an episode of a draft series is rejected'
);
select throws_ok(
  $$insert into public.watch_progress (title_id, duration_sec) values (999999999, 100)$$,
  '23503', null,
  'TC3: progress for a non-existent title is rejected'
);

-- TC4: value checks
select throws_ok(
  $$insert into public.watch_progress (title_id, position_sec, duration_sec)
    select id, -1, 100 from public.titles where tmdb_id = 900000501$$,
  '23514', null,
  'TC4: negative position_sec is rejected'
);
select throws_ok(
  $$insert into public.watch_progress (title_id, position_sec, duration_sec)
    select id, 0, 0 from public.titles where tmdb_id = 900000501$$,
  '23514', null,
  'TC4: zero duration_sec is rejected'
);

-- TC10: position beyond duration is clamped
insert into public.watch_progress (title_id, position_sec, duration_sec)
  select id, 1001, 1000 from public.titles where tmdb_id = 900000501
  on conflict (user_id, title_id) do update
    set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished;
select is(
  (select position_sec from public.watch_progress
    where title_id = (select id from public.titles where tmdb_id = 900000501)),
  1000,
  'TC10: position_sec greater than duration_sec is clamped to duration_sec'
);

-- TC11: title type cannot change while only watch_progress references it
reset role;
select throws_ok(
  $$update public.titles set type = 'series' where tmdb_id = 900000501$$,
  '23514', null,
  'TC11: movie type change is rejected while it has watch progress'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';

-- TC5: episode upsert in one query, repeated upsert updates the same row
insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
  select id, 10, 1000, false from public.episodes where name = 'WP e1'
  on conflict (user_id, episode_id) do update
    set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished;
reset role;
alter table public.watch_progress disable trigger watch_progress_set_updated_at;
update public.watch_progress set updated_at = now() - interval '1 day';
alter table public.watch_progress enable trigger watch_progress_set_updated_at;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
  select id, 120, 1000, false from public.episodes where name = 'WP e1'
  on conflict (user_id, episode_id) do update
    set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished;
select is(
  (select count(*)::int || '/' || max(position_sec) from public.watch_progress
    where episode_id = (select id from public.episodes where name = 'WP e1')),
  '1/120',
  'TC5: repeated episode upsert keeps one row with the latest position'
);
select ok(
  (select updated_at > now() - interval '1 hour' from public.watch_progress
    where episode_id = (select id from public.episodes where name = 'WP e1')),
  'TC5: repeated upsert bumps updated_at'
);

-- TC6: movie upsert
insert into public.watch_progress (title_id, position_sec, duration_sec)
  select id, 5, 500 from public.titles where tmdb_id = 900000501
  on conflict (user_id, title_id) do update
    set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished;
insert into public.watch_progress (title_id, position_sec, duration_sec)
  select id, 50, 500 from public.titles where tmdb_id = 900000501
  on conflict (user_id, title_id) do update
    set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished;
select is(
  (select count(*)::int || '/' || max(position_sec) from public.watch_progress
    where title_id = (select id from public.titles where tmdb_id = 900000501)),
  '1/50',
  'TC6: repeated movie upsert keeps one row with the latest position'
);

-- TC7: owner only
select is(
  (select count(*)::int from public.watch_progress),
  2,
  'TC7: user A sees own 2 rows'
);
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}';
select is(
  (select count(*)::int from public.watch_progress),
  0,
  'TC7: user B sees none of A rows'
);
update public.watch_progress set position_sec = 99;
delete from public.watch_progress;
select throws_ok(
  $$insert into public.watch_progress (user_id, title_id, duration_sec)
    select '00000000-0000-0000-0000-0000000000a1', id, 100 from public.titles where tmdb_id = 900000502$$,
  '42501', null,
  'TC7: user B cannot insert a row for user A'
);
reset role;
select is(
  (select count(*)::int from public.watch_progress where position_sec <> 99),
  2,
  'TC7: user B update/delete left A rows untouched'
);

-- TC8: own delete, anon has no access
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
delete from public.watch_progress where title_id is not null;
select is(
  (select count(*)::int from public.watch_progress),
  1,
  'TC8: user A can delete own row'
);
reset role;
set local role anon;
select throws_ok(
  $$select count(*) from public.watch_progress$$,
  '42501', null,
  'TC8: anon select is rejected'
);
select throws_ok(
  $$insert into public.watch_progress (user_id, title_id, duration_sec)
    select '00000000-0000-0000-0000-0000000000a1', id, 100 from public.titles where tmdb_id = 900000501$$,
  '42501', null,
  'TC8: anon insert is rejected'
);
reset role;

-- is_finished transitions: own fixtures, removed again before TC9
insert into public.titles (type, title, tmdb_id, is_published) values
  ('series', 'WP fin series', 900000510, true),
  ('movie', 'WP fin movie', 900000511, true);
insert into public.seasons (title_id, season_number, name)
  select id, 1, 'WP fin s1' from public.titles where tmdb_id = 900000510;
insert into public.episodes (season_id, episode_number, name)
  select s.id, n, 'WP f' || n from public.seasons s, generate_series(1, 6) n where s.name = 'WP fin s1';

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';

-- TC12: false -> true only at >= 90 % (regression)
select throws_ok(
  $$insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
    select id, 899, 1000, true from public.episodes where name = 'WP f1'$$,
  '23514', null,
  'TC12: new row finished below 90 % is rejected'
);
select lives_ok(
  $$insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
    select id, 900, 1000, true from public.episodes where name = 'WP f1'$$,
  'TC12: new row finished at exactly 90 % is accepted'
);
select throws_ok(
  $$insert into public.watch_progress (title_id, position_sec, duration_sec, is_finished)
    select id, 6, 7, true from public.titles where tmdb_id = 900000511
    on conflict (user_id, title_id) do update
      set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished$$,
  '23514', null,
  'TC12: movie upsert finished at 6 of 7 s is rejected'
);
select lives_ok(
  $$insert into public.watch_progress (title_id, position_sec, duration_sec, is_finished)
    select id, 7, 7, true from public.titles where tmdb_id = 900000511
    on conflict (user_id, title_id) do update
      set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished$$,
  'TC12: movie upsert finished at 7 of 7 s is accepted'
);

-- TC13: update false -> true
insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
  select id, 100, 1000, false from public.episodes where name = 'WP f2';
select throws_ok(
  $$update public.watch_progress set position_sec = 500, is_finished = true
    where episode_id = (select id from public.episodes where name = 'WP f2')$$,
  '23514', null,
  'TC13: update to finished at 50 % is rejected'
);
update public.watch_progress set position_sec = 950, is_finished = true
  where episode_id = (select id from public.episodes where name = 'WP f2');
select is(
  (select is_finished from public.watch_progress
    where episode_id = (select id from public.episodes where name = 'WP f2')),
  true,
  'TC13: update to finished at 95 % is accepted'
);

-- TC14: finished row stays finished at any position
insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
  select id, 950, 1000, true from public.episodes where name = 'WP f3';
update public.watch_progress set position_sec = 10
  where episode_id = (select id from public.episodes where name = 'WP f3');
select is(
  (select is_finished || '/' || position_sec from public.watch_progress
    where episode_id = (select id from public.episodes where name = 'WP f3')),
  'true/10',
  'TC14: rewinding a finished row keeps it finished'
);
select lives_ok(
  $$update public.watch_progress set position_sec = 20, is_finished = true
    where episode_id = (select id from public.episodes where name = 'WP f3')$$,
  'TC14: re-sending finished at a low position for a finished row is accepted'
);

-- TC15: upsert re-send of true at a low position
insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
  select id, 950, 1000, true from public.episodes where name = 'WP f4';
select lives_ok(
  $$insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
    select id, 5, 1000, true from public.episodes where name = 'WP f4'
    on conflict (user_id, episode_id) do update
      set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished$$,
  'TC15: upsert re-sending finished for a finished row is accepted'
);
select is(
  (select is_finished || '/' || position_sec from public.watch_progress
    where episode_id = (select id from public.episodes where name = 'WP f4')),
  'true/5',
  'TC15: upsert re-send keeps the row finished at the new position'
);
insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
  select id, 100, 1000, false from public.episodes where name = 'WP f5';
select throws_ok(
  $$insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
    select id, 5, 1000, true from public.episodes where name = 'WP f5'
    on conflict (user_id, episode_id) do update
      set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished$$,
  '23514', null,
  'TC15: upsert finished at a low position for an unfinished row is rejected'
);
select throws_ok(
  $$insert into public.watch_progress (episode_id, position_sec, duration_sec, is_finished)
    select id, 5, 1000, true from public.episodes where name = 'WP f6'
    on conflict (user_id, episode_id) do update
      set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec, is_finished = excluded.is_finished$$,
  '23514', null,
  'TC15: upsert finished at a low position without a stored row is rejected'
);

-- TC16: autosave without is_finished keeps the stored value
insert into public.watch_progress (episode_id, position_sec, duration_sec)
  select id, 30, 1000 from public.episodes where name = 'WP f4'
  on conflict (user_id, episode_id) do update
    set position_sec = excluded.position_sec, duration_sec = excluded.duration_sec;
select is(
  (select is_finished || '/' || position_sec from public.watch_progress
    where episode_id = (select id from public.episodes where name = 'WP f4')),
  'true/30',
  'TC16: upsert without is_finished keeps the row finished'
);

-- TC17: true -> false is always allowed
update public.watch_progress set is_finished = false
  where episode_id = (select id from public.episodes where name = 'WP f3');
select is(
  (select is_finished from public.watch_progress
    where episode_id = (select id from public.episodes where name = 'WP f3')),
  false,
  'TC17: unmarking a finished row at a low position is accepted'
);
update public.watch_progress set is_finished = false
  where title_id = (select id from public.titles where tmdb_id = 900000511);
select is(
  (select is_finished from public.watch_progress
    where title_id = (select id from public.titles where tmdb_id = 900000511)),
  false,
  'TC17: unmarking a finished row at 100 % is accepted'
);

-- TC18: moving a finished row to another episode is judged like a new row
select throws_ok(
  $$update public.watch_progress
    set episode_id = (select id from public.episodes where name = 'WP f6'), position_sec = 5
    where episode_id = (select id from public.episodes where name = 'WP f2')$$,
  '23514', null,
  'TC18: moving a finished row to another episode below 90 % is rejected'
);

reset role;
delete from public.titles where tmdb_id in (900000510, 900000511);

-- TC9: cascades
insert into public.watch_progress (user_id, episode_id, duration_sec)
  select '00000000-0000-0000-0000-0000000000b1', id, 100 from public.episodes where name = 'WP e1';
insert into public.watch_progress (user_id, title_id, duration_sec)
  select '00000000-0000-0000-0000-0000000000a1', id, 100 from public.titles where tmdb_id = 900000502;
delete from public.episodes where name = 'WP e1';
select is(
  (select count(*)::int from public.watch_progress where episode_id is not null),
  0,
  'TC9: deleting an episode removes its progress'
);
delete from public.titles where tmdb_id = 900000502;
select is(
  (select count(*)::int from public.watch_progress where title_id is not null),
  0,
  'TC9: deleting a movie removes its progress'
);
insert into public.watch_progress (user_id, title_id, duration_sec)
  select '00000000-0000-0000-0000-0000000000a1', id, 100 from public.titles where tmdb_id = 900000501;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select count(*)::int from public.watch_progress where user_id = '00000000-0000-0000-0000-0000000000a1'),
  0,
  'TC9: deleting a user removes their progress'
);

select * from finish();
rollback;
