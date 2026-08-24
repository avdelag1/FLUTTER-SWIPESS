-- SWIPESS active-time loyalty is the only client-facing 5-step token reward path.
-- Legacy daily-quest RPCs remain available to service_role for historical/admin
-- maintenance only, but signed-in clients can no longer progress or claim them.

revoke execute on function public.rpc_get_or_create_daily_quests(uuid)
from public, anon, authenticated;
grant execute on function public.rpc_get_or_create_daily_quests(uuid)
to service_role;

revoke execute on function public.rpc_increment_quest_progress(uuid, text, integer)
from public, anon, authenticated;
grant execute on function public.rpc_increment_quest_progress(uuid, text, integer)
to service_role;

revoke execute on function public.rpc_claim_quest_reward(uuid, text)
from public, anon, authenticated;
grant execute on function public.rpc_claim_quest_reward(uuid, text)
to service_role;

-- Re-assert the intended active-time API boundary.
revoke execute on function public.rpc_record_active_usage(integer)
from public, anon;
grant execute on function public.rpc_record_active_usage(integer)
to authenticated;

revoke execute on function public.rpc_get_engagement_reward_progress()
from public, anon;
grant execute on function public.rpc_get_engagement_reward_progress()
to authenticated;
