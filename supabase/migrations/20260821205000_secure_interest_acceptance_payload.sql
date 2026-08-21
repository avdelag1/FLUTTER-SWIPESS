-- Return the interested user from the owner-authorized acceptance RPC so the
-- Flutter UI never needs direct SELECT access to another user's raw likes row.
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
  WHERE id=p_like_id
    AND direction='right'
    AND target_type='listing';
  IF NOT FOUND THEN RAISE EXCEPTION 'Interest not found'; END IF;

  SELECT owner_id INTO v_owner FROM public.listings WHERE id=v_like.target_id;
  IF v_owner IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Only the listing owner can accept this interest';
  END IF;

  SELECT id INTO v_match_id
  FROM public.matches
  WHERE client_id=v_like.user_id
    AND owner_id=v_uid
    AND listing_id=v_like.target_id
    AND COALESCE(status,'active')='active'
  ORDER BY created_at DESC LIMIT 1;

  IF v_match_id IS NULL THEN
    INSERT INTO public.matches(client_id,owner_id,listing_id,status)
    VALUES(v_like.user_id,v_uid,v_like.target_id,'active')
    RETURNING id INTO v_match_id;
  END IF;

  SELECT id INTO v_conversation_id
  FROM public.conversations
  WHERE client_id=v_like.user_id
    AND owner_id=v_uid
    AND listing_id=v_like.target_id
    AND COALESCE(status,'active')<>'archived'
  ORDER BY created_at DESC LIMIT 1;

  IF v_conversation_id IS NULL THEN
    INSERT INTO public.conversations(
      match_id,client_id,owner_id,listing_id,status,last_message_at,free_messaging
    ) VALUES (
      v_match_id,v_like.user_id,v_uid,v_like.target_id,'active',now(),true
    ) RETURNING id INTO v_conversation_id;
  ELSE
    UPDATE public.conversations
    SET match_id=COALESCE(match_id,v_match_id),
        free_messaging=true,
        status='active'
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
    'status','matched',
    'match_id',v_match_id,
    'conversation_id',v_conversation_id,
    'interested_user_id',v_like.user_id,
    'listing_id',v_like.target_id,
    'free_messaging',true
  );
END;
$$;
