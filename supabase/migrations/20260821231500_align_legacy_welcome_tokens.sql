-- Older installed builds may still call rpc_grant_welcome_tokens after signup.
-- Route that legacy entry point into the complimentary Direct Request grant so
-- it cannot create a second five-message-token economy alongside the new one.

CREATE OR REPLACE FUNCTION public.rpc_grant_welcome_tokens(
  p_has_referral boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_grant public.complimentary_direct_request_grants;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  PERFORM public.grant_complimentary_direct_requests_for_user(
    v_user_id,
    'new_user_premium_trial'
  );

  -- Preserve the old referral bonus as one extra priority request, but keep it
  -- idempotent and expire it with the same complimentary-access window.
  IF p_has_referral THEN
    SELECT * INTO v_grant
    FROM public.complimentary_direct_request_grants
    WHERE user_id = v_user_id
      AND campaign_key = 'new_user_premium_trial';

    IF FOUND AND NOT EXISTS (
      SELECT 1 FROM public.tokens t
      WHERE t.user_id = v_user_id
        AND t.source = 'referral_welcome'
        AND t.notes = 'Referral Welcome Direct Request'
    ) THEN
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
        v_user_id,
        'messages',
        1,
        1,
        1,
        0,
        'referral',
        'referral_welcome',
        'Referral Welcome Direct Request',
        v_grant.access_ends_at
      );
    END IF;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_grant_welcome_tokens(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_grant_welcome_tokens(boolean) TO authenticated, service_role;
