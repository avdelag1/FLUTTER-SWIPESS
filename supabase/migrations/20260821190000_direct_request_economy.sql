-- Swipess Direct Request economy
--
-- Core product contract:
--   * right swipe / interest is free
--   * mutual matches are free
--   * a Direct Request reserves one token
--   * the token is consumed only when the receiver accepts
--   * decline / cancel / expiry releases the reservation automatically
--
-- Events and Legal are intentionally untouched by this migration.

CREATE TABLE IF NOT EXISTS public.direct_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES public.listings(id) ON DELETE SET NULL,
  message text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
  token_consumed boolean NOT NULL DEFAULT false,
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '48 hours'),
  CHECK (sender_id <> receiver_id)
);

CREATE INDEX IF NOT EXISTS direct_requests_sender_status_idx
  ON public.direct_requests(sender_id, status, expires_at);
CREATE INDEX IF NOT EXISTS direct_requests_receiver_status_idx
  ON public.direct_requests(receiver_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS direct_requests_listing_idx
  ON public.direct_requests(listing_id)
  WHERE listing_id IS NOT NULL;

ALTER TABLE public.direct_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Direct request participants can read" ON public.direct_requests;
CREATE POLICY "Direct request participants can read"
  ON public.direct_requests FOR SELECT
  TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Writes are RPC-only so a client cannot forge acceptance or token state.
REVOKE INSERT, UPDATE, DELETE ON public.direct_requests FROM anon, authenticated;
GRANT SELECT ON public.direct_requests TO authenticated;
GRANT ALL ON public.direct_requests TO service_role;

CREATE OR REPLACE FUNCTION public._expire_direct_requests(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  UPDATE public.direct_requests
  SET status = 'expired', responded_at = COALESCE(responded_at, now())
  WHERE status = 'pending'
    AND expires_at <= now()
    AND (sender_id = p_user_id OR receiver_id = p_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_get_direct_request_tokens()
RETURNS TABLE(
  total_tokens integer,
  reserved_tokens integer,
  available_tokens integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_total integer := 0;
  v_reserved integer := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  PERFORM public._expire_direct_requests(v_uid);

  SELECT COALESCE(sum(COALESCE(t.remaining_activations, 0)), 0)::integer
    INTO v_total
  FROM public.tokens t
  WHERE t.user_id = v_uid;

  SELECT count(*)::integer
    INTO v_reserved
  FROM public.direct_requests dr
  WHERE dr.sender_id = v_uid
    AND dr.status = 'pending'
    AND dr.expires_at > now();

  RETURN QUERY SELECT v_total, v_reserved, GREATEST(v_total - v_reserved, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_create_direct_request(
  p_receiver_id uuid,
  p_listing_id uuid DEFAULT NULL,
  p_message text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_total integer := 0;
  v_reserved integer := 0;
  v_request public.direct_requests;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_receiver_id IS NULL OR p_receiver_id = v_uid THEN
    RAISE EXCEPTION 'Invalid Direct Request receiver';
  END IF;

  IF p_listing_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = p_listing_id AND l.owner_id = p_receiver_id
  ) THEN
    RAISE EXCEPTION 'Listing does not belong to receiver';
  END IF;

  PERFORM public._expire_direct_requests(v_uid);

  -- Reuse an existing live request instead of reserving twice for double taps.
  SELECT * INTO v_request
  FROM public.direct_requests dr
  WHERE dr.sender_id = v_uid
    AND dr.receiver_id = p_receiver_id
    AND dr.listing_id IS NOT DISTINCT FROM p_listing_id
    AND dr.status = 'pending'
    AND dr.expires_at > now()
  ORDER BY dr.created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'id', v_request.id,
      'status', v_request.status,
      'expires_at', v_request.expires_at,
      'reserved', true
    );
  END IF;

  SELECT COALESCE(sum(COALESCE(t.remaining_activations, 0)), 0)::integer
    INTO v_total
  FROM public.tokens t
  WHERE t.user_id = v_uid;

  SELECT count(*)::integer
    INTO v_reserved
  FROM public.direct_requests dr
  WHERE dr.sender_id = v_uid
    AND dr.status = 'pending'
    AND dr.expires_at > now();

  IF v_total - v_reserved < 1 THEN
    RAISE EXCEPTION 'No Direct Request tokens available';
  END IF;

  INSERT INTO public.direct_requests (
    sender_id, receiver_id, listing_id, message
  ) VALUES (
    v_uid, p_receiver_id, p_listing_id, left(trim(COALESCE(p_message, '')), 1000)
  )
  RETURNING * INTO v_request;

  BEGIN
    PERFORM public.create_notification_for_user(
      p_receiver_id,
      'direct_request',
      'Direct Request',
      CASE
        WHEN p_listing_id IS NULL THEN 'Someone sent you a priority request.'
        ELSE 'Someone sent a priority request for your listing.'
      END,
      v_uid,
      jsonb_build_object(
        'direct_request_id', v_request.id,
        'listing_id', p_listing_id,
        'status', 'pending'
      )
    );
  EXCEPTION WHEN OTHERS THEN
    -- Notification delivery is best-effort; the request remains authoritative.
    NULL;
  END;

  RETURN jsonb_build_object(
    'id', v_request.id,
    'status', v_request.status,
    'expires_at', v_request.expires_at,
    'reserved', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_cancel_direct_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_request public.direct_requests;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_request
  FROM public.direct_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_request.sender_id <> v_uid THEN
    RAISE EXCEPTION 'Direct Request not found';
  END IF;
  IF v_request.status <> 'pending' THEN
    RETURN jsonb_build_object('id', v_request.id, 'status', v_request.status);
  END IF;

  UPDATE public.direct_requests
  SET status = 'cancelled', responded_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('id', p_request_id, 'status', 'cancelled', 'token_returned', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_respond_direct_request(
  p_request_id uuid,
  p_accept boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_request public.direct_requests;
  v_token_id uuid;
  v_conversation_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_request
  FROM public.direct_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_request.receiver_id <> v_uid THEN
    RAISE EXCEPTION 'Direct Request not found';
  END IF;

  IF v_request.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'id', v_request.id,
      'status', v_request.status,
      'conversation_id', v_request.conversation_id
    );
  END IF;

  IF v_request.expires_at <= now() THEN
    UPDATE public.direct_requests
    SET status = 'expired', responded_at = now()
    WHERE id = p_request_id;
    RETURN jsonb_build_object('id', p_request_id, 'status', 'expired', 'token_returned', true);
  END IF;

  IF NOT p_accept THEN
    UPDATE public.direct_requests
    SET status = 'declined', responded_at = now()
    WHERE id = p_request_id;
    RETURN jsonb_build_object('id', p_request_id, 'status', 'declined', 'token_returned', true);
  END IF;

  -- Consume exactly one of the sender's real token activations only now.
  SELECT t.id INTO v_token_id
  FROM public.tokens t
  WHERE t.user_id = v_request.sender_id
    AND COALESCE(t.remaining_activations, 0) > 0
  ORDER BY t.created_at ASC NULLS LAST, t.id
  LIMIT 1
  FOR UPDATE;

  IF v_token_id IS NULL THEN
    RAISE EXCEPTION 'Sender no longer has an available Direct Request token';
  END IF;

  UPDATE public.tokens
  SET remaining_activations = remaining_activations - 1
  WHERE id = v_token_id
    AND remaining_activations > 0;

  -- Reuse an existing active conversation between these users for this listing.
  SELECT c.id INTO v_conversation_id
  FROM public.conversations c
  WHERE c.client_id = v_request.sender_id
    AND c.owner_id = v_request.receiver_id
    AND c.listing_id IS NOT DISTINCT FROM v_request.listing_id
    AND COALESCE(c.status, 'active') <> 'archived'
  ORDER BY c.created_at DESC
  LIMIT 1;

  IF v_conversation_id IS NULL THEN
    INSERT INTO public.conversations (
      client_id, owner_id, listing_id, status, last_message_at
    ) VALUES (
      v_request.sender_id,
      v_request.receiver_id,
      v_request.listing_id,
      'active',
      now()
    ) RETURNING id INTO v_conversation_id;
  END IF;

  IF trim(COALESCE(v_request.message, '')) <> '' THEN
    INSERT INTO public.conversation_messages (
      conversation_id, sender_id, message_text, content, message_type
    ) VALUES (
      v_conversation_id,
      v_request.sender_id,
      v_request.message,
      v_request.message,
      'text'
    );
    UPDATE public.conversations
    SET last_message_at = now()
    WHERE id = v_conversation_id;
  END IF;

  UPDATE public.direct_requests
  SET status = 'accepted',
      token_consumed = true,
      conversation_id = v_conversation_id,
      responded_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'id', p_request_id,
    'status', 'accepted',
    'token_consumed', true,
    'conversation_id', v_conversation_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public._expire_direct_requests(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._expire_direct_requests(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_get_direct_request_tokens() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_create_direct_request(uuid, uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_cancel_direct_request(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_respond_direct_request(uuid, boolean) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.rpc_get_direct_request_tokens() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_create_direct_request(uuid, uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_cancel_direct_request(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_respond_direct_request(uuid, boolean) TO authenticated, service_role;
