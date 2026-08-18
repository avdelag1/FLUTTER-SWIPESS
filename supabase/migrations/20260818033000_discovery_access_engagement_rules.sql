-- Swipess discovery decisions, rolling complimentary access and engagement rewards.
-- This migration mirrors the production rules applied during the 1.2.36 release pass.

-- -----------------------------------------------------------------------------
-- Discovery decisions
-- -----------------------------------------------------------------------------
ALTER TABLE public.likes
  ADD COLUMN IF NOT EXISTS decision_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;

UPDATE public.likes
SET cooldown_until = COALESCE(dismissed_at, created_at, now()) + interval '7 days'
WHERE direction = 'left' AND dismiss_count = 1;

UPDATE public.likes d
SET decision_snapshot = jsonb_build_object(
  'price', COALESCE(l.price, l.hourly_rate),
  'description_length', length(trim(COALESCE(l.description, ''))),
  'image_count', COALESCE(array_length(l.images, 1), 0),
  'updated_at', l.updated_at
)
FROM public.listings l
WHERE d.target_type = 'listing'
  AND d.target_id = l.id
  AND d.direction = 'left'
  AND d.decision_snapshot = '{}'::jsonb;

UPDATE public.likes d
SET decision_snapshot = jsonb_build_object(
  'rating', COALESCE(p.average_rating, 0),
  'reviews', COALESCE(p.total_reviews, 0),
  'bio_length', length(trim(COALESCE(p.bio, ''))),
  'image_count', COALESCE(array_length(p.images, 1), 0),
  'verified', COALESCE(p.verified, false),
  'updated_at', p.updated_at
)
FROM public.profiles p
WHERE d.target_type = 'profile'
  AND d.target_id = p.id
  AND d.direction = 'left'
  AND d.decision_snapshot = '{}'::jsonb;

CREATE OR REPLACE FUNCTION public._discovery_listing_visible(
  p_user_id uuid,
  p_listing_id uuid,
  p_price numeric,
  p_hourly_rate numeric,
  p_description text,
  p_images text[]
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_decision record;
  v_snapshot jsonb;
  v_current_price numeric;
  v_snapshot_price numeric;
  v_description_length int;
  v_snapshot_description_length int;
  v_image_count int;
  v_snapshot_image_count int;
BEGIN
  IF p_user_id IS NULL THEN RETURN true; END IF;

  SELECT direction, dismiss_count, cooldown_until, dismissed_at, decision_snapshot
    INTO v_decision
  FROM public.likes
  WHERE user_id = p_user_id
    AND target_id = p_listing_id
    AND target_type = 'listing'
  LIMIT 1;

  IF NOT FOUND THEN RETURN true; END IF;
  IF v_decision.direction = 'right' THEN RETURN false; END IF;
  IF v_decision.direction <> 'left' THEN RETURN true; END IF;

  IF COALESCE(v_decision.dismiss_count, 0) <= 1 THEN
    RETURN COALESCE(
      v_decision.cooldown_until,
      v_decision.dismissed_at + interval '7 days',
      now() + interval '7 days'
    ) <= now();
  END IF;

  IF v_decision.dismiss_count >= 3 THEN RETURN false; END IF;

  v_snapshot := COALESCE(v_decision.decision_snapshot, '{}'::jsonb);
  v_current_price := COALESCE(p_price, p_hourly_rate);
  v_snapshot_price := NULLIF(v_snapshot->>'price', '')::numeric;
  v_description_length := length(trim(COALESCE(p_description, '')));
  v_snapshot_description_length := COALESCE(NULLIF(v_snapshot->>'description_length', '')::int, 0);
  v_image_count := COALESCE(array_length(p_images, 1), 0);
  v_snapshot_image_count := COALESCE(NULLIF(v_snapshot->>'image_count', '')::int, 0);

  RETURN
    (v_snapshot_price IS NOT NULL AND v_current_price IS NOT NULL AND v_current_price < v_snapshot_price)
    OR v_description_length >= v_snapshot_description_length + 40
    OR v_image_count > v_snapshot_image_count;
END;
$$;

CREATE OR REPLACE FUNCTION public._discovery_profile_visible(
  p_user_id uuid,
  p_target_id uuid,
  p_rating numeric,
  p_reviews int,
  p_bio text,
  p_image_count int,
  p_verified boolean
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_decision record;
  v_snapshot jsonb;
  v_snapshot_rating numeric;
  v_snapshot_reviews int;
  v_snapshot_bio_length int;
  v_snapshot_image_count int;
  v_snapshot_verified boolean;
BEGIN
  IF p_user_id IS NULL THEN RETURN true; END IF;

  SELECT direction, dismiss_count, cooldown_until, dismissed_at, decision_snapshot
    INTO v_decision
  FROM public.likes
  WHERE user_id = p_user_id
    AND target_id = p_target_id
    AND target_type = 'profile'
  LIMIT 1;

  IF NOT FOUND THEN RETURN true; END IF;
  IF v_decision.direction = 'right' THEN RETURN false; END IF;
  IF v_decision.direction <> 'left' THEN RETURN true; END IF;

  IF COALESCE(v_decision.dismiss_count, 0) <= 1 THEN
    RETURN COALESCE(
      v_decision.cooldown_until,
      v_decision.dismissed_at + interval '7 days',
      now() + interval '7 days'
    ) <= now();
  END IF;

  IF v_decision.dismiss_count >= 3 THEN RETURN false; END IF;

  v_snapshot := COALESCE(v_decision.decision_snapshot, '{}'::jsonb);
  v_snapshot_rating := COALESCE(NULLIF(v_snapshot->>'rating', '')::numeric, 0);
  v_snapshot_reviews := COALESCE(NULLIF(v_snapshot->>'reviews', '')::int, 0);
  v_snapshot_bio_length := COALESCE(NULLIF(v_snapshot->>'bio_length', '')::int, 0);
  v_snapshot_image_count := COALESCE(NULLIF(v_snapshot->>'image_count', '')::int, 0);
  v_snapshot_verified := COALESCE((v_snapshot->>'verified')::boolean, false);

  RETURN
    COALESCE(p_rating, 0) > v_snapshot_rating
    OR (COALESCE(p_reviews, 0) > v_snapshot_reviews AND COALESCE(p_rating, 0) >= v_snapshot_rating)
    OR length(trim(COALESCE(p_bio, ''))) >= v_snapshot_bio_length + 40
    OR COALESCE(p_image_count, 0) > v_snapshot_image_count
    OR (COALESCE(p_verified, false) AND NOT v_snapshot_verified);
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_record_discovery_decision(
  p_target_id uuid,
  p_target_type text,
  p_direction text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_existing record;
  v_dismiss_count int := 0;
  v_cooldown_until timestamptz;
  v_snapshot jsonb := '{}'::jsonb;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_target_type NOT IN ('listing', 'profile') THEN RAISE EXCEPTION 'Unsupported target type'; END IF;
  IF p_direction NOT IN ('left', 'right') THEN RAISE EXCEPTION 'Unsupported direction'; END IF;

  IF p_target_type = 'listing' THEN
    SELECT jsonb_build_object(
      'price', COALESCE(l.price, l.hourly_rate),
      'description_length', length(trim(COALESCE(l.description, ''))),
      'image_count', COALESCE(array_length(l.images, 1), 0),
      'updated_at', l.updated_at
    ) INTO v_snapshot
    FROM public.listings l
    WHERE l.id = p_target_id;
  ELSE
    SELECT jsonb_build_object(
      'rating', COALESCE(p.average_rating, 0),
      'reviews', COALESCE(p.total_reviews, 0),
      'bio_length', length(trim(COALESCE(NULLIF(p.bio, ''), NULLIF(cp.vap_bio, ''), cp.bio, ''))),
      'image_count', GREATEST(
        COALESCE(array_length(p.images, 1), 0),
        CASE WHEN jsonb_typeof(cp.profile_images) = 'array' THEN jsonb_array_length(cp.profile_images) ELSE 0 END
      ),
      'verified', COALESCE(p.verified, false),
      'updated_at', GREATEST(
        COALESCE(p.updated_at, '-infinity'::timestamptz),
        COALESCE(cp.updated_at, '-infinity'::timestamptz)
      )
    ) INTO v_snapshot
    FROM public.profiles p
    LEFT JOIN public.client_profiles cp ON cp.user_id = p.id
    WHERE p.id = p_target_id;
  END IF;

  v_snapshot := COALESCE(v_snapshot, '{}'::jsonb);

  SELECT direction, dismiss_count
    INTO v_existing
  FROM public.likes
  WHERE user_id = v_user_id
    AND target_id = p_target_id
    AND target_type = p_target_type
  FOR UPDATE;

  IF p_direction = 'right' THEN
    v_dismiss_count := 0;
    v_cooldown_until := NULL;
  ELSE
    IF FOUND AND v_existing.direction = 'left' THEN
      v_dismiss_count := COALESCE(v_existing.dismiss_count, 0) + 1;
    ELSE
      v_dismiss_count := 1;
    END IF;
    IF v_dismiss_count = 1 THEN
      v_cooldown_until := now() + interval '7 days';
    ELSE
      v_cooldown_until := NULL;
    END IF;
  END IF;

  INSERT INTO public.likes (
    user_id, target_id, target_type, direction,
    dismiss_count, dismissed_at, cooldown_until, decision_snapshot
  ) VALUES (
    v_user_id, p_target_id, p_target_type, p_direction,
    v_dismiss_count,
    CASE WHEN p_direction = 'left' THEN now() ELSE NULL END,
    v_cooldown_until,
    v_snapshot
  )
  ON CONFLICT (user_id, target_id, target_type)
  DO UPDATE SET
    direction = EXCLUDED.direction,
    dismiss_count = EXCLUDED.dismiss_count,
    dismissed_at = EXCLUDED.dismissed_at,
    cooldown_until = EXCLUDED.cooldown_until,
    decision_snapshot = EXCLUDED.decision_snapshot,
    created_at = now();

  RETURN jsonb_build_object(
    'direction', p_direction,
    'dismiss_count', v_dismiss_count,
    'cooldown_until', v_cooldown_until,
    'permanent', p_direction = 'left' AND v_dismiss_count >= 3
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.rpc_record_discovery_decision(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.rpc_filter_discoverable_listing_ids(p_ids uuid[])
RETURNS uuid[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT COALESCE(array_agg(l.id), ARRAY[]::uuid[])
  FROM public.listings l
  WHERE l.id = ANY(COALESCE(p_ids, ARRAY[]::uuid[]))
    AND public._discovery_listing_visible(
      auth.uid(), l.id, l.price, l.hourly_rate, l.description, l.images
    );
$$;
GRANT EXECUTE ON FUNCTION public.rpc_filter_discoverable_listing_ids(uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.rpc_filter_discoverable_profile_ids(p_ids uuid[])
RETURNS uuid[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT COALESCE(array_agg(ids.user_id), ARRAY[]::uuid[])
  FROM (
    SELECT
      x.user_id,
      COALESCE(p.average_rating, 0) AS rating,
      COALESCE(p.total_reviews, 0) AS reviews,
      COALESCE(NULLIF(p.bio, ''), NULLIF(cp.vap_bio, ''), cp.bio, '') AS bio,
      GREATEST(
        COALESCE(array_length(p.images, 1), 0),
        CASE WHEN jsonb_typeof(cp.profile_images) = 'array' THEN jsonb_array_length(cp.profile_images) ELSE 0 END
      ) AS image_count,
      COALESCE(p.verified, false) AS verified
    FROM unnest(COALESCE(p_ids, ARRAY[]::uuid[])) AS x(user_id)
    LEFT JOIN public.profiles p ON p.id = x.user_id
    LEFT JOIN public.client_profiles cp ON cp.user_id = x.user_id
  ) ids
  WHERE public._discovery_profile_visible(
    auth.uid(), ids.user_id, ids.rating, ids.reviews, ids.bio, ids.image_count, ids.verified
  );
$$;
GRANT EXECUTE ON FUNCTION public.rpc_filter_discoverable_profile_ids(uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_smart_listings(
  p_user_id uuid DEFAULT NULL::uuid,
  p_category text DEFAULT NULL::text,
  p_limit integer DEFAULT 30,
  p_offset integer DEFAULT 0
)
RETURNS SETOF public.listings
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT l.*
  FROM public.listings l
  WHERE auth.uid() IS NOT NULL
    AND COALESCE(l.is_active, true) = true
    AND COALESCE(l.status, 'active') = 'active'
    AND (p_category IS NULL OR l.category = p_category)
    AND l.owner_id IS DISTINCT FROM COALESCE(p_user_id, auth.uid())
    AND public._discovery_listing_visible(
      auth.uid(), l.id, l.price, l.hourly_rate, l.description, l.images
    )
  ORDER BY l.created_at ASC NULLS LAST, l.id ASC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 30), 200))
  OFFSET GREATEST(0, COALESCE(p_offset, 0));
$$;

CREATE OR REPLACE FUNCTION public.get_passport_map_listings(
  p_user_lat double precision,
  p_user_lon double precision,
  p_radius_km double precision DEFAULT 50,
  p_limit integer DEFAULT 300,
  p_exclude_owner_id uuid DEFAULT NULL::uuid
)
RETURNS TABLE(
  id uuid, title text, price numeric, images text[], category text, city text,
  latitude double precision, longitude double precision, bedrooms integer,
  bathrooms integer, distance_km double precision
)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT
    l.id, l.title, l.price, l.images, l.category, l.city,
    l.latitude::double precision, l.longitude::double precision,
    l.bedrooms, l.bathrooms,
    public.haversine_km(p_user_lat, p_user_lon, l.latitude, l.longitude) AS distance_km
  FROM public.listings l
  WHERE l.latitude IS NOT NULL
    AND l.longitude IS NOT NULL
    AND COALESCE(l.is_active, true) = true
    AND COALESCE(l.status, 'active') = 'active'
    AND (p_exclude_owner_id IS NULL OR l.owner_id IS DISTINCT FROM p_exclude_owner_id)
    AND public.haversine_km(p_user_lat, p_user_lon, l.latitude, l.longitude) <= p_radius_km
    AND public._discovery_listing_visible(
      auth.uid(), l.id, l.price, l.hourly_rate, l.description, l.images
    )
  ORDER BY distance_km
  LIMIT p_limit;
$$;

-- -----------------------------------------------------------------------------
-- Rolling new-user complimentary access campaign
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_access_campaigns (
  campaign_key text PRIMARY KEY,
  signup_starts_at timestamptz NOT NULL,
  signup_ends_at timestamptz,
  trial_months integer NOT NULL DEFAULT 3 CHECK (trial_months BETWEEN 1 AND 24),
  accepting_new_signups boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.app_access_campaigns (
  campaign_key, signup_starts_at, signup_ends_at, trial_months, accepting_new_signups
) VALUES (
  'new_user_premium_trial', '2026-08-17 00:00:00-05'::timestamptz, NULL, 3, true
)
ON CONFLICT (campaign_key) DO NOTHING;

ALTER TABLE public.app_access_campaigns ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can read access campaigns" ON public.app_access_campaigns;
CREATE POLICY "Public can read access campaigns"
  ON public.app_access_campaigns FOR SELECT
  TO anon, authenticated
  USING (true);
GRANT SELECT ON public.app_access_campaigns TO anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.app_access_campaigns FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.rpc_ensure_trial_expiry_notification(p_trial_ends_at timestamptz)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL OR p_trial_ends_at IS NULL OR p_trial_ends_at > now() THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_subscriptions s
    WHERE s.user_id = v_user_id
      AND s.is_active = true
      AND (s.end_date IS NULL OR s.end_date > now())
  ) THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.notifications n
    WHERE n.user_id = v_user_id
      AND n.metadata @> '{"kind":"complimentary_trial_expired"}'::jsonb
  ) THEN
    RETURN false;
  END IF;

  INSERT INTO public.notifications (
    user_id, notification_type, title, message, link_url, metadata
  ) VALUES (
    v_user_id,
    'system_announcement',
    'Your complimentary access has ended',
    'Your 3-month Swipess access is complete. Choose a membership to keep using AI, Events and Legal services.',
    '/subscription/packages',
    jsonb_build_object('kind', 'complimentary_trial_expired', 'trial_ended_at', p_trial_ends_at)
  );
  RETURN true;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rpc_ensure_trial_expiry_notification(timestamptz) TO authenticated;

-- -----------------------------------------------------------------------------
-- Foreground engagement reward: 90 active minutes = 1 step; 5 = 1 token
-- -----------------------------------------------------------------------------
ALTER TABLE public.tokens ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.tokens ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS public.user_engagement_rewards (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  active_seconds_remainder integer NOT NULL DEFAULT 0 CHECK (active_seconds_remainder >= 0),
  current_steps integer NOT NULL DEFAULT 0 CHECK (current_steps BETWEEN 0 AND 4),
  total_steps bigint NOT NULL DEFAULT 0,
  tokens_awarded bigint NOT NULL DEFAULT 0,
  last_ping_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.user_engagement_rewards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read own engagement reward" ON public.user_engagement_rewards;
CREATE POLICY "Users can read own engagement reward"
  ON public.user_engagement_rewards FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());
GRANT SELECT ON public.user_engagement_rewards TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.user_engagement_rewards FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.rpc_get_engagement_reward_progress()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_row public.user_engagement_rewards%ROWTYPE;
  v_points int := 0;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  INSERT INTO public.user_engagement_rewards(user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT COALESCE(quest_points, 0) INTO v_points
  FROM public.profiles WHERE id = v_user_id;
  v_points := mod(GREATEST(v_points, 0), 5);

  UPDATE public.user_engagement_rewards
  SET current_steps = v_points, updated_at = now()
  WHERE user_id = v_user_id;

  SELECT * INTO v_row FROM public.user_engagement_rewards WHERE user_id = v_user_id;
  RETURN jsonb_build_object(
    'steps', v_points,
    'steps_needed', 5,
    'active_seconds_remainder', v_row.active_seconds_remainder,
    'seconds_to_next_step', GREATEST(0, 5400 - v_row.active_seconds_remainder),
    'total_steps', v_row.total_steps,
    'tokens_awarded', v_row.tokens_awarded
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.rpc_get_engagement_reward_progress() TO authenticated;

CREATE OR REPLACE FUNCTION public.rpc_record_active_usage(p_seconds integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_row public.user_engagement_rewards%ROWTYPE;
  v_elapsed int;
  v_credit int := 0;
  v_total_seconds int;
  v_steps_earned int := 0;
  v_current_points int := 0;
  v_step_total int;
  v_tokens_earned int := 0;
  v_new_steps int;
  v_new_remainder int;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_seconds < 0 OR p_seconds > 120 THEN RAISE EXCEPTION 'Invalid active usage interval'; END IF;

  INSERT INTO public.user_engagement_rewards(user_id, last_ping_at)
  VALUES (v_user_id, now())
  ON CONFLICT (user_id) DO NOTHING;

  SELECT * INTO v_row
  FROM public.user_engagement_rewards
  WHERE user_id = v_user_id
  FOR UPDATE;

  SELECT COALESCE(quest_points, 0) INTO v_current_points
  FROM public.profiles
  WHERE id = v_user_id
  FOR UPDATE;
  v_current_points := mod(GREATEST(v_current_points, 0), 5);

  v_elapsed := GREATEST(0, floor(extract(epoch FROM (now() - v_row.last_ping_at)))::int);
  IF p_seconds > 0 THEN
    v_credit := LEAST(p_seconds, 120, GREATEST(0, v_elapsed + 10));
  END IF;

  v_total_seconds := v_row.active_seconds_remainder + v_credit;
  v_steps_earned := floor(v_total_seconds / 5400.0)::int;
  v_new_remainder := mod(v_total_seconds, 5400);
  v_step_total := v_current_points + v_steps_earned;
  v_tokens_earned := floor(v_step_total / 5.0)::int;
  v_new_steps := mod(v_step_total, 5);

  IF v_tokens_earned > 0 THEN
    INSERT INTO public.tokens (
      user_id, token_type, amount, source,
      remaining_activations, total_activations, used_activations,
      activation_type, notes
    ) VALUES (
      v_user_id, 'messages', v_tokens_earned, 'engagement_reward',
      v_tokens_earned, v_tokens_earned, 0,
      'reward', '5 reward steps completed; active-use step = 90 foreground minutes'
    );

    INSERT INTO public.notifications (
      user_id, notification_type, title, message, link_url, metadata
    ) VALUES (
      v_user_id, 'system_announcement', 'Free token unlocked 🎉',
      'Nice work — you reached 5/5 and earned a free message token.',
      '/client/profile',
      jsonb_build_object('kind', 'engagement_token', 'tokens', v_tokens_earned)
    );
  ELSIF v_steps_earned > 0 THEN
    INSERT INTO public.notifications (
      user_id, notification_type, title, message, link_url, metadata
    ) VALUES (
      v_user_id, 'system_announcement', 'Activity step unlocked',
      format('90 active minutes complete — you are %s/5 of the way to a free message token.', v_new_steps),
      '/client/profile',
      jsonb_build_object('kind', 'engagement_step', 'step', v_new_steps)
    );
  END IF;

  UPDATE public.profiles SET quest_points = v_new_steps WHERE id = v_user_id;
  UPDATE public.user_engagement_rewards
  SET active_seconds_remainder = v_new_remainder,
      current_steps = v_new_steps,
      total_steps = total_steps + v_steps_earned,
      tokens_awarded = tokens_awarded + v_tokens_earned,
      last_ping_at = now(),
      updated_at = now()
  WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'steps', v_new_steps,
    'steps_needed', 5,
    'active_seconds_remainder', v_new_remainder,
    'seconds_to_next_step', GREATEST(0, 5400 - v_new_remainder),
    'step_awarded', v_steps_earned > 0,
    'token_awarded', v_tokens_earned > 0,
    'tokens_earned', v_tokens_earned,
    'credited_seconds', v_credit
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.rpc_record_active_usage(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.rpc_claim_quest_reward(p_user_id uuid, p_quest_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_today date := current_date;
  v_quests jsonb;
  v_quest jsonb;
  v_new_quests jsonb := '[]'::jsonb;
  v_points_to_add int := 0;
  v_current_points int;
  v_new_points int;
  v_tokens_earned int := 0;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT quests INTO v_quests
  FROM public.user_daily_quests
  WHERE user_id = p_user_id AND quest_date = v_today;
  IF v_quests IS NULL THEN RAISE EXCEPTION 'No quests found for today'; END IF;

  FOR v_quest IN SELECT * FROM jsonb_array_elements(v_quests)
  LOOP
    IF v_quest->>'id' = p_quest_id THEN
      IF (v_quest->>'claimed')::boolean THEN RAISE EXCEPTION 'Quest already claimed'; END IF;
      IF (v_quest->>'progress')::int < (v_quest->>'goal')::int THEN RAISE EXCEPTION 'Quest goal not reached yet'; END IF;
      v_quest := jsonb_set(v_quest, '{claimed}', 'true'::jsonb);
      v_points_to_add := (v_quest->>'points')::int;
    END IF;
    v_new_quests := v_new_quests || v_quest;
  END LOOP;

  IF v_points_to_add > 0 THEN
    UPDATE public.user_daily_quests SET quests = v_new_quests, updated_at = now()
    WHERE user_id = p_user_id AND quest_date = v_today;

    SELECT COALESCE(quest_points, 0) INTO v_current_points
    FROM public.profiles WHERE id = p_user_id FOR UPDATE;
    v_new_points := GREATEST(v_current_points, 0) + v_points_to_add;
    v_tokens_earned := floor(v_new_points / 5.0)::int;
    v_new_points := mod(v_new_points, 5);

    IF v_tokens_earned > 0 THEN
      INSERT INTO public.tokens (
        user_id, token_type, source, amount,
        remaining_activations, total_activations, used_activations,
        activation_type, notes
      ) VALUES (
        p_user_id, 'messages', 'daily_quest', v_tokens_earned,
        v_tokens_earned, v_tokens_earned, 0, 'reward', '5-step quest reward'
      );
    END IF;

    UPDATE public.profiles SET quest_points = v_new_points WHERE id = p_user_id;
    INSERT INTO public.user_engagement_rewards(user_id, current_steps)
    VALUES (p_user_id, v_new_points)
    ON CONFLICT (user_id) DO UPDATE
      SET current_steps = EXCLUDED.current_steps, updated_at = now();
  END IF;

  RETURN v_new_quests;
END;
$$;
GRANT EXECUTE ON FUNCTION public.rpc_claim_quest_reward(uuid, text) TO authenticated;
