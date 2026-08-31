-- Mirror client SubscriptionTier.unlockAllFeatures during launch.
-- When monetization returns, restore paid/trial checks in this function
-- and set unlockAllFeatures = false in subscription_tier.dart.

create or replace function public.rpc_has_premium_feature_access()
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return false;
  end if;

  -- Launch mode: every signed-in user can use AI, Events, Legal, Local Brain.
  return true;
end;
$$;

revoke all on function public.rpc_has_premium_feature_access() from public, anon;
grant execute on function public.rpc_has_premium_feature_access() to authenticated;
