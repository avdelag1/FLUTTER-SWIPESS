-- Legal intake: request first, lawyer offers a package, client pays, then a
-- booked consult. No cold-ring. Writes go through RPCs so clients cannot
-- self-mark paid except via rpc_client_confirm_legal_payment.

alter table public.legal_package_requests
  add column if not exists city text,
  add column if not exists assigned_lawyer_id uuid,
  add column if not exists offered_at timestamptz,
  add column if not exists paid_at timestamptz,
  add column if not exists consult_at timestamptz,
  add column if not exists expires_at timestamptz,
  add column if not exists decline_reason text,
  add column if not exists payment_link text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'legal_package_requests_assigned_lawyer_fkey'
  ) then
    alter table public.legal_package_requests
      add constraint legal_package_requests_assigned_lawyer_fkey
      foreign key (assigned_lawyer_id) references public.lawyer_users(id)
      on delete set null;
  end if;
end $$;

create index if not exists legal_package_requests_status_idx
  on public.legal_package_requests (status, created_at desc);

update public.legal_package_requests
set expires_at = created_at + interval '48 hours'
where expires_at is null;

create or replace function public.rpc_submit_legal_intake(
  p_package_id uuid,
  p_package_name text,
  p_package_category text,
  p_quoted_price numeric,
  p_situation text,
  p_city text,
  p_full_name text,
  p_email text,
  p_phone text,
  p_preferred_contact text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if length(trim(coalesce(p_situation, ''))) < 12 then
    raise exception 'Please describe your situation in a bit more detail';
  end if;
  if length(trim(coalesce(p_package_category, ''))) < 2 then
    raise exception 'Choose a legal category';
  end if;

  insert into public.legal_package_requests (
    requested_by, package_id, package_name, package_category, quoted_price,
    situation, city, full_name, email, phone, preferred_contact,
    request_type, status, source, expires_at
  ) values (
    v_uid, p_package_id, nullif(trim(p_package_name), ''),
    trim(p_package_category), p_quoted_price,
    trim(p_situation), nullif(trim(p_city), ''),
    nullif(trim(p_full_name), ''), nullif(trim(p_email), ''),
    nullif(trim(p_phone), ''), coalesce(nullif(trim(p_preferred_contact), ''), 'phone'),
    'intake', 'pending', 'swipess_app', now() + interval '48 hours'
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.rpc_lawyer_offer_legal_intake(
  p_id uuid,
  p_package_id uuid,
  p_notes text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lawyer public.lawyer_users%rowtype;
  v_pkg public.legal_service_packages%rowtype;
begin
  select * into v_lawyer
  from public.lawyer_users
  where user_id = auth.uid() and is_active = true
  limit 1;
  if v_lawyer.id is null then
    raise exception 'Active lawyer access required';
  end if;

  if p_package_id is not null then
    select * into v_pkg from public.legal_service_packages where id = p_package_id;
  end if;

  update public.legal_package_requests
  set
    status = 'offered',
    assigned_lawyer_id = v_lawyer.id,
    package_id = coalesce(v_pkg.id, package_id),
    package_name = coalesce(v_pkg.name, package_name),
    package_category = coalesce(v_pkg.category, package_category),
    quoted_price = coalesce(v_pkg.price, quoted_price),
    lawyer_notes = nullif(trim(p_notes), ''),
    offered_at = now(),
    expires_at = now() + interval '48 hours',
    updated_at = now()
  where id = p_id
    and status in ('pending', 'offered');

  if not found then
    raise exception 'Intake is no longer waiting for an offer';
  end if;
end;
$$;

create or replace function public.rpc_lawyer_decline_legal_intake(
  p_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lawyer_id uuid;
begin
  select id into v_lawyer_id
  from public.lawyer_users
  where user_id = auth.uid() and is_active = true
  limit 1;
  if v_lawyer_id is null then
    raise exception 'Active lawyer access required';
  end if;

  update public.legal_package_requests
  set
    status = 'declined',
    assigned_lawyer_id = coalesce(assigned_lawyer_id, v_lawyer_id),
    decline_reason = nullif(trim(p_reason), ''),
    updated_at = now()
  where id = p_id
    and status in ('pending', 'offered');

  if not found then
    raise exception 'Intake cannot be declined';
  end if;
end;
$$;

create or replace function public.rpc_client_cancel_legal_intake(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.legal_package_requests
  set status = 'cancelled', updated_at = now()
  where id = p_id
    and requested_by = auth.uid()
    and status in ('pending', 'offered');
  if not found then
    raise exception 'This request can no longer be cancelled';
  end if;
end;
$$;

create or replace function public.rpc_client_confirm_legal_payment(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.legal_package_requests
  set status = 'paid', paid_at = now(), updated_at = now()
  where id = p_id
    and requested_by = auth.uid()
    and status = 'offered';
  if not found then
    raise exception 'Pay only after a lawyer has accepted with a price';
  end if;
end;
$$;

create or replace function public.rpc_lawyer_schedule_legal_consult(
  p_id uuid,
  p_consult_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lawyer_id uuid;
begin
  select id into v_lawyer_id
  from public.lawyer_users
  where user_id = auth.uid() and is_active = true
  limit 1;
  if v_lawyer_id is null then
    raise exception 'Active lawyer access required';
  end if;
  if p_consult_at is null or p_consult_at < now() - interval '5 minutes' then
    raise exception 'Choose a future consult time';
  end if;

  update public.legal_package_requests
  set
    status = 'scheduled',
    consult_at = p_consult_at,
    updated_at = now()
  where id = p_id
    and assigned_lawyer_id = v_lawyer_id
    and status in ('paid', 'scheduled');

  if not found then
    raise exception 'Schedule only after the client has paid';
  end if;
end;
$$;

revoke all on function public.rpc_submit_legal_intake(uuid,text,text,numeric,text,text,text,text,text,text) from public;
revoke all on function public.rpc_lawyer_offer_legal_intake(uuid,uuid,text) from public;
revoke all on function public.rpc_lawyer_decline_legal_intake(uuid,text) from public;
revoke all on function public.rpc_client_cancel_legal_intake(uuid) from public;
revoke all on function public.rpc_client_confirm_legal_payment(uuid) from public;
revoke all on function public.rpc_lawyer_schedule_legal_consult(uuid,timestamptz) from public;

grant execute on function public.rpc_submit_legal_intake(uuid,text,text,numeric,text,text,text,text,text,text) to authenticated;
grant execute on function public.rpc_lawyer_offer_legal_intake(uuid,uuid,text) to authenticated;
grant execute on function public.rpc_lawyer_decline_legal_intake(uuid,text) to authenticated;
grant execute on function public.rpc_client_cancel_legal_intake(uuid) to authenticated;
grant execute on function public.rpc_client_confirm_legal_payment(uuid) to authenticated;
grant execute on function public.rpc_lawyer_schedule_legal_consult(uuid,timestamptz) to authenticated;
