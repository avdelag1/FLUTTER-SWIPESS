-- One server-side entitlement for AI, Events and Legal. Paid subscriptions win;
-- otherwise the new-user welcome campaign grants the configured trial period.
-- Virtual/Local ID is intentionally not part of this gate and remains free.

create or replace function public.rpc_has_premium_feature_access()
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_created_at timestamptz;
  v_signup_starts_at timestamptz;
  v_signup_ends_at timestamptz;
  v_updated_at timestamptz;
  v_trial_months integer;
  v_accepting boolean;
  v_access_starts_at timestamptz;
  v_signup_cutoff timestamptz;
  v_trial_ends_at timestamptz;
begin
  if v_user_id is null then
    return false;
  end if;

  if exists (
    select 1
    from public.user_subscriptions us
    join public.subscription_packages sp on sp.id = us.package_id
    where us.user_id = v_user_id
      and us.is_active = true
      and (us.end_date is null or us.end_date > now())
      and lower(coalesce(sp.tier, 'free')) <> 'free'
  ) then
    return true;
  end if;

  select u.created_at
    into v_created_at
  from auth.users u
  where u.id = v_user_id;

  if v_created_at is null then
    return false;
  end if;

  select c.signup_starts_at,
         c.signup_ends_at,
         c.updated_at,
         greatest(1, least(coalesce(c.trial_months, 3), 24)),
         coalesce(c.accepting_new_signups, false)
    into v_signup_starts_at,
         v_signup_ends_at,
         v_updated_at,
         v_trial_months,
         v_accepting
  from public.app_access_campaigns c
  where c.campaign_key = 'new_user_premium_trial'
  limit 1;

  if v_signup_starts_at is null then
    return false;
  end if;

  v_access_starts_at := greatest(v_created_at, v_signup_starts_at);
  v_signup_cutoff := coalesce(
    v_signup_ends_at,
    case when v_accepting then null else v_updated_at end
  );

  if v_signup_cutoff is not null and v_access_starts_at >= v_signup_cutoff then
    return false;
  end if;

  v_trial_ends_at := v_access_starts_at + make_interval(months => v_trial_months);
  return now() < v_trial_ends_at;
end;
$$;

revoke all on function public.rpc_has_premium_feature_access() from public, anon;
grant execute on function public.rpc_has_premium_feature_access() to authenticated;
