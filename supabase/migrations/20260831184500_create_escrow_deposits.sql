-- Real backing table for the signed-in Escrow workspace.
-- The Flutter client reads only deposits where the current user is an owner or
-- client. Column-level UPDATE grants prevent participants from reassigning the
-- ownership fields through the Data API.

create table if not exists public.escrow_deposits (
  id uuid primary key default gen_random_uuid(),
  amount numeric(14,2) not null check (amount > 0),
  currency text not null default 'USD' check (char_length(currency) = 3),
  status text not null default 'pending'
    check (status in ('pending','held','released','disputed','cancelled')),
  contract_id uuid null references public.digital_contracts(id) on delete set null,
  client_id uuid not null references auth.users(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  notes text null,
  held_at timestamptz null,
  released_at timestamptz null,
  disputed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint escrow_participants_distinct check (client_id <> owner_id)
);

create index if not exists escrow_deposits_client_created_idx
  on public.escrow_deposits (client_id, created_at desc);
create index if not exists escrow_deposits_owner_created_idx
  on public.escrow_deposits (owner_id, created_at desc);
create index if not exists escrow_deposits_contract_idx
  on public.escrow_deposits (contract_id)
  where contract_id is not null;

alter table public.escrow_deposits enable row level security;

revoke all on public.escrow_deposits from anon;
revoke all on public.escrow_deposits from authenticated;
grant select on public.escrow_deposits to authenticated;
grant insert (amount, currency, status, contract_id, client_id, owner_id, notes)
  on public.escrow_deposits to authenticated;
grant update (status, held_at, released_at, disputed_at, updated_at)
  on public.escrow_deposits to authenticated;

drop policy if exists "escrow participants can read" on public.escrow_deposits;
create policy "escrow participants can read"
on public.escrow_deposits
for select
to authenticated
using ((select auth.uid()) = owner_id or (select auth.uid()) = client_id);

drop policy if exists "escrow participants can create" on public.escrow_deposits;
create policy "escrow participants can create"
on public.escrow_deposits
for insert
to authenticated
with check (
  ((select auth.uid()) = owner_id or (select auth.uid()) = client_id)
  and owner_id <> client_id
  and status = 'pending'
);

drop policy if exists "escrow participants can update state" on public.escrow_deposits;
create policy "escrow participants can update state"
on public.escrow_deposits
for update
to authenticated
using ((select auth.uid()) = owner_id or (select auth.uid()) = client_id)
with check ((select auth.uid()) = owner_id or (select auth.uid()) = client_id);

notify pgrst, 'reload schema';
