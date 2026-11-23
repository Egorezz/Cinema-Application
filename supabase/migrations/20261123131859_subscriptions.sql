-- 1.6: subscriptions table

create table public.subscriptions (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title_id    bigint not null references public.titles (id) on delete cascade,   -- published series only (trigger below)
  is_muted    boolean not null default false,
  created_at  timestamptz not null default now(),
  primary key (user_id, title_id)
);

-- user_id is leading in the PK; title_id needs its own index for cascades and per-series lookups (2.3, 7.2).
create index subscriptions_title_id_idx on public.subscriptions (title_id);

comment on table public.subscriptions is
  'Series subscriptions for the daily new-episode push digest. Subscribe = insert ... on conflict (user_id, title_id) do nothing.';

-- A subscription may target only a published series.
-- Missing / draft / movie targets raise one and the same error, so a draft's existence or type is not revealed.
-- security definer: must see the parent title regardless of caller RLS (draft titles); only reads and raises.
create or replace function public.subscriptions_check_target()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.titles t
    where t.id = new.title_id and t.type = 'series' and t.is_published
  ) then
    raise exception 'subscription target is not available' using errcode = 'foreign_key_violation';
  end if;
  return new;
end;
$$;

revoke execute on function public.subscriptions_check_target() from public, anon, authenticated;

create trigger subscriptions_check_target
  before insert or update of title_id on public.subscriptions
  for each row execute function public.subscriptions_check_target();

-- A title's type may not change while children depend on it: seasons (1.2) and subscriptions (1.6) need a series,
-- direct video sources (1.3) and watch progress (1.5) need a movie. Otherwise those rows would silently become unreachable.
-- security definer: must see child rows regardless of caller RLS (draft titles); only checks existence and raises.
create or replace function public.titles_check_type_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.type is distinct from old.type and (
    exists (select 1 from public.seasons s where s.title_id = new.id)
    or exists (select 1 from public.video_sources v where v.title_id = new.id)
    or exists (select 1 from public.watch_progress w where w.title_id = new.id)
    or exists (select 1 from public.subscriptions s where s.title_id = new.id)
  ) then
    raise exception 'title % type cannot change while it has seasons, video sources, watch progress or subscriptions', new.id
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

alter table public.subscriptions enable row level security;

create policy "subscriptions_select_own" on public.subscriptions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "subscriptions_insert_own" on public.subscriptions
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "subscriptions_update_own" on public.subscriptions
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "subscriptions_delete_own" on public.subscriptions
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Clients subscribe (insert, on conflict do nothing), mute/unmute (update is_muted) and unsubscribe (delete).
-- created_at stays server-managed; the key columns can't be rewritten in place.
revoke insert, update, truncate, references, trigger on public.subscriptions from anon, authenticated;
revoke select, delete on public.subscriptions from anon;
grant insert (user_id, title_id, is_muted) on public.subscriptions to authenticated;
grant update (is_muted) on public.subscriptions to authenticated;
