-- anon has no policy on video_sources/profiles: drop the leftover grants so anon gets 42501
-- (like on the other user-data tables) instead of an empty result.
revoke all on public.video_sources from anon;
revoke all on public.profiles from anon;

-- Trigger functions get no client grants.
revoke execute on function public.set_updated_at() from public, anon, authenticated;
