-- Social distribution is opt-in. Public listings remain discoverable through
-- Swipess even when a user never connects a social account.

create table if not exists public.social_connections (
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('instagram','facebook','tiktok','youtube')),
  provider_account_id text,
  provider_account_name text,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  primary key (user_id, provider)
);

-- Provider tokens are server-only. The Edge Functions encrypt values before
-- storing them with SOCIAL_TOKEN_ENCRYPTION_KEY. There are intentionally no
-- client RLS policies for this table.
create table if not exists public.social_connection_tokens (
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('instagram','facebook','tiktok','youtube')),
  access_token_ciphertext text not null,
  refresh_token_ciphertext text,
  expires_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, provider),
  foreign key (user_id, provider)
    references public.social_connections(user_id, provider)
    on delete cascade
);

create table if not exists public.social_distribution_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  auto_publish boolean not null default false,
  providers text[] not null default '{}'::text[],
  updated_at timestamptz not null default now(),
  constraint social_distribution_provider_values check (
    providers <@ array['instagram','facebook','tiktok','youtube']::text[]
  )
);

create table if not exists public.social_publish_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete cascade,
  provider text not null check (provider in ('instagram','facebook','tiktok','youtube')),
  status text not null default 'queued' check (
    status in ('queued','publishing','published','skipped','needs_setup','failed')
  ),
  provider_post_id text,
  error_message text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists social_publish_jobs_user_created_idx
  on public.social_publish_jobs(user_id, created_at desc);
create index if not exists social_publish_jobs_listing_idx
  on public.social_publish_jobs(listing_id);

alter table public.social_connections enable row level security;
alter table public.social_connection_tokens enable row level security;
alter table public.social_distribution_preferences enable row level security;
alter table public.social_publish_jobs enable row level security;

drop policy if exists "social connections read own" on public.social_connections;
create policy "social connections read own"
  on public.social_connections for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "social connections delete own" on public.social_connections;
create policy "social connections delete own"
  on public.social_connections for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "social preferences read own" on public.social_distribution_preferences;
create policy "social preferences read own"
  on public.social_distribution_preferences for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "social preferences insert own" on public.social_distribution_preferences;
create policy "social preferences insert own"
  on public.social_distribution_preferences for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "social preferences update own" on public.social_distribution_preferences;
create policy "social preferences update own"
  on public.social_distribution_preferences for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "social jobs read own" on public.social_publish_jobs;
create policy "social jobs read own"
  on public.social_publish_jobs for select
  to authenticated
  using (auth.uid() = user_id);

comment on table public.social_connections is
  'User-authorized social accounts used by Swipess Organic Auto Boost.';
comment on table public.social_connection_tokens is
  'Server-only encrypted OAuth tokens. Never expose this table to clients.';
comment on table public.social_distribution_preferences is
  'Explicit opt-in preferences for automatic organic social distribution.';
