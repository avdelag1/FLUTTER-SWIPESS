update public.listings
set video_original_url = video_url,
    video_processing_status = 'queued',
    video_processing_error = null,
    video_processed_at = null
where video_url is not null
  and btrim(video_url) <> ''
  and position('/processed/' in video_url) = 0
  and video_original_url is null;

create or replace function private.dispatch_listing_video(p_listing_id uuid)
returns bigint
language plpgsql
security definer
set search_path = public, private, net, pg_temp
as $$
declare
  v_secret text;
  v_request_id bigint;
begin
  select secret into v_secret
  from public.internal_job_secrets
  where job_name = 'listing-video-pipeline';

  if v_secret is null then
    raise exception 'listing-video-pipeline secret missing';
  end if;

  select net.http_post(
    url := 'https://vplgtcguxujxwrgguxqq.supabase.co/functions/v1/video-pipeline',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-job-secret', v_secret
    ),
    body := jsonb_build_object(
      'action', 'retry_internal',
      'listing_id', p_listing_id::text
    ),
    timeout_milliseconds := 5000
  ) into v_request_id;

  return v_request_id;
end;
$$;

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
      and l.video_processing_status in ('queued', 'failed')
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

revoke all on function private.dispatch_listing_video(uuid) from public;
revoke all on function private.dispatch_queued_listing_videos(integer) from public;
