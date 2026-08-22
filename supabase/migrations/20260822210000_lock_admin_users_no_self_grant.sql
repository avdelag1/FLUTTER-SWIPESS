-- Align consumer-app migration history with the admin portal lock.
-- Authenticated clients may only SELECT admin_users; writes go through
-- super-admin-access (service role).

alter table public.admin_users enable row level security;

drop policy if exists "Admin users can insert admin_users" on public.admin_users;
drop policy if exists "Admin users can update own record" on public.admin_users;
drop policy if exists "Only existing admins can insert admin_users" on public.admin_users;
drop policy if exists "Only existing admins can update admin_users" on public.admin_users;
drop policy if exists "Only existing admins can delete admin_users" on public.admin_users;

revoke all on table public.admin_users from anon;
revoke insert, update, delete, truncate, references, trigger on table public.admin_users from authenticated;
grant select on table public.admin_users to authenticated;
