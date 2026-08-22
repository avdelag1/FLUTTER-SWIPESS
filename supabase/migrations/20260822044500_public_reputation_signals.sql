-- Public, factual reputation signals for marketplace decisions.
-- This intentionally avoids an opaque/composite "trust score".

create or replace function public.rpc_get_user_reputation(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_review_count integer := 0;
  v_average_rating numeric := null;
  v_connections integer := 0;
  v_received_requests integer := 0;
  v_responded_requests integer := 0;
  v_response_rate numeric := null;
  v_account_since timestamptz := null;
  v_verified boolean := false;
begin
  select count(*)::integer,
         round(avg(rating)::numeric, 2)
    into v_review_count, v_average_rating
  from public.reviews
  where reviewed_id = p_user_id
    and coalesce(is_flagged, false) = false
    and rating is not null;

  select count(*)::integer
    into v_connections
  from public.conversations
  where deleted_at is null
    and (client_id = p_user_id or owner_id = p_user_id);

  select count(*)::integer,
         count(*) filter (where responded_at is not null)::integer
    into v_received_requests, v_responded_requests
  from public.direct_requests
  where receiver_id = p_user_id;

  if v_received_requests > 0 then
    v_response_rate := round(
      (100.0 * v_responded_requests::numeric / v_received_requests::numeric),
      0
    );
  end if;

  select min(created_at)
    into v_account_since
  from (
    select created_at from public.client_profiles where user_id = p_user_id
    union all
    select created_at from public.owner_profiles where user_id = p_user_id
  ) profile_dates;

  select coalesce(bool_or(verified_owner), false)
    into v_verified
  from public.owner_profiles
  where user_id = p_user_id;

  return jsonb_build_object(
    'user_id', p_user_id,
    'verified', coalesce(v_verified, false),
    'review_count', coalesce(v_review_count, 0),
    'average_rating', v_average_rating,
    'connections', coalesce(v_connections, 0),
    'received_direct_requests', coalesce(v_received_requests, 0),
    'responded_direct_requests', coalesce(v_responded_requests, 0),
    'response_rate', v_response_rate,
    'account_since', v_account_since
  );
end;
$$;

revoke all on function public.rpc_get_user_reputation(uuid) from public;
grant execute on function public.rpc_get_user_reputation(uuid) to anon, authenticated;
