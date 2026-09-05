create or replace function public.sync_studio_listing_video_metadata()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job public.studio_video_jobs%rowtype;
begin
  if new.video_url is null or position('/processed/studio/' in new.video_url) = 0 then
    return new;
  end if;

  select * into v_job
  from public.studio_video_jobs
  where owner_id = new.owner_id
    and playback_url = new.video_url
    and status = 'ready'
  order by completed_at desc nulls last, created_at desc
  limit 1;

  if found then
    new.video_original_url := coalesce(nullif(btrim(new.video_original_url), ''), new.video_url);
    new.video_playback_url := new.video_url;
    new.video_poster_url := coalesce(nullif(btrim(new.video_poster_url), ''), v_job.poster_url);
    new.video_processing_status := 'ready';
    new.video_processing_error := null;
    new.video_processed_at := coalesce(v_job.completed_at, now());
    -- Studio videos are synthesized only from images that already passed image
    -- moderation, so the generated MP4 is safe to expose to discovery immediately.
    new.video_moderation_status := 'approved';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_studio_listing_video_metadata on public.listings;
create trigger trg_sync_studio_listing_video_metadata
before insert or update of video_url on public.listings
for each row
execute function public.sync_studio_listing_video_metadata();
