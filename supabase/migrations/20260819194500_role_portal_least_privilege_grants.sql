-- Remove broad default grants from privileged portal tables.
-- RLS remains enabled, but table-level privileges should also follow least privilege.

revoke all privileges on table public.admin_users from anon, authenticated;
revoke all privileges on table public.user_roles from anon, authenticated;
revoke all privileges on table public.lawyer_users from anon, authenticated;
revoke all privileges on table public.business_promo_submissions from anon, authenticated;
revoke all privileges on table public.legal_package_requests from anon, authenticated;
revoke all privileges on table public.legal_video_calls from anon, authenticated;

grant select, insert, update on table public.lawyer_users to authenticated;
grant select, insert, update on table public.business_promo_submissions to authenticated;
grant select, insert on table public.legal_package_requests to authenticated;
grant select, insert on table public.legal_video_calls to authenticated;