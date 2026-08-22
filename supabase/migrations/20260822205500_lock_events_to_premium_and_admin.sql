-- Remove legacy public-all policies. Events are a Premium/welcome-access
-- feature for consumers; admin writes continue through admin_all_events.

drop policy if exists "Allow public deletes to events" on public.events;
drop policy if exists "Allow public inserts to events" on public.events;
drop policy if exists "Allow public updates to events" on public.events;
drop policy if exists "Events are publicly readable" on public.events;
drop policy if exists public_read_events on public.events;

create policy events_premium_read
on public.events
for select
to authenticated
using (
  is_published = true
  and is_approved = true
  and public.rpc_has_premium_feature_access()
);

-- Admin writes remain governed by the existing admin_all_events policy.
