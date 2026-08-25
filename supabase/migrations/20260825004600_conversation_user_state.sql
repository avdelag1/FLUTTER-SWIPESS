create table if not exists public.conversation_user_state (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  hidden_at timestamptz,
  archived_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

alter table public.conversation_user_state enable row level security;

grant select, insert, update, delete
  on public.conversation_user_state
  to authenticated;

create policy "conversation state select own"
  on public.conversation_user_state
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.conversations c
      where c.id = conversation_id
        and (
          (select auth.uid()) = c.client_id
          or (select auth.uid()) = c.owner_id
        )
    )
  );

create policy "conversation state insert own"
  on public.conversation_user_state
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.conversations c
      where c.id = conversation_id
        and (
          (select auth.uid()) = c.client_id
          or (select auth.uid()) = c.owner_id
        )
    )
  );

create policy "conversation state update own"
  on public.conversation_user_state
  for update
  to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.conversations c
      where c.id = conversation_id
        and (
          (select auth.uid()) = c.client_id
          or (select auth.uid()) = c.owner_id
        )
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.conversations c
      where c.id = conversation_id
        and (
          (select auth.uid()) = c.client_id
          or (select auth.uid()) = c.owner_id
        )
    )
  );

create policy "conversation state delete own"
  on public.conversation_user_state
  for delete
  to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.conversations c
      where c.id = conversation_id
        and (
          (select auth.uid()) = c.client_id
          or (select auth.uid()) = c.owner_id
        )
    )
  );

create index if not exists conversation_user_state_user_hidden_idx
  on public.conversation_user_state (user_id, hidden_at);
