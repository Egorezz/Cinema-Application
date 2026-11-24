-- Local dev seed, applied by `npx supabase db reset` after all migrations.
-- Only open-licence media with CORS. Fixtures: 2 test users, 3 published movies + 1 draft, 2 series.
-- Local only: never push this seed to the cloud project (it contains test users with known passwords).

-- Test users (local dev only). Empty strings, not NULL, in the *_token / email_change columns:
-- GoTrue fails to scan NULLs there and login returns 500.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-5eed00000001',
   'authenticated', 'authenticated', 'admin@cinema.local',
   extensions.crypt('admin12345', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"Admin"}', now(), now(),
   '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-5eed00000002',
   'authenticated', 'authenticated', 'user@cinema.local',
   extensions.crypt('user12345', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"Test user"}', now(), now(),
   '', '', '', '');

insert into auth.identities (
  provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
) values
  ('00000000-0000-0000-0000-5eed00000001', '00000000-0000-0000-0000-5eed00000001',
   '{"sub":"00000000-0000-0000-0000-5eed00000001","email":"admin@cinema.local","email_verified":true}',
   'email', now(), now(), now()),
  ('00000000-0000-0000-0000-5eed00000002', '00000000-0000-0000-0000-5eed00000002',
   '{"sub":"00000000-0000-0000-0000-5eed00000002","email":"user@cinema.local","email_verified":true}',
   'email', now(), now(), now());

-- Profiles are created by the on_auth_user_created trigger.
update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-5eed00000001';

-- Open demo streams (2xx + CORS "*" verified), referenced by code below.
create temporary table seed_sources (code text primary key, url text, format text, quality text);
insert into seed_sources values
  ('MUX_BBB', 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8', 'hls', 'auto'),
  ('MUX_TOS', 'https://test-streams.mux.dev/tos_ismc/main.m3u8', 'hls', 'auto'),
  ('US_TOS', 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8', 'hls', 'auto'),
  ('SINTEL', 'https://storage.googleapis.com/shaka-demo-assets/sintel-fmp4-aes/master.m3u8', 'hls', 'auto'),
  ('MUX_PTS', 'https://test-streams.mux.dev/pts_shift/master.m3u8', 'hls', 'auto'),
  ('FLOWER', 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4', 'mp4', '720p');

-- Movies
insert into public.titles (tmdb_id, type, title, original_title, overview, year, genres, rating, status, is_published) values
  (10378, 'movie', 'Большой кролик', 'Big Buck Bunny',
   'Огромный добродушный кролик отвечает на выходки трёх грызунов-хулиганов.', 2008, '{Анимация,Комедия}', 6.8, 'released', true),
  (45745, 'movie', 'Синтел', 'Sintel',
   'Девушка отправляется на поиски своего дракона через опасные земли.', 2010, '{Анимация,Фэнтези}', 7.4, 'released', true),
  (133701, 'movie', 'Слёзы стали', 'Tears of Steel',
   'Группа учёных и бойцов пытается спасти мир от роботов в Амстердаме будущего.', 2012, '{Фантастика,Короткометражка}', 6.5, 'released', true);
insert into public.titles (type, title, overview, year, genres, status, is_published) values
  ('movie', 'Черновик: тестовый поток', 'Неопубликованный черновик для проверки скрытия.', 2024, '{Тест}', 'released', false);

insert into public.video_sources (title_id, url, format, quality, language, priority, is_active)
select t.id, s.url, s.format, s.quality, 'en', m.priority, true
from (values
  ('movie', 10378, null, 'MUX_BBB', 0),
  ('movie', 45745, null, 'SINTEL', 0),
  ('movie', 133701, null, 'US_TOS', 0),
  ('movie', 133701, null, 'MUX_TOS', 1),
  ('movie', null, 'Черновик: тестовый поток', 'MUX_PTS', 0)
) as m(type, tmdb_id, ttl, code, priority)
join public.titles t on t.type = m.type
  and (t.tmdb_id = m.tmdb_id or (m.tmdb_id is null and t.title = m.ttl))
join seed_sources s on s.code = m.code;

-- Series
insert into public.titles (type, title, overview, year, genres, status, is_published) values
  ('series', 'Тестовые потоки', 'Подборка технических демонстрационных потоков.', 2024, '{Тест}', 'returning', true),
  ('series', 'Открытые фильмы Blender', 'Короткометражки с открытой лицензией от Blender Foundation.', 2008, '{Анимация}', 'ended', true);

insert into public.seasons (title_id, season_number, name)
select t.id, n, 'Сезон ' || n
from public.titles t, generate_series(1, 2) as n
where t.type = 'series' and t.title in ('Тестовые потоки', 'Открытые фильмы Blender');

insert into public.episodes (season_id, episode_number, name, overview, runtime, air_date)
select se.id, e.n,
       'Серия ' || e.n,
       'Тестовая серия ' || e.n || ' сезона ' || se.season_number || '.',
       10 + e.n,
       date '2024-01-01' + ((se.season_number - 1) * 3 + e.n) * 7
from public.seasons se
join public.titles t on t.id = se.title_id
cross join generate_series(1, 3) as e(n)
where t.type = 'series' and t.title in ('Тестовые потоки', 'Открытые фильмы Blender');

insert into public.video_sources (episode_id, url, format, quality, language, priority, is_active)
select ep.id, s.url, s.format, s.quality, 'en', 0, true
from (values
  ('Тестовые потоки', 1, 1, 'MUX_PTS'),
  ('Тестовые потоки', 1, 2, 'MUX_BBB'),
  ('Тестовые потоки', 1, 3, 'FLOWER'),
  ('Тестовые потоки', 2, 1, 'MUX_TOS'),
  ('Тестовые потоки', 2, 2, 'US_TOS'),
  ('Тестовые потоки', 2, 3, 'SINTEL'),
  ('Открытые фильмы Blender', 1, 1, 'MUX_BBB'),
  ('Открытые фильмы Blender', 1, 2, 'SINTEL'),
  ('Открытые фильмы Blender', 1, 3, 'US_TOS'),
  ('Открытые фильмы Blender', 2, 1, 'MUX_TOS'),
  ('Открытые фильмы Blender', 2, 2, 'MUX_BBB'),
  ('Открытые фильмы Blender', 2, 3, 'SINTEL')
) as m(ttl, sn, en, code)
join public.titles t on t.type = 'series' and t.title = m.ttl
join public.seasons se on se.title_id = t.id and se.season_number = m.sn
join public.episodes ep on ep.season_id = se.id and ep.episode_number = m.en
join seed_sources s on s.code = m.code;

drop table seed_sources;
