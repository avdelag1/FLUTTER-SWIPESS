-- Align paid Premium package promises with the authoritative backend.
-- Monthly / Semi-Annual / Yearly include 20 / 50 / 150 Direct Requests.

CREATE OR REPLACE FUNCTION public.service_grant_subscription_direct_requests(
  p_user_id uuid,
  p_product_id text,
  p_transaction_key text,
  p_expires_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_amount integer;
  v_token_id uuid;
  v_existing public.subscription_direct_request_grants;
BEGIN
  IF p_user_id IS NULL OR NULLIF(trim(p_transaction_key), '') IS NULL THEN
    RAISE EXCEPTION 'Invalid subscription grant';
  END IF;

  v_amount := CASE p_product_id
    WHEN 'Swipess.plus.monthly.v3' THEN 20
    WHEN 'swipess.plus.monthly.v2' THEN 20
    WHEN 'Swipess.plus.semestral.v3' THEN 50
    WHEN 'swipess.plus.semestral.v2' THEN 50
    WHEN 'Swipess.plus.annual.v3' THEN 150
    WHEN 'swipess.plus.annual.v2' THEN 150
    ELSE NULL
  END;

  IF v_amount IS NULL THEN
    RAISE EXCEPTION 'Unsupported subscription product';
  END IF;

  SELECT * INTO v_existing
  FROM public.subscription_direct_request_grants
  WHERE transaction_key = p_transaction_key;

  IF FOUND THEN
    IF v_existing.user_id <> p_user_id OR v_existing.product_id <> p_product_id THEN
      RAISE EXCEPTION 'Subscription transaction already belongs to another entitlement';
    END IF;
    RETURN jsonb_build_object(
      'granted', false,
      'already_granted', true,
      'amount', v_existing.amount,
      'token_row_id', v_existing.token_row_id
    );
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
    'subscription',
    'premium_included',
    'Premium Direct Requests: ' || p_product_id,
    p_expires_at
  )
  RETURNING id INTO v_token_id;

  INSERT INTO public.subscription_direct_request_grants(
    transaction_key,
    user_id,
    product_id,
    amount,
    token_row_id
  ) VALUES (
    p_transaction_key,
    p_user_id,
    p_product_id,
    v_amount,
    v_token_id
  );

  RETURN jsonb_build_object(
    'granted', true,
    'already_granted', false,
    'amount', v_amount,
    'token_row_id', v_token_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.service_grant_subscription_direct_requests(uuid, text, text, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.service_grant_subscription_direct_requests(uuid, text, text, timestamptz)
  TO service_role;
