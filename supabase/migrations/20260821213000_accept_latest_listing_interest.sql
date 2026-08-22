-- Compatibility bridge for the existing Interested Clients UI. Tapping reply on
-- somebody who liked one of your listings is an explicit owner acceptance and
-- therefore creates a free match before chat opens.
CREATE OR REPLACE FUNCTION public.rpc_accept_latest_listing_interest(p_liker_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_listing_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_liker_id IS NULL OR p_liker_id = v_uid THEN RAISE EXCEPTION 'Invalid member'; END IF;

  SELECT li.target_id INTO v_listing_id
  FROM public.likes li
  JOIN public.listings l ON l.id = li.target_id
  WHERE li.user_id = p_liker_id
    AND li.target_type = 'listing'
    AND li.direction = 'right'
    AND l.owner_id = v_uid
  ORDER BY li.created_at DESC
  LIMIT 1;

  IF v_listing_id IS NULL THEN
    RAISE EXCEPTION 'No listing interest found for this member';
  END IF;

  RETURN public.rpc_accept_listing_interest(p_liker_id, v_listing_id);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_accept_latest_listing_interest(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_accept_latest_listing_interest(uuid) TO authenticated;
