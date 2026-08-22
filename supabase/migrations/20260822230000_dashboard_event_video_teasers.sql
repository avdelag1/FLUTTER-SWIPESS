create or replace function public.rpc_event_video_teasers(p_limit integer default 8)
returns table (
  id uuid,
  title text,
  video_url text,
  video_audio_enabled boolean
)
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select
    e.id,
    e.title,
    e.video_url,
    coalesce(e.video_audio_enabled, true)
  from public.events e
  where e.is_published = true
    and e.is_approved = true
    and nullif(btrim(e.video_url), '') is not null
  order by e.created_at desc nulls last
  limit least(greatest(coalesce(p_limit, 8), 1), 12);
$$;

revoke all on function public.rpc_event_video_teasers(integer) from public;
grant execute on function public.rpc_event_video_teasers(integer) to anon, authenticated;
