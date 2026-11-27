-- is_finished transitions (client sets the flag, the DB guards it):
--   false → true only at ≥ 90 % watched; true stays true at any position; true → false always allowed.
-- 90 % is checked in integers: position_sec * 10 >= duration_sec * 9 (bigint: no float rounding, no int4 overflow).
-- Positions above duration count as 100 % (watch_progress_check_target clamps them anyway).
--
-- INSERT path: an upsert fires BEFORE INSERT before the conflict is found, so a re-send of true for an
-- already finished row would look like "new row, true below 90 %". The insert path therefore allows true
-- below 90 % only if the caller's stored row for the same target is already finished; the DO UPDATE branch
-- then runs the UPDATE path (old true → new true: allowed). A plain insert of such a row still fails on the
-- unique constraint (23505).
-- UPDATE path: the stored value counts only if the target is unchanged (moving a row to another episode/movie
-- is judged like a new row).
-- security invoker: reads only the caller's own rows (owner RLS); service role bypasses RLS.
create or replace function public.watch_progress_check_finished()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_was_finished boolean;
begin
  if not new.is_finished or new.position_sec::bigint * 10 >= new.duration_sec::bigint * 9 then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    v_was_finished := old.is_finished
      and old.episode_id is not distinct from new.episode_id
      and old.title_id   is not distinct from new.title_id;
  else
    select w.is_finished into v_was_finished
      from public.watch_progress w
     where w.user_id = new.user_id
       and (w.episode_id = new.episode_id or w.title_id = new.title_id);
  end if;

  if coalesce(v_was_finished, false) then
    return new;
  end if;

  raise exception 'is_finished can be set only after 90%% of the duration is watched'
    using errcode = 'check_violation';
end;
$$;

revoke execute on function public.watch_progress_check_finished() from public, anon, authenticated;

create trigger watch_progress_check_finished
  before insert or update on public.watch_progress
  for each row execute function public.watch_progress_check_finished();
