-- Keep video moderation sequenced after the server has produced the canonical
-- delivery MP4. The moderator can then inspect the exact file users will play.
create or replace function private.queue_ready_listing_video_moderation()
returns trigger
language plpgsql
security definer
set search_path to 'public','private','net','pg_temp'
as $function$
declare
  v_secret text;
begin
  if new.status = 'ready'
     and (tg_op = 'INSERT' or old.status is distinct from new.status)
     and nullif(btrim(coalesce(new.playback_url, '')), '') is not null then
    select secret into v_secret
    from public.internal_job_secrets
    where job_name = 'listing-video-moderation';

    if v_secret is not null then
      perform net.http_post(
        url := 'https://vplgtcguxujxwrgguxqq.supabase.co/functions/v1/moderate-video',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-job-secret', v_secret
        ),
        body := jsonb_build_object('listing_id', new.listing_id::text),
        timeout_milliseconds := 5000
      );
    end if;
  end if;
  return null;
end;
$function$;

drop trigger if exists listing_video_jobs_queue_moderation_when_ready
  on public.listing_video_jobs;
create trigger listing_video_jobs_queue_moderation_when_ready
after insert or update of status on public.listing_video_jobs
for each row execute function private.queue_ready_listing_video_moderation();

-- Dashboard quick filters are live discovery, not an owner's archive. Keep at
-- most the newest own listing in the eight-card preview, promote approved ready
-- video listings first, and never allow own listings into the full swipe deck.
create or replace function public.app_get_smart_listings(
  p_category text default 'property'::text,
  p_city text default null::text,
  p_country text default null::text,
  p_limit integer default 30,
  p_offset integer default 0
)
returns setof public.listings
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_category text := lower(btrim(coalesce(p_category, 'property')));
  v_market jsonb;
  v_features jsonb;
  v_market_open boolean;
  v_requested_feature text;
  v_is_quick_preview boolean := coalesce(p_limit, 30) <= 8;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_market := public.app_market_context(p_city, p_country);
  v_features := coalesce(v_market->'features', '{}'::jsonb);
  v_market_open := coalesce((v_market->>'effective_open')::boolean, true);

  v_requested_feature := case v_category
    when 'property' then 'properties'
    when 'services' then 'workers'
    when 'worker' then 'workers'
    when 'yacht' then 'yachts'
    when 'motorcycle' then 'motorcycles'
    when 'bicycle' then 'bicycles'
    else null
  end;

  if not v_market_open then return; end if;

  if v_category not in ('all', 'recommended', 'popular')
     and v_requested_feature is not null
     and coalesce((v_features->>v_requested_feature)::boolean, true) = false then
    return;
  end if;

  return query
  with candidates as (
    select
      l.*,
      case
        when v_is_quick_preview and l.owner_id = v_uid then
          row_number() over (
            partition by (l.owner_id = v_uid)
            order by l.created_at desc nulls last, l.id
          )
        else 1
      end as owner_preview_rank
    from public.listings l
    where coalesce(l.is_active, true) = true
      and coalesce(l.status, 'active') = 'active'
      and (v_is_quick_preview or l.owner_id is distinct from v_uid)
      and (
        v_category in ('all', 'recommended', 'popular')
        or lower(coalesce(l.category, '')) = v_category
        or (v_category = 'services' and lower(coalesce(l.category, '')) = 'worker')
        or (v_category = 'worker' and lower(coalesce(l.category, '')) = 'services')
      )
      and (
        v_is_quick_preview
        or p_city is null or btrim(p_city) = ''
        or lower(btrim(coalesce(l.city, ''))) = lower(btrim(p_city))
      )
      and (
        (v_is_quick_preview and l.owner_id = v_uid)
        or p_country is null or btrim(p_country) = ''
        or l.country is null or btrim(l.country) = ''
        or lower(btrim(l.country)) = lower(btrim(p_country))
      )
      and (
        case lower(coalesce(l.category, ''))
          when 'property' then coalesce((v_features->>'properties')::boolean, true)
          when 'services' then coalesce((v_features->>'workers')::boolean, true)
          when 'worker' then coalesce((v_features->>'workers')::boolean, true)
          when 'yacht' then coalesce((v_features->>'yachts')::boolean, true)
          when 'motorcycle' then coalesce((v_features->>'motorcycles')::boolean, true)
          when 'bicycle' then coalesce((v_features->>'bicycles')::boolean, true)
          else true
        end
      )
      and (
        v_is_quick_preview
        or public._discovery_listing_visible(
          v_uid,
          l.id,
          l.price,
          l.hourly_rate,
          l.description,
          l.images
        )
      )
  ), picked as (
    select c.*
    from candidates c
    where not v_is_quick_preview
       or c.owner_id is distinct from v_uid
       or c.owner_preview_rank = 1
    order by
      case
        when v_is_quick_preview
         and c.video_moderation_status = 'approved'
         and c.video_processing_status = 'ready'
         and nullif(btrim(coalesce(c.video_playback_url, c.video_url, '')), '') is not null
        then 1 else 0
      end desc,
      case when v_is_quick_preview and c.owner_id = v_uid then 1 else 0 end desc,
      case when v_category = 'popular' then coalesce(c.likes, 0) end desc nulls last,
      case when v_category = 'popular' then coalesce(c.views, 0) end desc nulls last,
      case when v_category = 'recommended' then coalesce(c.likes, 0) end desc nulls last,
      case when v_category not in ('recommended', 'popular') then c.created_at end desc nulls last,
      case when coalesce(c.verification_status, 'unverified') = 'approved' then 1 else 0 end desc,
      c.created_at desc nulls last,
      c.id
    limit greatest(1, least(coalesce(p_limit, 30), 100))
    offset greatest(0, coalesce(p_offset, 0))
  )
  select (
    jsonb_populate_record(
      null::public.listings,
      (to_jsonb(picked) - 'owner_preview_rank')
      || jsonb_build_object('video_original_url', null)
      || case
        when picked.video_moderation_status = 'approved'
         and picked.video_processing_status = 'ready'
        then '{}'::jsonb
        else jsonb_build_object(
          'video_url', null,
          'video_playback_url', null,
          'video_hls_url', null,
          'video_poster_url', null
        )
      end
    )
  ).*
  from picked;
end;
$function$;
