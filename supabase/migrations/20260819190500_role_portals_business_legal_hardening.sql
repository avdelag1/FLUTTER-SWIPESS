-- Role portal / business + legal dashboard hardening.
-- Applied to production through Supabase MCP before this file was committed.

-- Align the live business-promo table with the Flutter app while preserving
-- legacy business_name/business_type/owner_name/etc. columns.
alter table public.business_promo_submissions
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists title text,
  add column if not exists event_type text,
  add column if not exists location text,
  add column if not exists contact_name text,
  add column if not exists contact_phone text,
  add column if not exists image_url text,
  add column if not exists event_date text,
  add column if not exists promo_type text,
  add column if not exists updated_at timestamptz not null default now();

update public.business_promo_submissions
set
  title = coalesce(nullif(title, ''), business_name),
  event_type = coalesce(nullif(event_type, ''), business_type),
  contact_name = coalesce(nullif(contact_name, ''), owner_name),
  contact_phone = coalesce(nullif(contact_phone, ''), whatsapp),
  image_url = coalesce(nullif(image_url, ''), photo_urls[1]),
  promo_type = coalesce(nullif(promo_type, ''), business_type),
  updated_at = coalesce(updated_at, created_at, now())
where title is null
   or event_type is null
   or contact_name is null
   or contact_phone is null
   or image_url is null
   or promo_type is null;

alter table public.business_promo_submissions enable row level security;

drop policy if exists "public_insert_promo" on public.business_promo_submissions;
drop policy if exists "Users can insert own promo" on public.business_promo_submissions;
drop policy if exists "Users can view own promo" on public.business_promo_submissions;
drop policy if exists "Users can update own promo" on public.business_promo_submissions;
drop policy if exists "Admins can update promo" on public.business_promo_submissions;

create policy "Users can insert own promo"
on public.business_promo_submissions
for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can view own promo"
on public.business_promo_submissions
for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can update own promo"
on public.business_promo_submissions
for update to authenticated
using (
  (select auth.uid()) = user_id
  and coalesce(status, 'pending') in ('draft', 'pending', 'rejected')
)
with check ((select auth.uid()) = user_id);

create policy "Admins can update promo"
on public.business_promo_submissions
for update to authenticated
using (public.is_admin_user((select auth.uid())))
with check (public.is_admin_user((select auth.uid())));

revoke insert, update, delete on table public.business_promo_submissions from anon;
grant select, insert, update on table public.business_promo_submissions to authenticated;

-- Let admins operate the legal queue without weakening user/lawyer ownership.
drop policy if exists "Admins can view package requests" on public.legal_package_requests;
drop policy if exists "Admins can update package requests" on public.legal_package_requests;
create policy "Admins can view package requests"
on public.legal_package_requests
for select to authenticated
using (public.is_admin_user((select auth.uid())));
create policy "Admins can update package requests"
on public.legal_package_requests
for update to authenticated
using (public.is_admin_user((select auth.uid())))
with check (public.is_admin_user((select auth.uid())));

drop policy if exists "Admins can view legal video calls" on public.legal_video_calls;
drop policy if exists "Admins can update legal video calls" on public.legal_video_calls;
create policy "Admins can view legal video calls"
on public.legal_video_calls
for select to authenticated
using (public.is_admin_user((select auth.uid())));
create policy "Admins can update legal video calls"
on public.legal_video_calls
for update to authenticated
using (public.is_admin_user((select auth.uid())))
with check (public.is_admin_user((select auth.uid())));

revoke all on table public.legal_package_requests from anon;
revoke all on table public.legal_video_calls from anon;
grant select, insert, update on table public.legal_package_requests to authenticated;
grant select, insert, update on table public.legal_video_calls to authenticated;