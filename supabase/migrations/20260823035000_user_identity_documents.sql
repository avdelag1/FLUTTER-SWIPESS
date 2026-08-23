-- User-owned identity documents for the SWIPESS virtual card.
-- Launch behavior: uploads are immediately approved. The status/review fields
-- are intentionally present so moderation can later switch new uploads to
-- pending without redesigning the app data model.

create table if not exists public.user_identity_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  file_name text not null,
  file_path text not null unique,
  document_type text not null default 'other',
  status text not null default 'approved'
    check (status in ('pending', 'approved', 'rejected')),
  file_size bigint not null default 0,
  mime_type text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  review_note text
);

create index if not exists user_identity_documents_user_id_idx
  on public.user_identity_documents(user_id);
create index if not exists user_identity_documents_status_idx
  on public.user_identity_documents(status);
create index if not exists user_identity_documents_created_at_idx
  on public.user_identity_documents(created_at desc);

alter table public.user_identity_documents enable row level security;

drop policy if exists "Users can view own identity documents"
  on public.user_identity_documents;
create policy "Users can view own identity documents"
  on public.user_identity_documents
  for select to authenticated
  using (auth.uid() = user_id or is_admin_user(auth.uid()));

drop policy if exists "Users can upload own identity documents"
  on public.user_identity_documents;
create policy "Users can upload own identity documents"
  on public.user_identity_documents
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own identity documents"
  on public.user_identity_documents;
create policy "Users can delete own identity documents"
  on public.user_identity_documents
  for delete to authenticated
  using (auth.uid() = user_id or is_admin_user(auth.uid()));

drop policy if exists "Admins can review identity documents"
  on public.user_identity_documents;
create policy "Admins can review identity documents"
  on public.user_identity_documents
  for update to authenticated
  using (is_admin_user(auth.uid()))
  with check (is_admin_user(auth.uid()));

drop policy if exists "Admins can read identity document files"
  on storage.objects;
create policy "Admins can read identity document files"
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'legal-documents'
    and is_admin_user(auth.uid())
  );
