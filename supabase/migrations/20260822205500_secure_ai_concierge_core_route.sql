alter table public.security_private_config
  add column if not exists ai_concierge_core_slug text;

alter table public.security_private_config enable row level security;
revoke all on table public.security_private_config from anon, authenticated;
grant select, insert, update, delete on table public.security_private_config to service_role;

update public.security_private_config
set ai_concierge_core_slug = 'ai-concierge-core-2d97b32ac1582762956e08e1aa9f880b'
where singleton = true;
