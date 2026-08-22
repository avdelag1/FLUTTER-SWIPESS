-- Welcome Freemium includes five Direct Requests. Additional requests may be
-- earned through engagement/referrals or purchased separately.
-- Existing grants are not reduced retroactively.
CREATE OR REPLACE FUNCTION public.grant_complimentary_direct_requests_for_user(
  p_user_id uuid,
  p_campaign_key text DEFAULT 'new_user_premium_trial'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
  v_campaign public.app_access_campaigns;
  v_created_at timestamptz;
  v_access_start timestamptz;
  v_access_end timestamptz;
  v_signup_cutoff timestamptz;
  v_months integer;
  v_amount integer := 5;
  v_token_id uuid;
  v_existing public.complimentary_direct_request_grants;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Invalid complimentary access user';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('complimentary:' || p_user_id::text || ':' || p_campaign_key, 0)
  );

  SELECT * INTO v_existing
  FROM public.complimentary_direct_request_grants
  WHERE user_id = p_user_id AND campaign_key = p_campaign_key;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'granted', false,
      'already_granted', true,
      'amount', v_existing.amount,
      'token_row_id', v_existing.token_row_id,
      'access_ends_at', v_existing.access_ends_at
    );
  END IF;

  SELECT * INTO v_campaign
  FROM public.app_access_campaigns
  WHERE campaign_key = p_campaign_key;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('granted', false, 'reason', 'campaign_not_found');
  END IF;

  SELECT created_at INTO v_created_at
  FROM auth.users
  WHERE id = p_user_id;

  IF v_created_at IS NULL OR v_campaign.signup_starts_at IS NULL THEN
    RETURN jsonb_build_object('granted', false, 'reason', 'user_or_campaign_unavailable');
  END IF;

  v_access_start := GREATEST(v_created_at, v_campaign.signup_starts_at);
  v_signup_cutoff := CASE
    WHEN v_campaign.signup_ends_at IS NOT NULL THEN v_campaign.signup_ends_at
    WHEN COALESCE(v_campaign.accepting_new_signups, false) THEN NULL
    ELSE v_campaign.updated_at
  END;

  IF v_signup_cutoff IS NOT NULL AND v_access_start >= v_signup_cutoff THEN
    RETURN jsonb_build_object('granted', false, 'reason', 'signup_window_closed');
  END IF;

  v_months := LEAST(GREATEST(COALESCE(v_campaign.trial_months, 3), 1), 24);
  v_access_end := v_access_start + make_interval(months => v_months);

  IF v_access_end <= now() THEN
    RETURN jsonb_build_object('granted', false, 'reason', 'complimentary_access_ended');
  END IF;

  INSERT INTO public.tokens(
    user_id,
    token_type,
    amount,
    total_activations,
    remaining_activations,
    used_activations,
    activation_type,
    source,
    notes,
    expires_at
  ) VALUES (
    p_user_id,
    'messages',
    v_amount,
    v_amount,
    v_amount,
    0,
    'complimentary',
    'complimentary_welcome',
    'Welcome Direct Requests: ' || p_campaign_key,
    v_access_end
  )
  RETURNING id INTO v_token_id;

  INSERT INTO public.complimentary_direct_request_grants(
    user_id,
    campaign_key,
    amount,
    token_row_id,
    access_starts_at,
    access_ends_at
  ) VALUES (
    p_user_id,
    p_campaign_key,
    v_amount,
    v_token_id,
    v_access_start,
    v_access_end
  );

  RETURN jsonb_build_object(
    'granted', true,
    'already_granted', false,
    'amount', v_amount,
    'token_row_id', v_token_id,
    'access_ends_at', v_access_end
  );
END;
$$;

REVOKE ALL ON FUNCTION public.grant_complimentary_direct_requests_for_user(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.grant_complimentary_direct_requests_for_user(uuid, text)
  TO service_role;
