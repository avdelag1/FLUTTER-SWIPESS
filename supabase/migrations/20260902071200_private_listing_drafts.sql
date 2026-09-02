-- Private listing drafts are intentionally separate from public listings so
-- unfinished work never appears in discovery, maps, or active listing quotas.

create table if not exists public.listing_drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  draft_key text not null,
  kind text not null check (kind in ('create','edit')),
  category text not null,
  source_listing_id uuid null references public.listings(id) on delete cascade,
  step integer not null default 0 check (step >= 0),
  payload jsonb not null default '{}'::jsonb,
  media jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, draft_key)
);

alter table public.listing_drafts enable row level security;

drop policy if exists "listing drafts select own" on public.listing_drafts;
create policy "listing drafts select own"
on public.listing_drafts for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "listing drafts insert own" on public.listing_drafts;
create policy "listing drafts insert own"
on public.listing_drafts for insert to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "listing drafts update own" on public.listing_drafts;
create policy "listing drafts update own"
on public.listing_drafts for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "listing drafts delete own" on public.listing_drafts;
create policy "listing drafts delete own"
on public.listing_drafts for delete to authenticated
using (user_id = (select auth.uid()));

grant select, insert, update, delete on public.listing_drafts to authenticated;
revoke all on public.listing_drafts from anon;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'listing-drafts',
  'listing-drafts',
  false,
  62914560,
  array[
    'image/jpeg','image/png','image/webp','image/heic','image/heif',
    'video/mp4','video/quicktime','video/webm',
    'audio/mpeg','audio/mp4','audio/aac','audio/wav','audio/ogg',
    'application/pdf','application/octet-stream'
  ]::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "listing drafts storage read own" on storage.objects;
create policy "listing drafts storage read own"
on storage.objects for select to authenticated
using (
  bucket_id = 'listing-drafts'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "listing drafts storage insert own" on storage.objects;
create policy "listing drafts storage insert own"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'listing-drafts'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "listing drafts storage update own" on storage.objects;
create policy "listing drafts storage update own"
on storage.objects for update to authenticated
using (
  bucket_id = 'listing-drafts'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'listing-drafts'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "listing drafts storage delete own" on storage.objects;
create policy "listing drafts storage delete own"
on storage.objects for delete to authenticated
using (
  bucket_id = 'listing-drafts'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create index if not exists listing_drafts_user_updated_idx
  on public.listing_drafts (user_id, updated_at desc);
create index if not exists listing_drafts_source_idx
  on public.listing_drafts (source_listing_id)
  where source_listing_id is not null;
