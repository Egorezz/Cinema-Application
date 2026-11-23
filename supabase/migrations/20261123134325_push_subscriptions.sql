-- 1.7: push_subscriptions table (one row per browser Web Push subscription)

create table public.push_subscriptions (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references auth.users (id) on delete cascade,
  endpoint      text not null unique,
  p256dh        text not null,
  auth          text not null,
  user_agent    text,
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now(),
  -- The sender (7.3, 8.8) POSTs to every stored endpoint: only known Web Push services are accepted (no SSRF).
  -- A new push service needs a new migration that widens this list.
  constraint push_subscriptions_endpoint_push_service check (
    endpoint ~ '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|[a-z0-9-]+\.notify\.windows\.com|[a-z0-9-]+\.push\.apple\.com)/'
  ),
  -- Bounded sizes: real values are far below; also keeps endpoint under the btree unique-index row limit.
  constraint push_subscriptions_lengths check (
    char_length(endpoint) <= 2048
    and char_length(p256dh) between 1 and 128
    and char_length(auth) between 1 and 64
    and (user_agent is null or char_length(user_agent) <= 512)
  )
);

-- FK index: per-user lookups when sending (7.3) and the auth.users cascade.
create index push_subscriptions_user_id_idx on public.push_subscriptions (user_id);

comment on table public.push_subscriptions is
  'Web Push subscriptions, one row per browser. Register / refresh via register_push_subscription(); delete own row on logout.';

-- Registers (or refreshes) the caller's browser subscription; returns the row id.
-- The endpoint identifies a browser, not a user: if another user's row holds this endpoint (they did not log out
-- cleanly), it is handed over to the caller so the previous user's pushes stop reaching this browser.
-- security definer: the conflicting row may belong to another user and is invisible / not updatable under caller RLS.
create or replace function public.register_push_subscription(
  p_endpoint   text,
  p_p256dh     text,
  p_auth       text,
  p_user_agent text default null
)
returns bigint
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id  bigint;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = 'insufficient_privilege';
  end if;

  insert into public.push_subscriptions (user_id, endpoint, p256dh, auth, user_agent)
  values (v_uid, p_endpoint, p_p256dh, p_auth, p_user_agent)
  on conflict (endpoint) do update
    set user_id      = excluded.user_id,
        p256dh       = excluded.p256dh,
        auth         = excluded.auth,
        user_agent   = excluded.user_agent,
        last_seen_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function public.register_push_subscription(text, text, text, text) from public, anon;
grant execute on function public.register_push_subscription(text, text, text, text) to authenticated;

alter table public.push_subscriptions enable row level security;

create policy "push_subscriptions_select_own" on public.push_subscriptions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "push_subscriptions_delete_own" on public.push_subscriptions
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Clients read and delete (logout) own rows; all writes go through register_push_subscription().
-- Service role (7.3, 8.8) bypasses RLS and keeps its default grants.
revoke insert, update, truncate, references, trigger on public.push_subscriptions from anon, authenticated;
revoke select, delete on public.push_subscriptions from anon;
