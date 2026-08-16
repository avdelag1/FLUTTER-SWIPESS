-- Migration 3: Views and RPC Cleanup

-- 1. Views
-- Keep event_engagement_summary and profiles_excluding_caller as security_invoker.
ALTER VIEW public.profiles_excluding_caller SET (security_invoker = true);
ALTER VIEW public.event_engagement_summary SET (security_invoker = true);

-- other_profiles and app_users remain untouched to preserve their intended behavior.

-- 2. Hardening RPCs with Exact Signatures
REVOKE EXECUTE ON FUNCTION public.set_user_role(public.user_role) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.upsert_user_role(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.assign_user_subscription(uuid, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._deduct_user_tokens(uuid, integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.manage_user_ban(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_premium(uuid, integer) FROM PUBLIC, anon, authenticated;
