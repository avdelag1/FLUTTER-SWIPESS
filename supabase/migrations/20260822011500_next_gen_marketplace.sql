-- Swipess next-gen marketplace
-- IMPORTANT: demand stays in the existing canonical listings request engine
-- (listing_type=request, mode=seek). We do NOT create a second needs table.
-- This makes Seekers/Buyers/Renters and the new "I Need..." flow one system.

ALTER TABLE public.direct_requests
  ADD COLUMN IF NOT EXISTS request_context jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS request_context jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS listings_open_demand_idx
  ON public.listings(category, city, created_at DESC)
  WHERE listing_type = 'request' AND mode = 'seek' AND is_active = true;

-- Create a structured demand listing. AI may PREPARE these values, but Flutter
-- calls this RPC only after explicit user confirmation.
CREATE OR REPLACE FUNCTION public.rpc_create_marketplace_need(
  p_category text,
  p_title text,
  p_description text DEFAULT '',
  p_city text DEFAULT NULL,
  p_neighborhood text DEFAULT NULL,
  p_latitude double precision DEFAULT NULL,
  p_longitude double precision DEFAULT NULL,
  p_budget_min numeric DEFAULT NULL,
  p_budget_max numeric DEFAULT NULL,
  p_currency text DEFAULT 'USD',
  p_starts_at timestamptz DEFAULT NULL,
  p_ends_at timestamptz DEFAULT NULL,
  p_party_size integer DEFAULT NULL,
  p_urgency text DEFAULT 'flexible',
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS public.listings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.listings;
  v_category text := lower(trim(COALESCE(p_category, '')));
  v_urgency text := lower(trim(COALESCE(p_urgency, 'flexible')));
  v_context jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF v_category NOT IN ('property','yacht','motorcycle','bicycle','worker','service') THEN
    RAISE EXCEPTION 'Unsupported marketplace category';
  END IF;
  IF length(trim(COALESCE(p_title, ''))) < 3 THEN
    RAISE EXCEPTION 'Tell us what you need';
  END IF;
  IF v_urgency NOT IN ('now','today','this_week','flexible') THEN
    v_urgency := 'flexible';
  END IF;
  IF p_budget_min IS NOT NULL AND p_budget_min < 0 THEN
    RAISE EXCEPTION 'Invalid minimum budget';
  END IF;
  IF p_budget_max IS NOT NULL AND p_budget_max < 0 THEN
    RAISE EXCEPTION 'Invalid maximum budget';
  END IF;
  IF p_budget_min IS NOT NULL AND p_budget_max IS NOT NULL AND p_budget_max < p_budget_min THEN
    RAISE EXCEPTION 'Maximum budget must be greater than minimum budget';
  END IF;
  IF p_starts_at IS NOT NULL AND p_ends_at IS NOT NULL AND p_ends_at < p_starts_at THEN
    RAISE EXCEPTION 'End time must be after start time';
  END IF;

  v_context := jsonb_strip_nulls(jsonb_build_object(
    'budget_min', p_budget_min,
    'budget_max', p_budget_max,
    'currency', upper(left(trim(COALESCE(p_currency, 'USD')), 8)),
    'starts_at', p_starts_at,
    'ends_at', p_ends_at,
    'party_size', CASE WHEN p_party_size IS NULL THEN NULL ELSE greatest(1, least(p_party_size, 100)) END,
    'urgency', v_urgency,
    'neighborhood', nullif(left(trim(COALESCE(p_neighborhood, '')), 120), ''),
    'metadata', CASE WHEN jsonb_typeof(COALESCE(p_metadata, '{}'::jsonb)) = 'object'
      THEN COALESCE(p_metadata, '{}'::jsonb)
      ELSE '{}'::jsonb
    END
  ));

  INSERT INTO public.listings(
    owner_id, listing_type, mode, is_active, category, title, description,
    price, pricing_unit, city, location, latitude, longitude, status,
    request_context, created_at, updated_at
  ) VALUES (
    v_uid, 'request', 'seek', true, v_category,
    left(trim(p_title), 140),
    left(trim(COALESCE(p_description, '')), 2000),
    COALESCE(p_budget_max, p_budget_min, 0),
    'request',
    nullif(left(trim(COALESCE(p_city, '')), 120), ''),
    COALESCE(
      nullif(left(trim(COALESCE(p_neighborhood, '')), 120), ''),
      nullif(left(trim(COALESCE(p_city, '')), 120), '')
    ),
    p_latitude,
    p_longitude,
    v_urgency,
    v_context,
    now(),
    now()
  ) RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_close_marketplace_need(
  p_need_id uuid,
  p_status text DEFAULT 'closed'
)
RETURNS public.listings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.listings;
  v_status text := lower(trim(COALESCE(p_status, 'closed')));
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF v_status NOT IN ('matched','closed','cancelled') THEN v_status := 'closed'; END IF;

  UPDATE public.listings
     SET is_active = false, status = v_status, updated_at = now()
   WHERE id = p_need_id
     AND owner_id = v_uid
     AND listing_type = 'request'
     AND mode = 'seek'
   RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN RAISE EXCEPTION 'Need not found'; END IF;
  RETURN v_row;
END;
$$;

-- Structured Direct Request v2. The legacy function stays untouched for old
-- installed builds. This wrapper uses the same reservation engine and stores
-- only a small whitelist of useful context for the receiver.
CREATE OR REPLACE FUNCTION public.rpc_create_direct_request_v2(
  p_receiver_id uuid,
  p_listing_id uuid DEFAULT NULL,
  p_message text DEFAULT '',
  p_context jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_result jsonb;
  v_request_id uuid;
  v_context jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  v_context := jsonb_strip_nulls(jsonb_build_object(
    'starts_at', CASE WHEN jsonb_typeof(p_context->'starts_at') = 'string' THEN left(p_context->>'starts_at', 64) END,
    'ends_at', CASE WHEN jsonb_typeof(p_context->'ends_at') = 'string' THEN left(p_context->>'ends_at', 64) END,
    'budget_min', CASE WHEN jsonb_typeof(p_context->'budget_min') IN ('number','string') THEN left(p_context->>'budget_min', 32) END,
    'budget_max', CASE WHEN jsonb_typeof(p_context->'budget_max') IN ('number','string') THEN left(p_context->>'budget_max', 32) END,
    'currency', CASE WHEN jsonb_typeof(p_context->'currency') = 'string' THEN upper(left(p_context->>'currency', 8)) END,
    'location', CASE WHEN jsonb_typeof(p_context->'location') = 'string' THEN left(p_context->>'location', 160) END,
    'party_size', CASE WHEN jsonb_typeof(p_context->'party_size') IN ('number','string') THEN left(p_context->>'party_size', 8) END,
    'urgency', CASE WHEN p_context->>'urgency' IN ('now','today','this_week','flexible') THEN p_context->>'urgency' END,
    'need_id', CASE WHEN jsonb_typeof(p_context->'need_id') = 'string' THEN left(p_context->>'need_id', 64) END
  ));

  SELECT public.rpc_create_direct_request(p_receiver_id, p_listing_id, p_message)
    INTO v_result;
  v_request_id := NULLIF(v_result->>'id', '')::uuid;

  IF v_request_id IS NOT NULL THEN
    UPDATE public.direct_requests
       SET request_context = v_context
     WHERE id = v_request_id AND sender_id = v_uid;
  END IF;

  RETURN COALESCE(v_result, '{}'::jsonb) || jsonb_build_object('context', v_context);
END;
$$;

-- Match an existing demand listing against normal supply listings. Request
-- rows are explicitly excluded so demand never matches demand.
CREATE OR REPLACE FUNCTION public.rpc_find_listings_for_need(
  p_need_id uuid,
  p_limit integer DEFAULT 30
)
RETURNS SETOF public.listings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_need public.listings;
  v_budget_min numeric;
  v_budget_max numeric;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_need
  FROM public.listings n
  WHERE n.id = p_need_id
    AND n.listing_type = 'request'
    AND n.mode = 'seek';
  IF NOT FOUND THEN RAISE EXCEPTION 'Need not found'; END IF;

  v_budget_min := NULLIF(v_need.request_context->>'budget_min', '')::numeric;
  v_budget_max := NULLIF(v_need.request_context->>'budget_max', '')::numeric;

  RETURN QUERY
  SELECT l.*
  FROM public.listings l
  WHERE COALESCE(l.is_active, true) = true
    AND COALESCE(l.status, 'active') NOT IN ('deleted','archived','inactive','closed','cancelled')
    AND COALESCE(l.listing_type, '') <> 'request'
    AND COALESCE(l.mode, '') <> 'seek'
    AND l.id <> v_need.id
    AND (
      lower(COALESCE(l.category, '')) = lower(COALESCE(v_need.category, ''))
      OR (lower(COALESCE(v_need.category, '')) IN ('worker','service') AND lower(COALESCE(l.category, '')) IN ('worker','service','workers','services'))
      OR (lower(COALESCE(v_need.category, '')) = 'motorcycle' AND lower(COALESCE(l.category, '')) IN ('motorcycle','motorcycles','moto','motos'))
      OR (lower(COALESCE(v_need.category, '')) = 'bicycle' AND lower(COALESCE(l.category, '')) IN ('bicycle','bicycles','bike','bikes'))
    )
    AND (v_need.city IS NULL OR lower(COALESCE(l.city, '')) = lower(v_need.city))
    AND (v_budget_max IS NULL OR l.price IS NULL OR l.price <= v_budget_max)
    AND (v_budget_min IS NULL OR l.price IS NULL OR l.price >= v_budget_min)
  ORDER BY
    CASE WHEN v_need.city IS NOT NULL AND lower(COALESCE(l.city, '')) = lower(v_need.city) THEN 0 ELSE 1 END,
    CASE WHEN l.created_at >= now() - interval '48 hours' THEN 0 ELSE 1 END,
    COALESCE(l.updated_at, l.created_at) DESC
  LIMIT greatest(1, least(COALESCE(p_limit, 30), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_create_marketplace_need(text,text,text,text,text,double precision,double precision,numeric,numeric,text,timestamptz,timestamptz,integer,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_marketplace_need(text,text,text,text,text,double precision,double precision,numeric,numeric,text,timestamptz,timestamptz,integer,text,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.rpc_close_marketplace_need(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_close_marketplace_need(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.rpc_create_direct_request_v2(uuid,uuid,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_create_direct_request_v2(uuid,uuid,text,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.rpc_find_listings_for_need(uuid,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_find_listings_for_need(uuid,integer) TO authenticated;
