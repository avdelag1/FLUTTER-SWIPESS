-- Consent-first Swipess marketplace communication.
-- Interest is free, mutual matches chat for free, and Direct Requests reserve
-- one token that is only consumed after the receiver accepts.

DO $$
BEGIN
  ALTER TYPE public.notification_type ADD VALUE IF NOT EXISTS 'direct_request';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.direct_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES public.listings(id) ON DELETE SET NULL,
  message text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','accepted','declined','cancelled','expired')),
  token_consumed boolean NOT NULL DEFAULT false,
  conversation_id uuid REFERENCES public.conversations(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '48 hours'),
  CHECK (sender_id <> receiver_id)
);

ALTER TABLE public.direct_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Direct request participants can read" ON public.direct_requests;
CREATE POLICY "Direct request participants can read"
ON public.direct_requests FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = sender_id OR (SELECT auth.uid()) = receiver_id);
REVOKE ALL ON TABLE public.direct_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.direct_requests TO authenticated;
GRANT ALL ON TABLE public.direct_requests TO service_role;

CREATE INDEX IF NOT EXISTS idx_direct_requests_sender_pending
  ON public.direct_requests(sender_id, status, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_direct_requests_receiver_pending
  ON public.direct_requests(receiver_id, status, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_direct_requests_listing
  ON public.direct_requests(listing_id) WHERE listing_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public._expire_direct_requests(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog AS $$
BEGIN
  UPDATE public.direct_requests
     SET status='expired', responded_at=COALESCE(responded_at, now())
   WHERE status='pending' AND expires_at<=now()
     AND (sender_id=p_user_id OR receiver_id=p_user_id);
END;
$$;
REVOKE ALL ON FUNCTION public._expire_direct_requests(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._expire_direct_requests(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.rpc_get_direct_request_tokens()
RETURNS TABLE(total_tokens integer, reserved_tokens integer, available_tokens integer)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_total integer := 0;
  v_reserved integer := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE public.direct_requests
     SET status='expired', responded_at=COALESCE(responded_at,now())
   WHERE status='pending' AND expires_at<=now()
     AND (sender_id=v_uid OR receiver_id=v_uid);
  v_total := public.get_user_token_balance(v_uid);
  SELECT count(*)::integer INTO v_reserved
    FROM public.direct_requests
   WHERE sender_id=v_uid AND status='pending' AND expires_at>now();
  RETURN QUERY SELECT v_total, v_reserved, GREATEST(v_total-v_reserved,0);
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_get_direct_request_tokens() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_get_direct_request_tokens() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_create_direct_request(
  p_receiver_id uuid,
  p_listing_id uuid DEFAULT NULL,
  p_message text DEFAULT ''
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_total integer := 0;
  v_reserved integer := 0;
  v_request public.direct_requests;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_receiver_id IS NULL OR p_receiver_id=v_uid THEN
    RAISE EXCEPTION 'Invalid Direct Request receiver';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id=p_receiver_id) THEN
    RAISE EXCEPTION 'Receiver is unavailable';
  END IF;
  IF p_listing_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.listings l
     WHERE l.id=p_listing_id AND l.owner_id=p_receiver_id
       AND COALESCE(l.is_active,true)=true
  ) THEN
    RAISE EXCEPTION 'Listing is unavailable or does not belong to receiver';
  END IF;

  UPDATE public.direct_requests
     SET status='expired', responded_at=COALESCE(responded_at,now())
   WHERE status='pending' AND expires_at<=now()
     AND (sender_id=v_uid OR receiver_id=v_uid);

  SELECT * INTO v_request FROM public.direct_requests
   WHERE sender_id=v_uid AND receiver_id=p_receiver_id
     AND listing_id IS NOT DISTINCT FROM p_listing_id
     AND status='pending' AND expires_at>now()
   ORDER BY created_at DESC LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('id',v_request.id,'status',v_request.status,
      'expires_at',v_request.expires_at,'reserved',true);
  END IF;

  v_total := public.get_user_token_balance(v_uid);
  SELECT count(*)::integer INTO v_reserved FROM public.direct_requests
   WHERE sender_id=v_uid AND status='pending' AND expires_at>now();
  IF v_total-v_reserved<1 THEN RAISE EXCEPTION 'No Direct Request tokens available'; END IF;

  INSERT INTO public.direct_requests(sender_id,receiver_id,listing_id,message)
  VALUES(v_uid,p_receiver_id,p_listing_id,left(trim(COALESCE(p_message,'')),1000))
  RETURNING * INTO v_request;

  INSERT INTO public.notifications(
    user_id,notification_type,title,message,link_url,related_user_id,
    related_property_id,metadata,is_read
  ) VALUES (
    p_receiver_id,'direct_request','⚡ Direct Request',
    CASE WHEN p_listing_id IS NULL
      THEN 'Someone sent you a priority request. Accept to open chat.'
      ELSE 'Someone sent a priority request for your listing. Accept to open chat.' END,
    '/direct-request/'||v_request.id::text,v_uid,p_listing_id,
    jsonb_build_object('direct_request_id',v_request.id,'listing_id',p_listing_id,'status','pending'),false
  );
  RETURN jsonb_build_object('id',v_request.id,'status',v_request.status,
    'expires_at',v_request.expires_at,'reserved',true);
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_create_direct_request(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_direct_request(uuid,uuid,text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_cancel_direct_request(p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog AS $$
DECLARE v_uid uuid:=auth.uid(); v_request public.direct_requests;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_request FROM public.direct_requests WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND OR v_request.sender_id<>v_uid THEN RAISE EXCEPTION 'Direct Request not found'; END IF;
  IF v_request.status<>'pending' THEN
    RETURN jsonb_build_object('id',v_request.id,'status',v_request.status);
  END IF;
  UPDATE public.direct_requests SET status='cancelled',responded_at=now() WHERE id=p_request_id;
  RETURN jsonb_build_object('id',p_request_id,'status','cancelled','token_returned',true);
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_cancel_direct_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_cancel_direct_request(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_accept_listing_interest(p_liker_id uuid,p_listing_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog AS $$
DECLARE v_uid uuid:=auth.uid(); v_match_id uuid; v_conversation_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_liker_id IS NULL OR p_liker_id=v_uid THEN RAISE EXCEPTION 'Invalid member'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.listings WHERE id=p_listing_id AND owner_id=v_uid)
    THEN RAISE EXCEPTION 'Listing not found'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.likes WHERE user_id=p_liker_id
    AND target_id=p_listing_id AND target_type='listing' AND direction='right')
    THEN RAISE EXCEPTION 'This member has not expressed interest in the listing'; END IF;

  INSERT INTO public.matches(client_id,owner_id,listing_id,status,updated_at)
  VALUES(p_liker_id,v_uid,p_listing_id,'active',now())
  ON CONFLICT(client_id,owner_id,listing_id)
  DO UPDATE SET status='active',updated_at=now()
  RETURNING id INTO v_match_id;

  SELECT id INTO v_conversation_id FROM public.conversations
   WHERE client_id=p_liker_id AND owner_id=v_uid
     AND listing_id IS NOT DISTINCT FROM p_listing_id
     AND COALESCE(status,'active')<>'blocked'
   ORDER BY created_at ASC LIMIT 1;
  IF v_conversation_id IS NULL THEN
    INSERT INTO public.conversations(match_id,client_id,owner_id,listing_id,status,free_messaging)
    VALUES(v_match_id,p_liker_id,v_uid,p_listing_id,'active',true)
    RETURNING id INTO v_conversation_id;
  ELSE
    UPDATE public.conversations SET match_id=COALESCE(match_id,v_match_id),
      status='active',free_messaging=true WHERE id=v_conversation_id;
  END IF;

  INSERT INTO public.notifications(user_id,notification_type,title,message,link_url,
    related_user_id,related_property_id,related_match_id,metadata,is_read)
  VALUES(p_liker_id,'new_match','It’s a match','Your interest was accepted. Chat is open for free.',
    '/messages/'||v_conversation_id::text,v_uid,p_listing_id,v_match_id,
    jsonb_build_object('match_id',v_match_id,'conversation_id',v_conversation_id,'free_chat',true),false);
  RETURN jsonb_build_object('status','matched','match_id',v_match_id,
    'conversation_id',v_conversation_id,'free_chat',true);
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_accept_listing_interest(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_accept_listing_interest(uuid,uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_respond_direct_request(p_request_id uuid,p_accept boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog AS $$
DECLARE
  v_uid uuid:=auth.uid(); v_request public.direct_requests;
  v_client_id uuid; v_owner_id uuid; v_match_id uuid; v_conversation_id uuid;
  v_deducted boolean; v_sender_role text; v_receiver_role text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_request FROM public.direct_requests WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND OR v_request.receiver_id<>v_uid THEN RAISE EXCEPTION 'Direct Request not found'; END IF;
  IF v_request.status<>'pending' THEN
    RETURN jsonb_build_object('id',v_request.id,'status',v_request.status,'conversation_id',v_request.conversation_id);
  END IF;
  IF v_request.expires_at<=now() THEN
    UPDATE public.direct_requests SET status='expired',responded_at=now() WHERE id=p_request_id;
    RETURN jsonb_build_object('id',p_request_id,'status','expired','token_returned',true);
  END IF;
  IF NOT p_accept THEN
    UPDATE public.direct_requests SET status='declined',responded_at=now() WHERE id=p_request_id;
    INSERT INTO public.notifications(user_id,notification_type,title,message,related_user_id,
      related_property_id,metadata,is_read)
    VALUES(v_request.sender_id,'direct_request','Direct Request declined',
      'No token was spent. It is available to use again.',v_uid,v_request.listing_id,
      jsonb_build_object('direct_request_id',p_request_id,'status','declined','token_returned',true),false);
    RETURN jsonb_build_object('id',p_request_id,'status','declined','token_returned',true);
  END IF;

  v_deducted:=public._deduct_user_tokens(v_request.sender_id,1);
  IF NOT v_deducted THEN RAISE EXCEPTION 'Sender no longer has an available Direct Request token'; END IF;

  IF v_request.listing_id IS NOT NULL THEN
    v_client_id:=v_request.sender_id; v_owner_id:=v_request.receiver_id;
    INSERT INTO public.matches(client_id,owner_id,listing_id,status,updated_at)
    VALUES(v_client_id,v_owner_id,v_request.listing_id,'active',now())
    ON CONFLICT(client_id,owner_id,listing_id)
    DO UPDATE SET status='active',updated_at=now()
    RETURNING id INTO v_match_id;
  ELSE
    SELECT role::text INTO v_sender_role FROM public.user_roles WHERE user_id=v_request.sender_id LIMIT 1;
    SELECT role::text INTO v_receiver_role FROM public.user_roles WHERE user_id=v_request.receiver_id LIMIT 1;
    IF v_sender_role='owner' AND v_receiver_role<>'owner' THEN
      v_owner_id:=v_request.sender_id; v_client_id:=v_request.receiver_id;
    ELSIF v_receiver_role='owner' THEN
      v_owner_id:=v_request.receiver_id; v_client_id:=v_request.sender_id;
    ELSE
      v_client_id:=LEAST(v_request.sender_id,v_request.receiver_id);
      v_owner_id:=GREATEST(v_request.sender_id,v_request.receiver_id);
    END IF;
  END IF;

  SELECT id INTO v_conversation_id FROM public.conversations
   WHERE ((client_id=v_client_id AND owner_id=v_owner_id)
      OR (client_id=v_owner_id AND owner_id=v_client_id))
     AND listing_id IS NOT DISTINCT FROM v_request.listing_id
     AND COALESCE(status,'active')<>'blocked'
   ORDER BY created_at ASC LIMIT 1;
  IF v_conversation_id IS NULL THEN
    INSERT INTO public.conversations(match_id,client_id,owner_id,listing_id,status,last_message_at,free_messaging)
    VALUES(v_match_id,v_client_id,v_owner_id,v_request.listing_id,'active',now(),true)
    RETURNING id INTO v_conversation_id;
  ELSE
    UPDATE public.conversations SET match_id=COALESCE(match_id,v_match_id),free_messaging=true,status='active'
    WHERE id=v_conversation_id;
  END IF;

  IF trim(COALESCE(v_request.message,''))<>'' THEN
    INSERT INTO public.conversation_messages(conversation_id,sender_id,receiver_id,message_text,content,message_type)
    VALUES(v_conversation_id,v_request.sender_id,v_request.receiver_id,v_request.message,v_request.message,'text');
    UPDATE public.conversations SET last_message_at=now(),last_message=v_request.message,
      last_message_sender_id=v_request.sender_id WHERE id=v_conversation_id;
  END IF;

  UPDATE public.direct_requests SET status='accepted',token_consumed=true,
    conversation_id=v_conversation_id,responded_at=now() WHERE id=p_request_id;
  INSERT INTO public.notifications(user_id,notification_type,title,message,link_url,
    related_user_id,related_property_id,metadata,is_read)
  VALUES(v_request.sender_id,'direct_request','Direct Request accepted','Your request was accepted. Chat is now open.',
    '/messages/'||v_conversation_id::text,v_uid,v_request.listing_id,
    jsonb_build_object('direct_request_id',p_request_id,'status','accepted','conversation_id',v_conversation_id,'token_consumed',true),false);
  RETURN jsonb_build_object('id',p_request_id,'status','accepted','token_consumed',true,'conversation_id',v_conversation_id);
END;
$$;
REVOKE ALL ON FUNCTION public.rpc_respond_direct_request(uuid,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_respond_direct_request(uuid,boolean) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.start_conversation_with_message(
  p_other_user_id uuid,p_initial_message text,p_listing_id uuid DEFAULT NULL
)
RETURNS TABLE(conversation_id uuid,message_id uuid,created boolean)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog AS $$
DECLARE
  v_uid uuid:=auth.uid(); v_match public.matches; v_conversation_id uuid;
  v_message_id uuid; v_created boolean:=false;
  v_msg text:=COALESCE(NULLIF(btrim(p_initial_message),''),'Hi!');
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_other_user_id IS NULL OR p_other_user_id=v_uid THEN RAISE EXCEPTION 'Invalid recipient'; END IF;
  SELECT id INTO v_conversation_id FROM public.conversations
   WHERE ((client_id=v_uid AND owner_id=p_other_user_id) OR (client_id=p_other_user_id AND owner_id=v_uid))
     AND (p_listing_id IS NULL OR listing_id IS NOT DISTINCT FROM p_listing_id)
     AND COALESCE(status,'active')<>'blocked' ORDER BY created_at ASC LIMIT 1;
  IF v_conversation_id IS NULL THEN
    SELECT * INTO v_match FROM public.matches
     WHERE ((client_id=v_uid AND owner_id=p_other_user_id) OR (client_id=p_other_user_id AND owner_id=v_uid))
       AND (p_listing_id IS NULL OR listing_id IS NOT DISTINCT FROM p_listing_id)
       AND COALESCE(status,'active')='active' ORDER BY created_at DESC LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'No mutual match yet. Send a Direct Request if you want priority.'; END IF;
    INSERT INTO public.conversations(match_id,client_id,owner_id,listing_id,status,free_messaging)
    VALUES(v_match.id,v_match.client_id,v_match.owner_id,COALESCE(p_listing_id,v_match.listing_id),'active',true)
    RETURNING id INTO v_conversation_id;
    v_created:=true;
  END IF;
  INSERT INTO public.conversation_messages(conversation_id,sender_id,receiver_id,message_text,content,message_type)
  VALUES(v_conversation_id,v_uid,p_other_user_id,v_msg,v_msg,'text') RETURNING id INTO v_message_id;
  UPDATE public.conversations SET last_message_at=now(),last_message=v_msg,
    last_message_sender_id=v_uid,free_messaging=true WHERE id=v_conversation_id;
  RETURN QUERY SELECT v_conversation_id,v_message_id,v_created;
END;
$$;
REVOKE ALL ON FUNCTION public.start_conversation_with_message(uuid,text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_conversation_with_message(uuid,text,uuid) TO authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.subscription_direct_request_grants (
  transaction_key text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id text NOT NULL,
  amount integer NOT NULL CHECK(amount>0),
  token_row_id uuid REFERENCES public.tokens(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.subscription_direct_request_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.subscription_direct_request_grants FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.subscription_direct_request_grants TO service_role;

CREATE OR REPLACE FUNCTION public.service_grant_subscription_direct_requests(
  p_user_id uuid,p_product_id text,p_transaction_key text,p_expires_at timestamptz DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog AS $$
DECLARE v_amount integer; v_token_id uuid; v_existing public.subscription_direct_request_grants;
BEGIN
  IF p_user_id IS NULL OR NULLIF(trim(p_transaction_key),'') IS NULL THEN RAISE EXCEPTION 'Invalid subscription grant'; END IF;
  v_amount:=CASE p_product_id
    WHEN 'Swipess.plus.monthly.v3' THEN 6 WHEN 'swipess.plus.monthly.v2' THEN 6
    WHEN 'Swipess.plus.semestral.v3' THEN 12 WHEN 'swipess.plus.semestral.v2' THEN 12
    WHEN 'Swipess.plus.annual.v3' THEN 30 WHEN 'swipess.plus.annual.v2' THEN 30 ELSE NULL END;
  IF v_amount IS NULL THEN RAISE EXCEPTION 'Unsupported subscription product'; END IF;
  SELECT * INTO v_existing FROM public.subscription_direct_request_grants WHERE transaction_key=p_transaction_key;
  IF FOUND THEN
    IF v_existing.user_id<>p_user_id OR v_existing.product_id<>p_product_id THEN RAISE EXCEPTION 'Subscription transaction already belongs to another entitlement'; END IF;
    RETURN jsonb_build_object('granted',false,'already_granted',true,'amount',v_existing.amount,'token_row_id',v_existing.token_row_id);
  END IF;
  INSERT INTO public.tokens(user_id,token_type,amount,total_activations,remaining_activations,used_activations,activation_type,source,notes,expires_at)
  VALUES(p_user_id,'messages',v_amount,v_amount,v_amount,0,'subscription','premium_included','Premium Direct Requests: '||p_product_id,p_expires_at)
  RETURNING id INTO v_token_id;
  INSERT INTO public.subscription_direct_request_grants(transaction_key,user_id,product_id,amount,token_row_id)
  VALUES(p_transaction_key,p_user_id,p_product_id,v_amount,v_token_id);
  RETURN jsonb_build_object('granted',true,'already_granted',false,'amount',v_amount,'token_row_id',v_token_id);
END;
$$;
REVOKE ALL ON FUNCTION public.service_grant_subscription_direct_requests(uuid,text,text,timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.service_grant_subscription_direct_requests(uuid,text,text,timestamptz) TO service_role;

UPDATE public.subscription_packages SET
  message_activations=CASE name WHEN 'Basic Client' THEN 6 WHEN 'Premium Client' THEN 12 WHEN 'Unlimited Client' THEN 30 ELSE message_activations END,
  description=CASE name
    WHEN 'Basic Client' THEN 'Here Now — speed, AI and 6 included Direct Requests'
    WHEN 'Premium Client' THEN 'Live Local — more reach, AI and 12 included Direct Requests'
    WHEN 'Unlimited Client' THEN 'Pro — maximum scale, AI and 30 included Direct Requests'
    ELSE description END
WHERE name IN ('Basic Client','Premium Client','Unlimited Client');
