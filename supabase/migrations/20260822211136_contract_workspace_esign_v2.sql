-- Swipess Sign / document workspace
-- Canonical repo copy of the production migration applied on 2026-08-22.

alter table public.digital_contracts
  add column if not exists content text,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists owner_signature text,
  add column if not exists client_signature text,
  add column if not exists owner_signed_at timestamptz,
  add column if not exists client_signed_at timestamptz,
  add column if not exists sent_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists counterparty_label text,
  add column if not exists document_hash text,
  add column if not exists version integer not null default 1;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conrelid = 'public.digital_contracts'::regclass
      and conname = 'digital_contracts_template_type_check'
  ) then
    alter table public.digital_contracts
      drop constraint digital_contracts_template_type_check;
  end if;
end $$;

alter table public.digital_contracts alter column file_path drop not null;
alter table public.digital_contracts alter column file_name drop not null;
alter table public.digital_contracts alter column file_size drop not null;

-- Legacy installs used enums here. The workspace needs extensible templates and states.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='digital_contracts'
      and column_name='contract_type' and data_type <> 'text'
  ) then
    alter table public.digital_contracts
      alter column contract_type type text using contract_type::text;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='digital_contracts'
      and column_name='status' and data_type <> 'text'
  ) then
    alter table public.digital_contracts
      alter column status drop default;
    alter table public.digital_contracts
      alter column status type text using status::text;
  end if;
end $$;

update public.digital_contracts
set created_by = coalesce(created_by, owner_id),
    content = coalesce(content, terms_and_conditions),
    status = case
      when status in ('completed','cancelled','disputed','signed_by_owner','signed_by_client') then status
      when status = 'pending' then 'draft'
      else coalesce(status, 'draft')
    end
where created_by is null
   or content is null
   or status is null
   or status = 'pending';

alter table public.digital_contracts alter column status set default 'draft';
alter table public.digital_contracts alter column status set not null;

create table if not exists public.contract_signatures (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.digital_contracts(id) on delete cascade,
  signer_id uuid not null,
  signature_data text not null,
  signature_type text not null default 'drawn',
  document_hash text not null,
  user_agent text,
  signed_at timestamptz not null default now(),
  unique (contract_id, signer_id)
);

create table if not exists public.contract_events (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.digital_contracts(id) on delete cascade,
  actor_id uuid,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_contract_events_contract_created
  on public.contract_events(contract_id, created_at desc);
create index if not exists idx_contract_signatures_contract
  on public.contract_signatures(contract_id);
create index if not exists idx_digital_contracts_owner_updated
  on public.digital_contracts(owner_id, updated_at desc);
create index if not exists idx_digital_contracts_client_updated
  on public.digital_contracts(client_id, updated_at desc);

alter table public.digital_contracts enable row level security;
alter table public.contract_signatures enable row level security;
alter table public.contract_events enable row level security;

-- Replace broad legacy contract policies. Users read only documents they are party to;
-- writes after creation go through audited SECURITY DEFINER RPCs below.
drop policy if exists "Admins can view all contracts" on public.digital_contracts;
drop policy if exists "Contract parties can update status" on public.digital_contracts;
drop policy if exists "Legal team can view contracts" on public.digital_contracts;
drop policy if exists "Owners can create contracts" on public.digital_contracts;
drop policy if exists "Users can view contracts they are involved in" on public.digital_contracts;
drop policy if exists legal_view_contracts on public.digital_contracts;
drop policy if exists digital_contracts_admin_select on public.digital_contracts;
drop policy if exists digital_contracts_owner_insert on public.digital_contracts;
drop policy if exists digital_contracts_parties_select on public.digital_contracts;

create policy digital_contracts_parties_select
on public.digital_contracts for select to authenticated
using (
  auth.uid() = created_by
  or auth.uid() = owner_id
  or auth.uid() = client_id
);

create policy digital_contracts_owner_insert
on public.digital_contracts for insert to authenticated
with check (
  auth.uid() = created_by
  and auth.uid() = owner_id
  and (client_id is null or client_id = auth.uid())
);

create policy digital_contracts_admin_select
on public.digital_contracts for select to authenticated
using (
  has_admin_role('legal')
  or has_admin_role('super_admin')
  or exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid() and ur.role = 'admin'
  )
);

drop policy if exists contract_signatures_parties_select on public.contract_signatures;
create policy contract_signatures_parties_select
on public.contract_signatures for select to authenticated
using (
  exists (
    select 1 from public.digital_contracts c
    where c.id = contract_signatures.contract_id
      and (auth.uid() = c.created_by or auth.uid() = c.owner_id or auth.uid() = c.client_id)
  )
);

drop policy if exists contract_events_parties_select on public.contract_events;
create policy contract_events_parties_select
on public.contract_events for select to authenticated
using (
  exists (
    select 1 from public.digital_contracts c
    where c.id = contract_events.contract_id
      and (auth.uid() = c.created_by or auth.uid() = c.owner_id or auth.uid() = c.client_id)
  )
);

create or replace function public.log_contract_created_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.contract_events(contract_id, actor_id, event_type, metadata)
  values (new.id, new.created_by, 'created', jsonb_build_object('template_type', new.template_type, 'version', new.version));
  return new;
end;
$$;

drop trigger if exists trg_contract_created_event on public.digital_contracts;
create trigger trg_contract_created_event
after insert on public.digital_contracts
for each row execute function public.log_contract_created_event();

create or replace function public.rpc_resolve_contract_counterparty(p_query text)
returns table(user_id uuid, display_name text, username text)
language sql
security definer
set search_path = public, auth, pg_temp
as $$
  with input as (
    select trim(p_query) as q, lower(trim(leading '@' from trim(p_query))) as normalized
  )
  select p.id,
         coalesce(nullif(trim(p.full_name),''), nullif(trim(p.username),''), 'Swipess user') as display_name,
         p.username
  from public.profiles p, input i
  where p.id <> auth.uid()
    and coalesce(p.is_active, true)
    and not coalesce(p.is_banned, false)
    and not coalesce(p.is_blocked, false)
    and p.deleted_at is null
    and (
      (position('@' in i.q) > 1 and lower(coalesce(p.email,'')) = lower(i.q))
      or lower(coalesce(p.username,'')) = i.normalized
      or lower(coalesce(p.full_name,'')) = lower(i.q)
    )
  order by
    case
      when position('@' in i.q) > 1 and lower(coalesce(p.email,'')) = lower(i.q) then 0
      when lower(coalesce(p.username,'')) = i.normalized then 1
      else 2
    end,
    p.updated_at desc nulls last
  limit 5;
$$;

create or replace function public.rpc_update_contract_draft(
  p_contract_id uuid,
  p_title text,
  p_content text,
  p_metadata jsonb default '{}'::jsonb
)
returns public.digital_contracts
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  c public.digital_contracts;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if length(coalesce(p_content,'')) > 250000 then raise exception 'Document is too large'; end if;

  select * into c from public.digital_contracts where id = p_contract_id for update;
  if not found then raise exception 'Contract not found'; end if;
  if auth.uid() <> c.owner_id and auth.uid() <> c.created_by then raise exception 'Only the creator can edit this document'; end if;
  if c.status <> 'draft' then raise exception 'Sent or signed documents are locked. Duplicate it to make changes.'; end if;

  update public.digital_contracts
  set title = coalesce(nullif(trim(p_title),''), title),
      content = coalesce(p_content,''),
      terms_and_conditions = coalesce(p_content,''),
      metadata = coalesce(p_metadata,'{}'::jsonb),
      document_hash = null,
      version = version + 1,
      updated_at = now()
  where id = p_contract_id
  returning * into c;

  insert into public.contract_events(contract_id, actor_id, event_type, metadata)
  values (c.id, auth.uid(), 'updated', jsonb_build_object('version', c.version));
  return c;
end;
$$;

create or replace function public.rpc_share_contract_with_user(
  p_contract_id uuid,
  p_client_id uuid
)
returns public.digital_contracts
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  c public.digital_contracts;
  recipient public.profiles;
  h text;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_client_id is null or p_client_id = auth.uid() then raise exception 'Choose another Swipess user'; end if;

  select * into c from public.digital_contracts where id = p_contract_id for update;
  if not found then raise exception 'Contract not found'; end if;
  if auth.uid() <> c.owner_id and auth.uid() <> c.created_by then raise exception 'Only the creator can send this document'; end if;
  if c.client_signed_at is not null or c.status in ('completed','signed','fully_signed','cancelled') then
    raise exception 'This document can no longer be reassigned';
  end if;

  select * into recipient from public.profiles
  where id = p_client_id
    and coalesce(is_active,true)
    and not coalesce(is_banned,false)
    and not coalesce(is_blocked,false)
    and deleted_at is null;
  if not found then raise exception 'Recipient is unavailable'; end if;

  h := encode(extensions.digest(convert_to(coalesce(c.content, c.terms_and_conditions, ''), 'UTF8'), 'sha256'), 'hex');

  update public.digital_contracts
  set client_id = p_client_id,
      counterparty_label = coalesce(nullif(trim(recipient.full_name),''), nullif(trim(recipient.username),''), 'Swipess user'),
      status = case when owner_signed_at is null then 'sent' else 'signed_by_owner' end,
      sent_at = coalesce(sent_at, now()),
      document_hash = h,
      updated_at = now()
  where id = c.id
  returning * into c;

  insert into public.contract_events(contract_id, actor_id, event_type, metadata)
  values (c.id, auth.uid(), 'sent', jsonb_build_object('recipient_id', p_client_id, 'version', c.version));

  insert into public.notifications(user_id, notification_type, title, message, link_url, related_user_id, metadata)
  values (
    p_client_id,
    'contract_pending',
    'Document ready to sign',
    format('%s sent you "%s" for review and signature.', coalesce(nullif(trim((select full_name from public.profiles where id=auth.uid())),''),'A Swipess user'), c.title),
    '/client/contracts',
    auth.uid(),
    jsonb_build_object('contract_id', c.id)
  );

  return c;
end;
$$;

create or replace function public.rpc_sign_contract(
  p_contract_id uuid,
  p_signature_data text,
  p_signature_type text default 'drawn',
  p_user_agent text default null
)
returns public.digital_contracts
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  c public.digital_contracts;
  signer uuid := auth.uid();
  h text;
  next_status text;
  other_id uuid;
begin
  if signer is null then raise exception 'Not authenticated'; end if;
  if coalesce(length(p_signature_data),0) < 20 or length(p_signature_data) > 750000 then raise exception 'Invalid signature payload'; end if;
  if p_signature_type not in ('drawn','typed','uploaded') then raise exception 'Invalid signature type'; end if;

  select * into c from public.digital_contracts where id = p_contract_id for update;
  if not found then raise exception 'Contract not found'; end if;
  if signer <> c.owner_id and signer <> c.client_id then raise exception 'You are not a signer on this document'; end if;
  if c.status in ('cancelled','disputed') then raise exception 'This document cannot be signed'; end if;

  h := encode(extensions.digest(convert_to(coalesce(c.content, c.terms_and_conditions, ''), 'UTF8'), 'sha256'), 'hex');
  if c.document_hash is not null and c.document_hash <> h then
    raise exception 'Document changed after it was prepared for signature';
  end if;

  if signer = c.owner_id then
    if c.owner_signed_at is not null then raise exception 'You already signed this document'; end if;
    next_status := case when c.client_signed_at is not null then 'completed' else 'signed_by_owner' end;
    update public.digital_contracts
    set owner_signature = p_signature_data,
        owner_signed_at = now(),
        status = next_status,
        document_hash = h,
        completed_at = case when next_status='completed' then now() else completed_at end,
        updated_at = now()
    where id = c.id returning * into c;
    other_id := c.client_id;
  else
    if c.client_signed_at is not null then raise exception 'You already signed this document'; end if;
    next_status := case when c.owner_signed_at is not null then 'completed' else 'signed_by_client' end;
    update public.digital_contracts
    set client_signature = p_signature_data,
        client_signed_at = now(),
        status = next_status,
        document_hash = h,
        completed_at = case when next_status='completed' then now() else completed_at end,
        updated_at = now()
    where id = c.id returning * into c;
    other_id := c.owner_id;
  end if;

  insert into public.contract_signatures(contract_id, signer_id, signature_data, signature_type, document_hash, user_agent)
  values (c.id, signer, p_signature_data, p_signature_type, h, left(coalesce(p_user_agent,''),300))
  on conflict (contract_id, signer_id) do nothing;

  insert into public.contract_events(contract_id, actor_id, event_type, metadata)
  values (c.id, signer, 'signed', jsonb_build_object('signature_type', p_signature_type, 'document_hash', h, 'status', c.status));

  if other_id is not null and other_id <> signer then
    insert into public.notifications(user_id, notification_type, title, message, link_url, related_user_id, metadata)
    values (
      other_id,
      'contract_signed',
      case when c.status='completed' then 'Document fully signed' else 'Document signed' end,
      case when c.status='completed'
        then format('"%s" is fully signed and stored in your contract vault.', c.title)
        else format('The other party signed "%s".', c.title)
      end,
      '/client/contracts',
      signer,
      jsonb_build_object('contract_id', c.id, 'status', c.status)
    );
  end if;

  return c;
end;
$$;

create or replace function public.rpc_cancel_contract(p_contract_id uuid)
returns public.digital_contracts
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c public.digital_contracts;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select * into c from public.digital_contracts where id=p_contract_id for update;
  if not found then raise exception 'Contract not found'; end if;
  if auth.uid() <> c.owner_id and auth.uid() <> c.created_by then raise exception 'Only the creator can cancel this document'; end if;
  if c.status in ('completed','signed','fully_signed') then raise exception 'A fully signed document cannot be cancelled here'; end if;

  update public.digital_contracts
  set status='cancelled', cancelled_at=now(), updated_at=now()
  where id=c.id returning * into c;

  insert into public.contract_events(contract_id, actor_id, event_type)
  values (c.id, auth.uid(), 'cancelled');
  return c;
end;
$$;

revoke all on function public.rpc_resolve_contract_counterparty(text) from public, anon;
revoke all on function public.rpc_update_contract_draft(uuid,text,text,jsonb) from public, anon;
revoke all on function public.rpc_share_contract_with_user(uuid,uuid) from public, anon;
revoke all on function public.rpc_sign_contract(uuid,text,text,text) from public, anon;
revoke all on function public.rpc_cancel_contract(uuid) from public, anon;

grant execute on function public.rpc_resolve_contract_counterparty(text) to authenticated;
grant execute on function public.rpc_update_contract_draft(uuid,text,text,jsonb) to authenticated;
grant execute on function public.rpc_share_contract_with_user(uuid,uuid) to authenticated;
grant execute on function public.rpc_sign_contract(uuid,text,text,text) to authenticated;
grant execute on function public.rpc_cancel_contract(uuid) to authenticated;

revoke insert, update, delete on public.contract_signatures from anon, authenticated;
revoke insert, update, delete on public.contract_events from anon, authenticated;
