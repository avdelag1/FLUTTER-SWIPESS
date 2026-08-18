-- Release security hardening for App Store / Play release.
-- Keep client read paths intact while moving privileged writes behind trusted
-- backend/service-role code.

-- ---------------------------------------------------------------------------
-- Paid subscriptions: clients may read their own subscription through RLS,
-- but must never be able to grant/update/delete paid entitlements directly.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can manage their own subscriptions"
  ON public.user_subscriptions;

REVOKE ALL ON TABLE public.user_subscriptions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.user_subscriptions TO authenticated;
GRANT ALL ON TABLE public.user_subscriptions TO service_role;

-- ---------------------------------------------------------------------------
-- Purchase replay/audit records are backend-only. The previous policy was
-- named for service_role but applied to PUBLIC with a true predicate.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Service role can manage purchase audit log"
  ON public.purchase_audit_log;

REVOKE ALL ON TABLE public.purchase_audit_log FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.purchase_audit_log TO service_role;

-- ---------------------------------------------------------------------------
-- Internal helper views are not used by the Flutter client. Make them execute
-- with invoker privileges and remove direct client access.
-- ---------------------------------------------------------------------------
ALTER VIEW public.app_users SET (security_invoker = true);
ALTER VIEW public.other_profiles SET (security_invoker = true);

REVOKE ALL ON TABLE public.app_users FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.other_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.app_users TO service_role;
GRANT SELECT ON TABLE public.other_profiles TO service_role;

-- ---------------------------------------------------------------------------
-- Legacy privileged RPCs. Current Flutter flows do not call these directly;
-- account deletion and purchase entitlement writes are handled by Edge
-- Functions. Restrict them to trusted backend code.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.delete_user_account(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_account(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.cancel_user_subscription(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_user_subscription(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.change_user_subscription(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.change_user_subscription(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.complete_user_onboarding(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_user_onboarding(uuid, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.send_message(uuid, uuid, text, bigint, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.send_message(uuid, uuid, text, bigint, text) TO service_role;

REVOKE ALL ON FUNCTION public.block_user(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.block_user(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.unblock_user(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.manage_user_verification(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.manage_user_verification(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.get_user_token_balance(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_token_balance(uuid) TO service_role;

-- This legacy helper returns full profile rows and is not used by the app.
REVOKE ALL ON FUNCTION public.get_other_profiles() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_other_profiles() TO service_role;

-- ---------------------------------------------------------------------------
-- Authenticated RPCs used by legitimate client/admin flows. Remove anonymous
--/PUBLIC execution while preserving authenticated and service-role access.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.admin_set_business_team_code(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_business_team_code(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.block_user(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.block_user(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.unblock_user(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.manage_user_verification(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.manage_user_verification(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_deduct_token(integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_deduct_token(integer, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_deduct_token(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_deduct_token(text, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_get_user_tokens() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_get_user_tokens() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_grant_referral_bonus(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_grant_referral_bonus(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_grant_welcome_tokens(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_grant_welcome_tokens(boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_notification_for_user(uuid, text, text, text, uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_notification_for_user(uuid, text, text, text, uuid, jsonb) TO authenticated, service_role;
