-- Prevent two simultaneous Direct Requests from reserving the same last token.
CREATE OR REPLACE FUNCTION public.rpc_create_direct_request(
  p_receiver_id uuid,
  p_listing_id uuid DEFAULT NULL,
  p_message text DEFAULT ''
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

  PERFORM pg_advisory_xact_lock(hashtextextended(v_uid::text,0));
  PERFORM public._expire_direct_requests(v_uid);

  SELECT * INTO v_request
  FROM public.direct_requests dr
  WHERE dr.sender_id=v_uid
    AND dr.receiver_id=p_receiver_id
    AND dr.listing_id IS NOT DISTINCT FROM p_listing_id
    AND dr.status='pending'
    AND dr.expires_at>now()
  ORDER BY dr.created_at DESC
  LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'id',v_request.id,'status',v_request.status,
      'expires_at',v_request.expires_at,'reserved',true
    );
  END IF;

  SELECT COALESCE(sum(COALESCE(t.remaining_activations,0)),0)::integer
    INTO v_total
  FROM public.tokens t
  WHERE t.user_id=v_uid;

  SELECT count(*)::integer INTO v_reserved
  FROM public.direct_requests dr
  WHERE dr.sender_id=v_uid
    AND dr.status='pending'
    AND dr.expires_at>now();

  IF v_total-v_reserved<1 THEN
    RAISE EXCEPTION 'No Direct Request tokens available';
  END IF;

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
    jsonb_build_object(
      'direct_request_id',v_request.id,'listing_id',p_listing_id,'status','pending'
    ),false
  );

  RETURN jsonb_build_object(
    'id',v_request.id,'status',v_request.status,
    'expires_at',v_request.expires_at,'reserved',true
  );
END;
$$;
