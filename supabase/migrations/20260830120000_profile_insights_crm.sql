-- Profile insights / lightweight CRM for premium members.
-- Tracks views, messages, direct requests, shares and external contact taps.

CREATE TABLE IF NOT EXISTS public.profile_insight_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type text NOT NULL CHECK (
    event_type IN (
      'profile_view',
      'message',
      'direct_request',
      'share',
      'whatsapp',
      'call',
      'social',
      'listing_view',
      'external_link'
    )
  ),
  channel text NOT NULL DEFAULT 'in_app' CHECK (
    channel IN (
      'in_app',
      'whatsapp',
      'instagram',
      'facebook',
      'sms',
      'email',
      'web',
      'other'
    )
  ),
  source text NOT NULL DEFAULT 'flutter',
  session_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profile_insight_events_owner_created
  ON public.profile_insight_events (owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_profile_insight_events_owner_type
  ON public.profile_insight_events (owner_user_id, event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_profile_insight_events_actor
  ON public.profile_insight_events (actor_user_id, created_at DESC)
  WHERE actor_user_id IS NOT NULL;

ALTER TABLE public.profile_insight_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profile_insight_events_insert ON public.profile_insight_events;
CREATE POLICY profile_insight_events_insert ON public.profile_insight_events
  FOR INSERT TO authenticated
  WITH CHECK (
    owner_user_id IS DISTINCT FROM auth.uid()
    AND (actor_user_id IS NULL OR actor_user_id = auth.uid())
  );

DROP POLICY IF EXISTS profile_insight_events_select_own ON public.profile_insight_events;
CREATE POLICY profile_insight_events_select_own ON public.profile_insight_events
  FOR SELECT TO authenticated
  USING (owner_user_id = auth.uid());

COMMENT ON TABLE public.profile_insight_events IS
  'Best-effort profile engagement analytics for premium CRM / insights.';

CREATE OR REPLACE FUNCTION public.track_profile_insight_event(
  p_owner_user_id uuid,
  p_event_type text,
  p_channel text DEFAULT 'in_app',
  p_source text DEFAULT 'flutter',
  p_session_id text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF p_owner_user_id IS NULL OR p_event_type IS NULL OR btrim(p_event_type) = '' THEN
    RETURN;
  END IF;

  IF v_actor IS NOT NULL AND v_actor = p_owner_user_id THEN
    RETURN;
  END IF;

  INSERT INTO public.profile_insight_events (
    owner_user_id,
    actor_user_id,
    event_type,
    channel,
    source,
    session_id,
    metadata
  )
  VALUES (
    p_owner_user_id,
    v_actor,
    lower(btrim(p_event_type)),
    lower(COALESCE(NULLIF(btrim(p_channel), ''), 'in_app')),
    COALESCE(NULLIF(btrim(p_source), ''), 'flutter'),
    p_session_id,
    COALESCE(p_metadata, '{}'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.track_profile_insight_event(
  uuid, text, text, text, text, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.track_profile_insight_event(
  uuid, text, text, text, text, jsonb
) TO authenticated;

CREATE OR REPLACE FUNCTION public.rpc_profile_insights_summary(
  p_days integer DEFAULT 30
)
RETURNS TABLE (
  profile_views bigint,
  in_app_messages bigint,
  direct_requests bigint,
  shares bigint,
  whatsapp_taps bigint,
  social_taps bigint,
  external_clicks bigint,
  total_contacts bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  WITH scoped AS (
    SELECT e.*
    FROM public.profile_insight_events e
    WHERE e.owner_user_id = auth.uid()
      AND e.created_at >= now() - make_interval(days => GREATEST(COALESCE(p_days, 30), 1))
  )
  SELECT
    COUNT(*) FILTER (WHERE event_type = 'profile_view')::bigint AS profile_views,
    COUNT(*) FILTER (WHERE event_type = 'message')::bigint AS in_app_messages,
    COUNT(*) FILTER (WHERE event_type = 'direct_request')::bigint AS direct_requests,
    COUNT(*) FILTER (WHERE event_type = 'share')::bigint AS shares,
    COUNT(*) FILTER (WHERE event_type = 'whatsapp' OR channel = 'whatsapp')::bigint AS whatsapp_taps,
    COUNT(*) FILTER (WHERE event_type = 'social' OR channel IN ('instagram', 'facebook'))::bigint AS social_taps,
    COUNT(*) FILTER (
      WHERE event_type IN ('whatsapp', 'call', 'social', 'external_link')
        OR channel NOT IN ('in_app')
    )::bigint AS external_clicks,
    COUNT(DISTINCT actor_user_id) FILTER (WHERE actor_user_id IS NOT NULL)::bigint AS total_contacts
  FROM scoped;
$$;

REVOKE ALL ON FUNCTION public.rpc_profile_insights_summary(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_profile_insights_summary(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.rpc_profile_insight_contacts(
  p_days integer DEFAULT 30,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  actor_user_id uuid,
  display_name text,
  avatar_url text,
  occupation text,
  is_app_member boolean,
  last_event_type text,
  last_channel text,
  last_seen_at timestamptz,
  touch_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  WITH scoped AS (
    SELECT e.*
    FROM public.profile_insight_events e
    WHERE e.owner_user_id = auth.uid()
      AND e.actor_user_id IS NOT NULL
      AND e.created_at >= now() - make_interval(days => GREATEST(COALESCE(p_days, 30), 1))
  ),
  ranked AS (
    SELECT
      s.actor_user_id,
      s.event_type AS last_event_type,
      s.channel AS last_channel,
      s.created_at AS last_seen_at,
      COUNT(*) OVER (PARTITION BY s.actor_user_id) AS touch_count,
      ROW_NUMBER() OVER (
        PARTITION BY s.actor_user_id
        ORDER BY s.created_at DESC
      ) AS rn
    FROM scoped s
  )
  SELECT
    r.actor_user_id,
    COALESCE(
      NULLIF(btrim(cp.name), ''),
      NULLIF(btrim(op.business_name), ''),
      'Swipess member'
    ) AS display_name,
    CASE
      WHEN jsonb_typeof(cp.profile_images) = 'array' AND jsonb_array_length(cp.profile_images) > 0
        THEN cp.profile_images->>0
      WHEN jsonb_typeof(op.profile_images) = 'array' AND jsonb_array_length(op.profile_images) > 0
        THEN op.profile_images->>0
      ELSE NULL
    END AS avatar_url,
    COALESCE(NULLIF(btrim(cp.vap_occupation), ''), NULLIF(btrim(cp.occupation), '')) AS occupation,
    true AS is_app_member,
    r.last_event_type,
    r.last_channel,
    r.last_seen_at,
    r.touch_count
  FROM ranked r
  LEFT JOIN public.client_profiles cp ON cp.user_id = r.actor_user_id
  LEFT JOIN public.owner_profiles op ON op.user_id = r.actor_user_id
  WHERE r.rn = 1
  ORDER BY r.last_seen_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
$$;

REVOKE ALL ON FUNCTION public.rpc_profile_insight_contacts(integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_profile_insight_contacts(integer, integer) TO authenticated;
