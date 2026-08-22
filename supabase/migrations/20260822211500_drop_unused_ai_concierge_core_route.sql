alter table public.security_private_config
  drop column if exists ai_concierge_core_slug;

alter table public.security_private_config enable row level security;
revoke all on table public.security_private_config from anon, authenticated;
grant select, insert, update, delete on table public.security_private_config to service_role;
