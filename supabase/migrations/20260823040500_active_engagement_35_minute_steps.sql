-- Active-use reward ladder: five 35-minute engagement steps unlock one token.
-- The client only sends p_seconds while the app is foregrounded and receiving
-- real user interaction; this function remains authoritative and caps credit.

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
  v_step_seconds constant int := 2100;
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

  SELECT * INTO v_row
  FROM public.user_engagement_rewards
  WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'steps', v_points,
    'steps_needed', 5,
    'step_minutes', 35,
    'active_seconds_remainder', v_row.active_seconds_remainder,
    'seconds_to_next_step', GREATEST(0, v_step_seconds - v_row.active_seconds_remainder),
    'total_steps', v_row.total_steps,
    'tokens_awarded', v_row.tokens_awarded
  );
END;
$$;

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
  v_step_seconds constant int := 2100;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_seconds < 0 OR p_seconds > 120 THEN
    RAISE EXCEPTION 'Invalid active usage interval';
  END IF;

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

  v_elapsed := GREATEST(
    0,
    floor(extract(epoch FROM (now() - v_row.last_ping_at)))::int
  );

  IF p_seconds > 0 THEN
    -- Never credit more than the client reported, never more than 120 seconds,
    -- and never more than real wall-clock time since the last accepted ping.
    v_credit := LEAST(p_seconds, 120, v_elapsed);
  END IF;

  v_total_seconds := v_row.active_seconds_remainder + v_credit;
  v_steps_earned := floor(v_total_seconds / v_step_seconds::numeric)::int;
  v_new_remainder := mod(v_total_seconds, v_step_seconds);
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
      'reward', '5 active-use reward steps completed'
    );

    INSERT INTO public.notifications (
      user_id, notification_type, title, message, link_url, metadata
    ) VALUES (
      v_user_id,
      'system_announcement',
      'Free token unlocked',
      'You completed all 5 active-use steps and earned a free token.',
      '/client/profile',
      jsonb_build_object(
        'kind', 'engagement_token',
        'tokens', v_tokens_earned,
        'step_minutes', 35
      )
    );
  ELSIF v_steps_earned > 0 THEN
    INSERT INTO public.notifications (
      user_id, notification_type, title, message, link_url, metadata
    ) VALUES (
      v_user_id,
      'system_announcement',
      'Activity step unlocked',
      format('You reached step %s/5 toward a free token.', v_new_steps),
      '/client/profile',
      jsonb_build_object(
        'kind', 'engagement_step',
        'step', v_new_steps,
        'minutes', 35
      )
    );
  END IF;

  UPDATE public.profiles
  SET quest_points = v_new_steps
  WHERE id = v_user_id;

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
    'step_minutes', 35,
    'active_seconds_remainder', v_new_remainder,
    'seconds_to_next_step', GREATEST(0, v_step_seconds - v_new_remainder),
    'step_awarded', v_steps_earned > 0,
    'token_awarded', v_tokens_earned > 0,
    'tokens_earned', v_tokens_earned,
    'credited_seconds', v_credit
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rpc_record_active_usage(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_get_engagement_reward_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_record_active_usage(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_engagement_reward_progress() TO authenticated;
