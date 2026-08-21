-- Safe rollout bridge for the consent-first Direct Request marketplace.
--
-- New builds use start_mutual_conversation_v2, which only opens/sends chat
-- after a mutual/owner-accepted match. The legacy RPC name intentionally keeps
-- the pre-v2 token/unlimited behavior so already-installed App Store/TestFlight
-- builds do not break during the rollout window. Remove the legacy behavior in
-- a later forced-update release after old clients are retired.

CREATE OR REPLACE FUNCTION public.start_mutual_conversation_v2(
  p_other_user_id uuid,
  p_initial_message text,
  p_listing_id uuid DEFAULT NULL::uuid
)
RETURNS TABLE(conversation_id uuid, message_id uuid, created boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_conversation_id uuid;
  v_message_id uuid;
  v_created boolean := false;
  v_msg text := COALESCE(NULLIF(btrim(p_initial_message), ''), 'Hi!');
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_other_user_id IS NULL OR p_other_user_id = v_uid THEN
    RAISE EXCEPTION 'Invalid recipient';
  END IF;

  SELECT c.id INTO v_conversation_id
    FROM public.conversations c
   WHERE ((c.client_id = v_uid AND c.owner_id = p_other_user_id)
       OR (c.client_id = p_other_user_id AND c.owner_id = v_uid))
     AND (p_listing_id IS NULL OR c.listing_id IS NOT DISTINCT FROM p_listing_id)
     AND COALESCE(c.status, 'active') <> 'blocked'
   ORDER BY c.created_at ASC
   LIMIT 1;

  IF v_conversation_id IS NULL THEN
    SELECT m.* INTO v_match
      FROM public.matches m
     WHERE ((m.client_id = v_uid AND m.owner_id = p_other_user_id)
         OR (m.client_id = p_other_user_id AND m.owner_id = v_uid))
       AND (p_listing_id IS NULL OR m.listing_id IS NOT DISTINCT FROM p_listing_id)
       AND COALESCE(m.status, 'active') = 'active'
     ORDER BY m.created_at DESC
     LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'No mutual match yet. Send a Direct Request if you want priority.';
    END IF;

    INSERT INTO public.conversations(
      match_id, client_id, owner_id, listing_id, status, free_messaging
    ) VALUES (
      v_match.id,
      v_match.client_id,
      v_match.owner_id,
      COALESCE(p_listing_id, v_match.listing_id),
      'active',
      true
    )
    RETURNING id INTO v_conversation_id;
    v_created := true;
  END IF;

  INSERT INTO public.conversation_messages(
    conversation_id, sender_id, receiver_id, message_text, content, message_type
  ) VALUES (
    v_conversation_id, v_uid, p_other_user_id, v_msg, v_msg, 'text'
  )
  RETURNING id INTO v_message_id;

  UPDATE public.conversations
     SET last_message_at = now(),
         last_message = v_msg,
         last_message_sender_id = v_uid,
         free_messaging = true
   WHERE id = v_conversation_id;

  RETURN QUERY SELECT v_conversation_id, v_message_id, v_created;
END;
$$;

REVOKE ALL ON FUNCTION public.start_mutual_conversation_v2(uuid, text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_mutual_conversation_v2(uuid, text, uuid)
  TO authenticated, service_role;

-- Compatibility-only legacy entry point.
-- Existing clients expect one spendable message token to create a new chat,
-- unless the account has unlimited messaging. Continuing an existing chat is
-- always free. New clients MUST NOT call this function.
--
-- Active Direct Requests are real reservations: legacy clients may only spend
-- from the unreserved portion of the balance. The same per-user advisory lock
-- used by Direct Request creation prevents a race between reserving and legacy
-- spending during the rollout window.
CREATE OR REPLACE FUNCTION public.start_conversation_with_message(
  p_other_user_id uuid,
  p_initial_message text,
  p_listing_id uuid DEFAULT NULL::uuid
)
RETURNS TABLE(conversation_id uuid, message_id uuid, created boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_conversation_id uuid;
  v_message_id uuid;
  v_created boolean := false;
  v_unlimited boolean := false;
  v_total integer := 0;
  v_reserved integer := 0;
  v_msg text := COALESCE(NULLIF(btrim(p_initial_message), ''), 'Hi!');
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_other_user_id IS NULL OR p_other_user_id = v_uid THEN
    RAISE EXCEPTION 'Invalid recipient';
  END IF;

  SELECT c.id INTO v_conversation_id
    FROM public.conversations c
   WHERE ((c.client_id = v_uid AND c.owner_id = p_other_user_id)
       OR (c.client_id = p_other_user_id AND c.owner_id = v_uid))
     AND (p_listing_id IS NULL OR c.listing_id IS NOT DISTINCT FROM p_listing_id)
     AND COALESCE(c.status, 'active') <> 'blocked'
   ORDER BY c.created_at ASC
   LIMIT 1;

  IF v_conversation_id IS NULL THEN
    v_unlimited := COALESCE(public.user_has_unlimited_messaging(v_uid), false);

    IF NOT v_unlimited THEN
      PERFORM pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));
      PERFORM public._expire_direct_requests(v_uid);

      SELECT COALESCE(sum(COALESCE(t.remaining_activations, 0)), 0)::integer
        INTO v_total
      FROM public.tokens t
      WHERE t.user_id = v_uid
        AND COALESCE(t.remaining_activations, 0) > 0
        AND (t.expires_at IS NULL OR t.expires_at > now());

      SELECT count(*)::integer
        INTO v_reserved
      FROM public.direct_requests dr
      WHERE dr.sender_id = v_uid
        AND dr.status = 'pending'
        AND dr.expires_at > now();

      IF v_total - v_reserved < 1 THEN
        RAISE EXCEPTION 'No message tokens available';
      END IF;

      IF NOT COALESCE(public._deduct_user_tokens(v_uid, 1), false) THEN
        RAISE EXCEPTION 'No message tokens available';
      END IF;
    END IF;

    INSERT INTO public.conversations(
      client_id, owner_id, listing_id, status, free_messaging
    ) VALUES (
      v_uid,
      p_other_user_id,
      p_listing_id,
      'active',
      v_unlimited
    )
    RETURNING id INTO v_conversation_id;
    v_created := true;
  END IF;

  INSERT INTO public.conversation_messages(
    conversation_id, sender_id, receiver_id, message_text, content, message_type
  ) VALUES (
    v_conversation_id, v_uid, p_other_user_id, v_msg, v_msg, 'text'
  )
  RETURNING id INTO v_message_id;

  UPDATE public.conversations
     SET last_message_at = now(),
         last_message = v_msg,
         last_message_sender_id = v_uid
   WHERE id = v_conversation_id;

  RETURN QUERY SELECT v_conversation_id, v_message_id, v_created;
END;
$$;

REVOKE ALL ON FUNCTION public.start_conversation_with_message(uuid, text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_conversation_with_message(uuid, text, uuid)
  TO authenticated, service_role;
