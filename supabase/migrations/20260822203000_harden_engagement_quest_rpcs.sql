-- Require authenticated ownership for engagement/daily-quest RPCs and remove
-- the default PUBLIC/anon EXECUTE grants that SECURITY DEFINER functions get.

CREATE OR REPLACE FUNCTION public.rpc_get_or_create_daily_quests(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_today date := current_date;
    v_quests jsonb;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    SELECT quests INTO v_quests
    FROM public.user_daily_quests
    WHERE user_id = p_user_id AND quest_date = v_today;

    IF v_quests IS NULL THEN
        v_quests := '[
            {"id": "login", "title": "Daily Login", "goal": 1, "progress": 1, "points": 1, "claimed": false},
            {"id": "swipe", "title": "The Explorer", "goal": 10, "progress": 0, "points": 2, "claimed": false},
            {"id": "message", "title": "The Networker", "goal": 1, "progress": 0, "points": 2, "claimed": false}
        ]'::jsonb;

        INSERT INTO public.user_daily_quests (user_id, quest_date, quests)
        VALUES (p_user_id, v_today, v_quests)
        ON CONFLICT (user_id, quest_date) DO NOTHING;

        SELECT quests INTO v_quests
        FROM public.user_daily_quests
        WHERE user_id = p_user_id AND quest_date = v_today;
    END IF;

    RETURN v_quests;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_increment_quest_progress(
    p_user_id uuid,
    p_quest_id text,
    p_amount integer DEFAULT 1
)
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
    v_found boolean := false;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;
    IF p_amount < 1 OR p_amount > 10 THEN
        RAISE EXCEPTION 'Invalid quest progress increment';
    END IF;

    SELECT quests INTO v_quests
    FROM public.user_daily_quests
    WHERE user_id = p_user_id AND quest_date = v_today;

    IF v_quests IS NULL THEN
        RETURN NULL;
    END IF;

    FOR v_quest IN SELECT * FROM jsonb_array_elements(v_quests)
    LOOP
        IF v_quest->>'id' = p_quest_id AND NOT (v_quest->>'claimed')::boolean THEN
            v_quest := jsonb_set(
                v_quest,
                '{progress}',
                to_jsonb(LEAST((v_quest->>'goal')::int, (v_quest->>'progress')::int + p_amount))
            );
            v_found := true;
        END IF;
        v_new_quests := v_new_quests || v_quest;
    END LOOP;

    IF v_found THEN
        UPDATE public.user_daily_quests
        SET quests = v_new_quests, updated_at = now()
        WHERE user_id = p_user_id AND quest_date = v_today;
    END IF;

    RETURN v_new_quests;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rpc_get_or_create_daily_quests(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_increment_quest_progress(uuid, text, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_claim_quest_reward(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_record_active_usage(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_get_engagement_reward_progress() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.rpc_get_or_create_daily_quests(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_increment_quest_progress(uuid, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_claim_quest_reward(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_record_active_usage(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_engagement_reward_progress() TO authenticated;
