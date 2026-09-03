alter table public.listings
  add column if not exists video_hls_url text;

alter table public.listing_video_jobs
  add column if not exists hls_master_url text,
  add column if not exists hls_total_size_bytes bigint,
  add column if not exists hls_output_count integer;

update storage.buckets
set allowed_mime_types = array[
  'video/mp4',
  'video/quicktime',
  'video/webm',
  'image/jpeg',
  'application/vnd.apple.mpegurl',
  'application/x-mpegURL',
  'video/mp2t'
]::text[]
where id = 'listing-videos';

create or replace function private.prepare_listing_video_processing()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
begin
  if tg_op = 'INSERT' or new.video_url is distinct from old.video_url then
    if new.video_url is null or btrim(new.video_url) = '' then
      new.video_original_url := null;
      new.video_playback_url := null;
      new.video_hls_url := null;
      new.video_poster_url := null;
      new.video_processing_status := 'none';
      new.video_processing_error := null;
      new.video_processed_at := null;
    elsif position('/processed/' in new.video_url) > 0 then
      null;
    else
      new.video_original_url := new.video_url;
      new.video_playback_url := null;
      new.video_hls_url := null;
      new.video_poster_url := null;
      new.video_processing_status := 'queued';
      new.video_processing_error := null;
      new.video_processed_at := null;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.record_video_playback_event(
  p_session_id text,
  p_event_type text,
  p_listing_id uuid default null,
  p_surface text default 'quick_filter',
  p_platform text default 'unknown',
  p_network_type text default null,
  p_media_url_hash text default null,
  p_init_ms integer default null,
  p_ttff_ms integer default null,
  p_buffer_ms integer default null,
  p_rebuffer_count integer default null,
  p_position_ms integer default null,
  p_duration_ms integer default null,
  p_error_code text default null,
  p_extra jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_event_type not in ('init','first_frame','rebuffer','playback_error','ended','prefetch') then
    raise exception 'invalid_event_type';
  end if;
  if coalesce(length(p_session_id),0) < 8 or length(p_session_id) > 120 then
    raise exception 'invalid_session_id';
  end if;

  insert into public.video_playback_events(
    session_id,user_id,listing_id,event_type,surface,platform,network_type,media_url_hash,
    init_ms,ttff_ms,buffer_ms,rebuffer_count,position_ms,duration_ms,error_code,extra
  ) values (
    left(p_session_id,120),auth.uid(),p_listing_id,p_event_type,left(coalesce(p_surface,'quick_filter'),80),
    left(coalesce(p_platform,'unknown'),80),left(coalesce(p_network_type,''),80),left(coalesce(p_media_url_hash,''),128),
    case when p_init_ms is null then null else greatest(p_init_ms,0) end,
    case when p_ttff_ms is null then null else greatest(p_ttff_ms,0) end,
    case when p_buffer_ms is null then null else greatest(p_buffer_ms,0) end,
    case when p_rebuffer_count is null then null else greatest(p_rebuffer_count,0) end,
    case when p_position_ms is null then null else greatest(p_position_ms,0) end,
    case when p_duration_ms is null then null else greatest(p_duration_ms,0) end,
    nullif(left(coalesce(p_error_code,''),240),''),coalesce(p_extra,'{}'::jsonb)
  );
end;
$$;