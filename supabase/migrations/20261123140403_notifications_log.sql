-- 1.8: notifications_log table

create table public.notifications_log (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  episode_id  bigint not null references public.episodes (id) on delete cascade,
  sent_at     timestamptz not null default now(),   -- time of the last delivery attempt
  status      text not null check (status in ('sent', 'failed')),
  error       text,
  constraint notifications_log_user_episode_key unique (user_id, episode_id),
  -- sent => no error; failed => error with at least one non-whitespace char (null fails the regex check via coalesce)
  constraint notifications_log_error_matches_status check (
    (status = 'sent' and error is null) or (status = 'failed' and coalesce(error ~ '\S', false))
  )
);

-- user_id is leading in the unique index; episode_id needs its own index for cascades from episodes.
create index notifications_log_episode_id_idx on public.notifications_log (episode_id);

comment on table public.notifications_log is
  'Push delivery log, one row per (user, episode); written only by the service role (7.3/7.4), '
  'and only AFTER a delivery attempt (never as a pre-send claim). '
  'sent = delivered to at least one of the user''s push subscriptions; failed = delivered to none. '
  'Before sending, skip pairs that already have status = ''sent''. '
  'Write: insert ... on conflict (user_id, episode_id) do update set status, error, sent_at = now() '
  'where notifications_log.status = ''failed'' returning id (no row => already sent).';

-- Service role only: RLS on, no policies. Service role bypasses RLS and keeps its default grants.
alter table public.notifications_log enable row level security;
revoke all on public.notifications_log from anon, authenticated;
