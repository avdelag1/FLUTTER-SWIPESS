-- Complete the marketplace loop:
-- right-swipe interest is free and notifies the listing owner;
-- owner acceptance creates a free match/conversation;
-- Direct Requests notify the receiver and consume a token only on acceptance.
-- Events and Legal are intentionally untouched.

DO $$
BEGIN
  ALTER TYPE public.notification_type ADD VALUE IF NOT EXISTS 'direct_request';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.notify_listing_interest()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public,pg_catalog
AS $$
DECLARE
  v_owner uuid;
  v_title text;
BEGIN
  IF NEW.target_type <> 'listing' OR NEW.direction <> 'right' THEN RETURN NEW; END IF;
  SELECT l.owner_id, COALESCE(NULLIF(l.title,''),'your listing')
    INTO v_owner,v_title
  FROM public.listings l WHERE l.id=NEW.target_id;
  IF v_owner IS NULL OR v_owner=NEW.user_id THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND OLD.direction='right' THEN RETURN NEW; END IF;

  INSERT INTO public.notifications(
    user_id,notification_type,title,message,link_url,related_user_id,
    related_property_id,metadata,is_read
  ) VALUES (
    v_owner,'new_like','Someone is interested',
    'Someone is interested in '||v_title||'. Match to chat for free.',
    '/interest/'||NEW.id::text,NEW.user_id,NEW.target_id,
    jsonb_build_object('like_id',NEW.id,'listing_id',NEW.target_id,'interest',true),false
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_listing_interest ON public.likes;
CREATE TRIGGER trg_notify_listing_interest
AFTER INSERT OR UPDATE OF direction ON public.likes
FOR EACH ROW EXECUTE FUNCTION public.notify_listing_interest();

CREATE OR REPLACE FUNCTION public.rpc_accept_interest(p_like_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public,pg_catalog
AS $$
DECLARE
  v_uid uuid:=auth.uid();
  v_like public.likes;
  v_owner uuid;
  v_match_id uuid;
  v_conversation_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_like
  FROM public.likes
  WHERE id=p_like_id AND direction='right' AND target_type='listing';
  IF NOT FOUND THEN RAISE EXCEPTION 'Interest not found'; END IF;

  SELECT owner_id INTO v_owner FROM public.listings WHERE id=v_like.target_id;
  IF v_owner IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Only the listing owner can accept this interest';
  END IF;

  SELECT id INTO v_match_id
  FROM public.matches
  WHERE client_id=v_like.user_id AND owner_id=v_uid
    AND listing_id=v_like.target_id AND COALESCE(status,'active')='active'
  ORDER BY created_at DESC LIMIT 1;
  IF v_match_id IS NULL THEN
    INSERT INTO public.matches(client_id,owner_id,listing_id,status)
    VALUES(v_like.user_id,v_uid,v_like.target_id,'active')
    RETURNING id INTO v_match_id;
  END IF;

  SELECT id INTO v_conversation_id
  FROM public.conversations
  WHERE client_id=v_like.user_id AND owner_id=v_uid
    AND listing_id=v_like.target_id AND COALESCE(status,'active')<>'archived'
  ORDER BY created_at DESC LIMIT 1;
  IF v_conversation_id IS NULL THEN
    INSERT INTO public.conversations(
      match_id,client_id,owner_id,listing_id,status,last_message_at,free_messaging
    ) VALUES (
      v_match_id,v_like.user_id,v_uid,v_like.target_id,'active',now(),true
    ) RETURNING id INTO v_conversation_id;
  ELSE
    UPDATE public.conversations
    SET match_id=COALESCE(match_id,v_match_id),free_messaging=true,status='active'
    WHERE id=v_conversation_id;
  END IF;

  INSERT INTO public.notifications(
    user_id,notification_type,title,message,link_url,related_user_id,
    related_property_id,related_match_id,metadata,is_read
  ) VALUES (
    v_like.user_id,'new_match','It’s a Match',
    'Your interest was accepted. You can chat for free.',
    '/messages/'||v_conversation_id::text,v_uid,v_like.target_id,v_match_id,
    jsonb_build_object('conversation_id',v_conversation_id,'free_chat',true),false
  );

  RETURN jsonb_build_object(
    'status','matched','match_id',v_match_id,
    'conversation_id',v_conversation_id,'free_messaging',true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_create_direct_request(
  p_receiver_id uuid,p_listing_id uuid DEFAULT NULL,p_message text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public,pg_catalog
AS $$
DECLARE
  v_uid uuid:=auth.uid();
  v_total integer:=0;
  v_reserved integer:=0;
  v_request public.direct_requests;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_receiver_id IS NULL OR p_receiver_id=v_uid THEN
    RAISE EXCEPTION 'Invalid Direct Request receiver';
  END IF;
  IF p_listing_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id=p_listing_id AND l.owner_id=p_receiver_id
  ) THEN
    RAISE EXCEPTION 'Listing does not belong to receiver';
  END IF;

  PERFORM public._expire_direct_requests(v_uid);
  SELECT * INTO v_request
  FROM public.direct_requests dr
  WHERE dr.sender_id=v_uid AND dr.receiver_id=p_receiver_id
    AND dr.listing_id IS NOT DISTINCT FROM p_listing_id
    AND dr.status='pending' AND dr.expires_at>now()
  ORDER BY dr.created_at DESC LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'id',v_request.id,'status',v_request.status,
      'expires_at',v_request.expires_at,'reserved',true
    );
  END IF;

  SELECT COALESCE(sum(COALESCE(t.remaining_activations,0)),0)::integer
    INTO v_total FROM public.tokens t WHERE t.user_id=v_uid;
  SELECT count(*)::integer INTO v_reserved
  FROM public.direct_requests dr
  WHERE dr.sender_id=v_uid AND dr.status='pending' AND dr.expires_at>now();
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

  RETURN jsonb_build_object(
    'id',v_request.id,'status',v_request.status,
    'expires_at',v_request.expires_at,'reserved',true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_respond_direct_request(
  p_request_id uuid,p_accept boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public,pg_catalog
AS $$
DECLARE
  v_uid uuid:=auth.uid();
  v_request public.direct_requests;
  v_token_id uuid;
  v_conversation_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_request FROM public.direct_requests
  WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND OR v_request.receiver_id<>v_uid THEN
    RAISE EXCEPTION 'Direct Request not found';
  END IF;
  IF v_request.status<>'pending' THEN
    RETURN jsonb_build_object(
      'id',v_request.id,'status',v_request.status,
      'conversation_id',v_request.conversation_id
    );
  END IF;
  IF v_request.expires_at<=now() THEN
    UPDATE public.direct_requests SET status='expired',responded_at=now()
    WHERE id=p_request_id;
    RETURN jsonb_build_object('id',p_request_id,'status','expired','token_returned',true);
  END IF;
  IF NOT p_accept THEN
    UPDATE public.direct_requests SET status='declined',responded_at=now()
    WHERE id=p_request_id;
    INSERT INTO public.notifications(
      user_id,notification_type,title,message,related_user_id,
      related_property_id,metadata,is_read
    ) VALUES (
      v_request.sender_id,'direct_request','Direct Request declined',
      'Your token was returned automatically.',v_uid,v_request.listing_id,
      jsonb_build_object('direct_request_id',p_request_id,'status','declined','token_returned',true),false
    );
    RETURN jsonb_build_object('id',p_request_id,'status','declined','token_returned',true);
  END IF;

  SELECT t.id INTO v_token_id
  FROM public.tokens t
  WHERE t.user_id=v_request.sender_id AND COALESCE(t.remaining_activations,0)>0
  ORDER BY t.created_at ASC NULLS LAST,t.id LIMIT 1 FOR UPDATE;
  IF v_token_id IS NULL THEN
    RAISE EXCEPTION 'Sender no longer has an available Direct Request token';
  END IF;
  UPDATE public.tokens
  SET remaining_activations=remaining_activations-1,
      used_activations=COALESCE(used_activations,0)+1,
      updated_at=now()
  WHERE id=v_token_id AND remaining_activations>0;

  SELECT c.id INTO v_conversation_id
  FROM public.conversations c
  WHERE c.client_id=v_request.sender_id AND c.owner_id=v_request.receiver_id
    AND c.listing_id IS NOT DISTINCT FROM v_request.listing_id
    AND COALESCE(c.status,'active')<>'archived'
  ORDER BY c.created_at DESC LIMIT 1;
  IF v_conversation_id IS NULL THEN
    INSERT INTO public.conversations(
      client_id,owner_id,listing_id,status,last_message_at,free_messaging
    ) VALUES (
      v_request.sender_id,v_request.receiver_id,v_request.listing_id,
      'active',now(),true
    ) RETURNING id INTO v_conversation_id;
  ELSE
    UPDATE public.conversations SET free_messaging=true,status='active'
    WHERE id=v_conversation_id;
  END IF;

  IF trim(COALESCE(v_request.message,''))<>'' THEN
    INSERT INTO public.conversation_messages(
      conversation_id,sender_id,receiver_id,message_text,content,message_type
    ) VALUES (
      v_conversation_id,v_request.sender_id,v_request.receiver_id,
      v_request.message,v_request.message,'text'
    );
    UPDATE public.conversations
    SET last_message_at=now(),last_message=v_request.message,
        last_message_sender_id=v_request.sender_id
    WHERE id=v_conversation_id;
  END IF;

  UPDATE public.direct_requests
  SET status='accepted',token_consumed=true,
      conversation_id=v_conversation_id,responded_at=now()
  WHERE id=p_request_id;

  INSERT INTO public.notifications(
    user_id,notification_type,title,message,link_url,related_user_id,
    related_property_id,metadata,is_read
  ) VALUES (
    v_request.sender_id,'direct_request','Direct Request accepted',
    'Your request was accepted. Chat is now open.',
    '/messages/'||v_conversation_id::text,v_uid,v_request.listing_id,
    jsonb_build_object(
      'direct_request_id',p_request_id,'status','accepted',
      'conversation_id',v_conversation_id,'token_consumed',true
    ),false
  );

  RETURN jsonb_build_object(
    'id',p_request_id,'status','accepted','token_consumed',true,
    'conversation_id',v_conversation_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_accept_interest(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.rpc_accept_interest(uuid) TO authenticated,service_role;
