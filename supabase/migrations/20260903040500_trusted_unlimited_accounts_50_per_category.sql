-- Trusted launch accounts keep permanent Unlimited access while their active
-- marketplace inventory is capped independently at 50 items per listing
-- category (property, yacht, motorcycle, bicycle, worker, and any future
-- listing category). Events and other premium features remain uncapped.
-- Resolve users/packages by stable email/name instead of generated UUID/ID.

do $$
declare
  v_package_id bigint;
begin
  select sp.id
    into v_package_id
  from public.subscription_packages sp
  where lower(coalesce(sp.tier, '')) = 'unlimited'
    and lower(coalesce(sp.name, '')) = 'unlimited owner'
    and coalesce(sp.is_active, true) = true
  order by sp.id desc
  limit 1;

  if v_package_id is null then
    raise exception 'Active Unlimited Owner package not found';
  end if;

  insert into public.user_content_limit_overrides (
    user_id,
    max_active_per_listing_category,
    max_active_events,
    label,
    updated_at
  )
  select
    u.id,
    50,
    null,
    case lower(u.email)
      when 'lakin.hatulum@gmail.com' then 'Lakin - Ha · trusted unlimited'
      when 'onefithealth@gmail.com' then 'OneFitHealth · trusted unlimited'
      when 'woorkify@gmail.com' then 'Woorkify · trusted unlimited'
      else 'Trusted unlimited'
    end,
    now()
  from auth.users u
  where lower(u.email) in (
    'lakin.hatulum@gmail.com',
    'onefithealth@gmail.com',
    'woorkify@gmail.com'
  )
  on conflict (user_id) do update
  set max_active_per_listing_category = 50,
      max_active_events = null,
      label = excluded.label,
      updated_at = now();

  insert into public.user_subscriptions (
    user_id,
    package_id,
    start_date,
    end_date,
    is_active,
    payment_status,
    created_at,
    updated_at
  )
  select
    u.id,
    v_package_id,
    now(),
    null,
    true,
    'paid',
    now(),
    now()
  from auth.users u
  where lower(u.email) in (
    'lakin.hatulum@gmail.com',
    'onefithealth@gmail.com',
    'woorkify@gmail.com'
  )
  on conflict (user_id, package_id) do update
  set end_date = null,
      is_active = true,
      payment_status = 'paid',
      updated_at = now();

  -- Keep the legacy fallback in sync too. The subscription row remains the
  -- authoritative entitlement used by current clients and paid-video checks.
  update public.profiles p
  set package = 'unlimited'
  where p.id in (
    select u.id
    from auth.users u
    where lower(u.email) in (
      'lakin.hatulum@gmail.com',
      'onefithealth@gmail.com',
      'woorkify@gmail.com'
    )
  );
end
$$;
