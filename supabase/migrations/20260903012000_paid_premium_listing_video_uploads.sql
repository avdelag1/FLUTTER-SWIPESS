-- Listing videos are a paid Premium promotion benefit.
-- Existing videos can stay visible after a plan ends, but adding/replacing a
-- listing video requires a currently paid subscription (admins bypass this).

create or replace function public._has_paid_listing_video_access(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null
     and (
       public._is_active_admin(p_user_id)
       or exists (
         select 1
         from public.user_subscriptions us
         join public.subscription_packages sp on sp.id = us.package_id
         where us.user_id = p_user_id
           and coalesce(us.is_active, false) = true
           and coalesce(us.payment_status, '') = 'paid'
           and (us.end_date is null or us.end_date > now())
           and coalesce(sp.is_active, true) = true
           and lower(coalesce(sp.tier, 'free')) in (
             'basic', 'premium', 'premium_plus', 'unlimited'
           )
       )
     );
$$;

create or replace function public.rpc_can_upload_listing_video()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public._has_paid_listing_video_access(auth.uid());
$$;

-- New-listing video uploads still respect listing capacity. Existing-listing
-- replacements use /<user>/listing/<listing-id>/... and remain editable even
-- when the account is currently at its active-listing cap.
drop policy if exists "listing videos insert own folder" on storage.objects;
create policy "listing videos insert own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and public._has_paid_listing_video_access((select auth.uid()))
  and (
    coalesce(((public.content_quota_status()->>'can_create_listing')::boolean), false)
    or (
      (storage.foldername(name))[2] = 'listing'
      and exists (
        select 1
        from public.listings l
        where l.id::text = (storage.foldername(name))[3]
          and l.owner_id = (select auth.uid())
      )
    )
  )
);

drop policy if exists "listing videos update own folder" on storage.objects;
create policy "listing videos update own folder"
on storage.objects for update to authenticated
using (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and public._has_paid_listing_video_access((select auth.uid()))
);

-- Keep the per-user category override logic from the current production guard,
-- while adding paid-video enforcement only when a video is newly added/replaced.
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
  v_video_changed boolean := false;
begin
  if public._is_active_admin(new.owner_id) then
    return new;
  end if;

  v_video_changed := new.video_url is not null
    and btrim(new.video_url) <> ''
    and (tg_op = 'INSERT' or old.video_url is distinct from new.video_url);

  if v_video_changed then
    if not public._has_paid_listing_video_access(new.owner_id) then
      raise exception 'Listing video uploads are a paid Premium benefit';
    end if;

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

-- Add the paid-video capability to the existing listing preflight payload so
-- clients can lock the control before any large upload starts.
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
    'video_enabled', coalesce(v_video_enabled, false),
    'can_upload_video', public._has_paid_listing_video_access(v_user),
    'video_requires_paid_premium', true
  );
end;
$$;

revoke execute on function public._has_paid_listing_video_access(uuid) from public, anon, authenticated;
revoke execute on function public.enforce_listing_content_guardrails() from public, anon, authenticated;
revoke execute on function public.rpc_can_upload_listing_video() from public, anon;
grant execute on function public.rpc_can_upload_listing_video() to authenticated;
revoke execute on function public.rpc_can_publish_listing(text) from public, anon;
grant execute on function public.rpc_can_publish_listing(text) to authenticated;
