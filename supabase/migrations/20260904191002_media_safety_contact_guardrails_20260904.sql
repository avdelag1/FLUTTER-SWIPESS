alter table public.listings
  add column if not exists video_moderation_status text not null default 'none',
  add column if not exists video_moderation_reason text,
  add column if not exists video_moderated_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'listings_video_moderation_status_check'
      and conrelid = 'public.listings'::regclass
  ) then
    alter table public.listings
      add constraint listings_video_moderation_status_check
      check (video_moderation_status in ('none','queued','processing','approved','rejected','review'));
  end if;
end $$;

update public.listings
set video_moderation_status = case
      when video_processing_status = 'ready'
       and nullif(btrim(coalesce(video_playback_url, video_url, '')), '') is not null
      then 'approved'
      when nullif(btrim(coalesce(video_original_url, '')), '') is not null
       and video_processing_status in ('queued','processing')
      then 'queued'
      else 'none'
    end,
    video_moderated_at = case
      when video_processing_status = 'ready'
       and nullif(btrim(coalesce(video_playback_url, video_url, '')), '') is not null
      then coalesce(video_processed_at, now())
      else video_moderated_at
    end
where video_moderation_status = 'none';

create or replace function public._listing_external_contact_reason(
  p_title text,
  p_description text
) returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := coalesce(p_title, '') || E'\n' || coalesce(p_description, '');
begin
  if v ~* '(^|[^[:alnum:]_.%+\-])[[:alnum:]_.%+\-]+@[[:alnum:].\-]+\.[[:alpha:]]{2,}([^[:alnum:]_.\-]|$)' then
    return 'Email addresses are not allowed in listings';
  end if;

  if v ~* '(https?://|www\.|wa\.me/|t\.me/|instagram\.com/|facebook\.com/|fb\.com/|tiktok\.com/|x\.com/|twitter\.com/|linktr\.ee/)' then
    return 'External links and social links are not allowed in listings';
  end if;

  if v ~* '(^|[[:space:][:punct:]])@[[:alnum:]_.]{3,}' then
    return 'Social-media handles are not allowed in listings';
  end if;

  if v ~* '(^|[^0-9])[+]?[0-9]{10,15}([^0-9]|$)'
     or v ~* '(^|[^0-9])[+]?[0-9][0-9 ()\-]{8,}[0-9]([^0-9]|$)' then
    return 'Phone or WhatsApp numbers are not allowed in listings';
  end if;

  return null;
end;
$$;

create or replace function public.enforce_listing_content_guardrails()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer;
  v_count integer;
  v_video_enabled boolean;
  v_category text := lower(btrim(coalesce(new.category, '')));
  v_video_changed boolean := false;
  v_has_override boolean := false;
  v_contact_reason text;
begin
  v_contact_reason := public._listing_external_contact_reason(new.title, new.description);
  if v_contact_reason is not null then
    raise exception '%', v_contact_reason using errcode = '22023';
  end if;

  if public._is_active_admin(new.owner_id) then
    return new;
  end if;

  v_video_changed := new.video_url is not null
    and btrim(new.video_url) <> ''
    and (tg_op = 'INSERT' or old.video_url is distinct from new.video_url);

  if v_video_changed then
    select mr.video_enabled
      into v_video_enabled
    from public.platform_media_rules mr
    where mr.content_type = v_category;

    if coalesce(v_video_enabled, false) = false then
      raise exception 'Video is not enabled for % listings',
        coalesce(new.category, 'this category');
    end if;
  end if;

  if coalesce(new.is_active, true) = true
     and coalesce(new.status, 'active') = 'active' then
    if tg_op = 'UPDATE'
       and coalesce(old.is_active, true) = true
       and coalesce(old.status, 'active') = 'active'
       and lower(btrim(coalesce(old.category, ''))) = v_category then
      return new;
    end if;

    select exists (
      select 1
      from public.user_content_limit_overrides o
      where o.user_id = new.owner_id
    ) into v_has_override;

    if v_has_override then
      select o.max_active_per_listing_category
        into v_limit
      from public.user_content_limit_overrides o
      where o.user_id = new.owner_id;
    else
      v_limit := 6;
    end if;

    if v_limit is not null then
      select count(*)::integer
        into v_count
      from public.listings x
      where x.owner_id = new.owner_id
        and lower(btrim(coalesce(x.category, ''))) = v_category
        and coalesce(x.is_active, true) = true
        and coalesce(x.status, 'active') = 'active'
        and (tg_op <> 'UPDATE' or x.id <> new.id);

      if v_count >= v_limit then
        raise exception 'Active % listing limit reached (% listings)',
          v_category, v_limit;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_listing_content_guardrails on public.listings;
create trigger trg_listing_content_guardrails
before insert or update of status, is_active, video_url, category, title, description
on public.listings
for each row execute function public.enforce_listing_content_guardrails();

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
      if coalesce(new.video_moderation_status, 'none') not in ('rejected','review') then
        new.video_moderation_status := 'none';
        new.video_moderation_reason := null;
        new.video_moderated_at := null;
      end if;
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
      new.video_moderation_status := 'queued';
      new.video_moderation_reason := null;
      new.video_moderated_at := null;
    end if;
  end if;
  return new;
end;
$$;

insert into public.internal_job_secrets(job_name, secret)
select 'listing-video-moderation', encode(gen_random_bytes(32), 'hex')
where not exists (
  select 1 from public.internal_job_secrets where job_name = 'listing-video-moderation'
);

create or replace function private.queue_listing_video_moderation()
returns trigger
language plpgsql
security definer
set search_path = public, private, net, pg_temp
as $$
declare
  v_secret text;
begin
  if new.video_moderation_status = 'queued'
     and nullif(btrim(coalesce(new.video_original_url, '')), '') is not null
     and (
       tg_op = 'INSERT'
       or new.video_original_url is distinct from old.video_original_url
       or old.video_moderation_status is distinct from new.video_moderation_status
     ) then
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
        body := jsonb_build_object('listing_id', new.id::text),
        timeout_milliseconds := 5000
      );
    end if;
  end if;
  return null;
end;
$$;

revoke all on function public._listing_external_contact_reason(text, text) from public;
revoke all on function private.queue_listing_video_moderation() from public;

drop trigger if exists listings_queue_video_moderation on public.listings;
create trigger listings_queue_video_moderation
after insert or update of video_url on public.listings
for each row execute function private.queue_listing_video_moderation();

create or replace function private.guard_listing_video_promotion()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
begin
  if new.video_url is distinct from old.video_url
     and new.video_url is not null
     and position('/processed/' in new.video_url) > 0
     and coalesce(new.video_moderation_status, old.video_moderation_status, 'none') <> 'approved' then
    return null;
  end if;
  return new;
end;
$$;

revoke all on function private.guard_listing_video_promotion() from public;

drop trigger if exists aaa_listings_guard_video_promotion on public.listings;
create trigger aaa_listings_guard_video_promotion
before update of video_url on public.listings
for each row execute function private.guard_listing_video_promotion();

create or replace function public.app_get_smart_listings(
  p_category text default 'property',
  p_city text default null,
  p_country text default null,
  p_limit integer default 30,
  p_offset integer default 0
) returns setof public.listings
language plpgsql
stable security definer
set search_path = ''
as $$
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
  with picked as (
    select l.*
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
        or public._discovery_listing_visible(v_uid, l.id, l.price, l.hourly_rate, l.description, l.images)
      )
    order by
      case when v_is_quick_preview and l.owner_id = v_uid then 1 else 0 end desc,
      case
        when v_is_quick_preview
         and l.video_moderation_status = 'approved'
         and l.video_processing_status = 'ready'
         and nullif(btrim(coalesce(l.video_playback_url, l.video_url, '')), '') is not null
        then 1 else 0
      end desc,
      case when v_category = 'popular' then coalesce(l.likes, 0) end desc nulls last,
      case when v_category = 'popular' then coalesce(l.views, 0) end desc nulls last,
      case when v_category = 'recommended' then coalesce(l.likes, 0) end desc nulls last,
      case when v_category not in ('recommended', 'popular') then l.created_at end desc nulls last,
      case when coalesce(l.verification_status, 'unverified') = 'approved' then 1 else 0 end desc,
      l.created_at desc nulls last,
      l.id
    limit greatest(1, least(coalesce(p_limit, 30), 100))
    offset greatest(0, coalesce(p_offset, 0))
  )
  select (
    jsonb_populate_record(
      null::public.listings,
      to_jsonb(picked)
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
$$;
