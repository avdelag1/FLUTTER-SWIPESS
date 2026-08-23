-- Restrict Google Play transaction records to trusted backend/service-role code.
-- The purchase validation and server notification Edge Functions use the
-- service-role client for these writes; the mobile/web client does not need
-- direct access to this table.

alter table public.google_play_transactions enable row level security;

drop policy if exists "Service role can manage google play transactions"
  on public.google_play_transactions;
drop policy if exists "service_role_manage_google_play_transactions"
  on public.google_play_transactions;

revoke all privileges on table public.google_play_transactions
  from anon, authenticated;
grant all privileges on table public.google_play_transactions
  to service_role;

create policy "service_role_manage_google_play_transactions"
on public.google_play_transactions
for all
to service_role
using (true)
with check (true);
