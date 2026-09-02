-- Per-user content overrides for trusted launch accounts.
-- Unlike account_content_limits, listing limits here apply independently to
-- each category (property, yacht, worker, motorcycle, bicycle).

create table if not exists public.user_content_limit_overrides (
  user_id uuid primary key references auth.users(id) on delete cascade,
  max_active_per_listing_category integer null check (
    max_active_per_listing_category is null or max_active_per_listing_category >= 0
  ),
  max_active_events integer null check (
    max_active_events is null or max_active_events >= 0
  ),
  label text null,
  updated_at timestamptz not null default now()
);

alter table public.user_content_limit_overrides enable row level security;

insert into public.user_content_limit_overrides (
  user_id,
  max_active_per_listing_category,
  max_active_events,
  label,
  updated_at
)
values
  ('8a9091cb-be99-4989-8007-fdba7d580143'::uuid, 50, 50, 'Lakin - Ha', now()),
  ('d16b56de-95ff-47fb-84a5-57ade3441fff'::uuid, 50, 50, 'Woorkify', now()),
  ('2e50c534-9979-4885-b126-8a6c6384fc0d'::uuid, 50, 50, 'OneFitHealth', now())
on conflict (user_id) do update
set max_active_per_listing_category = excluded.max_active_per_listing_category,
    max_active_events = excluded.max_active_events,
    label = excluded.label,
    updated_at = now();

create or replace function public.content_quota_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_tier text;
  v_listing_limit integer;
  v_event_limit integer;
  v_listing_count integer;
  v_event_count integer;
  v_override_category_limit integer;
  v_override_event_limit integer;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  v_tier := public._effective_content_tier(v_user);

  select l.max_active_listings, l.max_active_events
    into v_listing_limit, v_event_limit
  from public.account_content_limits l
  where l.tier = v_tier;

  select o.max_active_per_listing_category, o.max_active_events
    into v_override_category_limit, v_override_event_limit
  from public.user_content_limit_overrides o
  where o.user_id = v_user;

  select count(*)::integer
    into v_listing_count
  from public.listings x
  where x.owner_id = v_user
    and coalesce(x.is_active, true) = true
    and coalesce(x.status, 'active') = 'active';

  select count(*)::integer
    into v_event_count
  from public.business_promo_submissions e
  where e.user_id = v_user
    and e.status in ('pending', 'approved')
    and (
      e.published_event_id is not null
      or e.event_type is not null
      or e.title is not null
    );

  if v_override_event_limit is not null then
    v_event_limit := v_override_event_limit;
  end if;

  return jsonb_build_object(
    'tier', v_tier,
    'quota_override', v_override_category_limit is not null or v_override_event_limit is not null,
    'max_active_per_listing_category', v_override_category_limit,
    'active_listings', v_listing_count,
    'max_active_listings', v_listing_limit,
    'listing_remaining', case
      when v_listing_limit is null then null
      else greatest(v_listing_limit - v_listing_count, 0)
    end,
    'can_create_listing', v_listing_limit is null or v_listing_count < v_listing_limit,
    'active_or_pending_events', v_event_count,
    'max_active_events', v_event_limit,
    'event_remaining', case
      when v_event_limit is null then null
      else greatest(v_event_limit - v_event_count, 0)
    end,
    'can_create_event', v_event_limit is null or v_event_count < v_event_limit
  );
end;
$$;

create or replace function public.rpc_can_publish_listing(p_category text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_category text := lower(btrim(coalesce(p_category, '')));
  v_status jsonb;
  v_video_enabled boolean;
  v_override_limit integer;
  v_category_count integer;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  v_status := public.content_quota_status();

  select o.max_active_per_listing_category
    into v_override_limit
  from public.user_content_limit_overrides o
  where o.user_id = v_user;

  if found then
    select count(*)::integer
      into v_category_count
    from public.listings x
    where x.owner_id = v_user
      and lower(coalesce(x.category, '')) = v_category
      and coalesce(x.is_active, true) = true
      and coalesce(x.status, 'active') = 'active';

    v_status := v_status || jsonb_build_object(
      'quota_override', true,
      'active_listings', v_category_count,
      'max_active_listings', v_override_limit,
      'listing_remaining', case
        when v_override_limit is null then null
        else greatest(v_override_limit - v_category_count, 0)
      end,
      'can_create_listing', v_override_limit is null or v_category_count < v_override_limit
    );
  end if;

  select mr.video_enabled
    into v_video_enabled
  from public.platform_media_rules mr
  where mr.content_type = v_category;

  return v_status || jsonb_build_object(
    'category', v_category,
    'video_enabled', coalesce(v_video_enabled, false)
  );
end;
$$;

create or replace function public.enforce_listing_content_guardrails()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tier text;
  v_limit integer;
  v_count integer;
  v_video_enabled boolean;
  v_override_limit integer;
  v_category text := lower(coalesce(new.category, ''));
begin
  if public._is_active_admin(new.owner_id) then
    return new;
  end if;

  if new.video_url is not null and btrim(new.video_url) <> '' then
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
       and lower(coalesce(old.category, '')) = v_category then
      return new;
    end if;

    select o.max_active_per_listing_category
      into v_override_limit
    from public.user_content_limit_overrides o
    where o.user_id = new.owner_id;

    if found then
      if v_override_limit is not null then
        select count(*)::integer
          into v_count
        from public.listings x
        where x.owner_id = new.owner_id
          and lower(coalesce(x.category, '')) = v_category
          and coalesce(x.is_active, true) = true
          and coalesce(x.status, 'active') = 'active'
          and (tg_op <> 'UPDATE' or x.id <> new.id);

        if v_count >= v_override_limit then
          raise exception 'Active % listing limit reached (% listings)',
            v_category, v_override_limit;
        end if;
      end if;
    else
      v_tier := public._effective_content_tier(new.owner_id);
      select l.max_active_listings
        into v_limit
      from public.account_content_limits l
      where l.tier = v_tier;

      if v_limit is not null then
        select count(*)::integer
          into v_count
        from public.listings x
        where x.owner_id = new.owner_id
          and coalesce(x.is_active, true) = true
          and coalesce(x.status, 'active') = 'active'
          and (tg_op <> 'UPDATE' or x.id <> new.id);

        if v_count >= v_limit then
          raise exception 'Active listing limit reached for % tier (% listings)',
            v_tier, v_limit;
        end if;
      end if;
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.enforce_event_content_guardrails()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tier text;
  v_limit integer;
  v_count integer;
  v_override_limit integer;
begin
  if new.user_id is null or public._is_active_admin(new.user_id) then
    return new;
  end if;

  if new.video_url is not null
     and btrim(new.video_url) <> ''
     and not exists (
       select 1
       from public.platform_media_rules mr
       where mr.content_type = 'event'
         and mr.video_enabled = true
     ) then
    raise exception 'Event video uploads are currently disabled';
  end if;

  if coalesce(new.status, 'pending') in ('pending', 'approved') then
    if tg_op = 'UPDATE'
       and coalesce(old.status, 'pending') in ('pending', 'approved') then
      return new;
    end if;

    select o.max_active_events
      into v_override_limit
    from public.user_content_limit_overrides o
    where o.user_id = new.user_id;

    if found then
      v_limit := v_override_limit;
    else
      v_tier := public._effective_content_tier(new.user_id);
      select l.max_active_events
        into v_limit
      from public.account_content_limits l
      where l.tier = v_tier;
    end if;

    if v_limit is not null then
      select count(*)::integer
        into v_count
      from public.business_promo_submissions e
      where e.user_id = new.user_id
        and e.status in ('pending', 'approved')
        and (tg_op <> 'UPDATE' or e.id <> new.id);

      if v_count >= v_limit then
        raise exception 'Active/pending event limit reached (% events)', v_limit;
      end if;
    end if;
  end if;

  return new;
end;
$$;

revoke all on table public.user_content_limit_overrides from anon, authenticated;
revoke execute on function public.enforce_listing_content_guardrails() from public, anon, authenticated;
revoke execute on function public.enforce_event_content_guardrails() from public, anon, authenticated;
revoke execute on function public.content_quota_status() from public, anon;
grant execute on function public.content_quota_status() to authenticated;
revoke execute on function public.rpc_can_publish_listing(text) from public, anon;
grant execute on function public.rpc_can_publish_listing(text) to authenticated;
