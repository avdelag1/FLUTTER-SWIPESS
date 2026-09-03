create or replace function private.dispatch_queued_listing_videos(p_limit integer default 25)
returns table(listing_id uuid, request_id bigint)
language plpgsql
security definer
set search_path = public, private, net, pg_temp
as $$
declare
  v_listing_id uuid;
begin
  for v_listing_id in
    select l.id
    from public.listings l
    where l.video_original_url is not null
      and l.video_processing_status = 'queued'
      and l.video_playback_url is null
    order by l.updated_at desc
    limit greatest(1, least(coalesce(p_limit, 25), 100))
  loop
    listing_id := v_listing_id;
    request_id := private.dispatch_listing_video(v_listing_id);
    return next;
  end loop;
end;
$$;

revoke all on function private.dispatch_queued_listing_videos(integer) from public;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'listing-video-pipeline-retry'
  limit 1;
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end $$;

select cron.schedule(
  'listing-video-pipeline-retry',
  '*/5 * * * *',
  $cron$select private.dispatch_queued_listing_videos(10);$cron$
);
