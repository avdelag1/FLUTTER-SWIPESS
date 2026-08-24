-- Harden lawyer intake mutations and expose a privacy-limited mobile queue.
-- Lawyers may claim an unassigned pending request, but may only mutate requests
-- assigned to themselves after that point. Unassigned queue rows omit direct
-- contact details until assignment.

create or replace function public.rpc_lawyer_offer_legal_intake(
  p_id uuid,
  p_package_id uuid,
  p_notes text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_lawyer public.lawyer_users%rowtype;
  v_pkg public.legal_service_packages%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_lawyer
  from public.lawyer_users
  where user_id = auth.uid() and is_active = true
  limit 1;
  if v_lawyer.id is null then
    raise exception 'Active lawyer access required' using errcode = '42501';
  end if;

  if p_package_id is not null then
    select * into v_pkg
    from public.legal_service_packages
    where id = p_package_id and is_active = true;
    if v_pkg.id is null then
      raise exception 'Active legal package not found';
    end if;
  end if;

  update public.legal_package_requests
  set
    status = 'offered',
    assigned_lawyer_id = v_lawyer.id,
    package_id = coalesce(v_pkg.id, package_id),
    package_name = coalesce(v_pkg.name, package_name),
    package_category = coalesce(v_pkg.category, package_category),
    quoted_price = coalesce(v_pkg.price, quoted_price),
    lawyer_notes = nullif(left(trim(coalesce(p_notes, '')), 5000), ''),
    decline_reason = null,
    offered_at = now(),
    expires_at = now() + interval '48 hours',
    updated_at = now()
  where id = p_id
    and status in ('pending', 'offered')
    and (assigned_lawyer_id is null or assigned_lawyer_id = v_lawyer.id);

  if not found then
    raise exception 'Intake is already assigned or no longer waiting for an offer';
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
set search_path = public, pg_temp
as $$
declare
  v_lawyer_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select id into v_lawyer_id
  from public.lawyer_users
  where user_id = auth.uid() and is_active = true
  limit 1;
  if v_lawyer_id is null then
    raise exception 'Active lawyer access required' using errcode = '42501';
  end if;

  update public.legal_package_requests
  set
    status = 'declined',
    decline_reason = nullif(left(trim(coalesce(p_reason, '')), 2000), ''),
    updated_at = now()
  where id = p_id
    and assigned_lawyer_id = v_lawyer_id
    and status in ('pending', 'offered');

  if not found then
    raise exception 'Only your assigned intake can be declined';
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
set search_path = public, pg_temp
as $$
declare
  v_lawyer_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select id into v_lawyer_id
  from public.lawyer_users
  where user_id = auth.uid() and is_active = true
  limit 1;
  if v_lawyer_id is null then
    raise exception 'Active lawyer access required' using errcode = '42501';
  end if;
  if p_consult_at is null or p_consult_at < now() + interval '5 minutes' then
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
    raise exception 'Schedule only your paid intake';
  end if;
end;
$$;

create or replace function public.update_legal_request_workflow(
  p_request_id uuid,
  p_status text,
  p_lawyer_notes text default null
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_lawyer_id uuid;
  v_is_admin boolean := false;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_status not in ('pending','reviewing','in_progress','completed','closed','cancelled') then
    raise exception 'Invalid legal request status' using errcode = '22023';
  end if;

  v_is_admin := public.is_admin_user(v_uid);
  if not v_is_admin then
    select id into v_lawyer_id
    from public.lawyer_users
    where user_id = v_uid and is_active = true
    limit 1;
    if v_lawyer_id is null then
      raise exception 'Insufficient privilege' using errcode = '42501';
    end if;
  end if;

  update public.legal_package_requests
     set status = p_status,
         lawyer_notes = case
           when p_lawyer_notes is null then lawyer_notes
           else left(trim(p_lawyer_notes), 5000)
         end,
         updated_at = now()
   where id = p_request_id
     and (v_is_admin or assigned_lawyer_id = v_lawyer_id);
  return found;
end;
$$;

create or replace function public.app_lawyer_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_lawyer record;
  v_summary jsonb;
  v_available jsonb;
  v_requests jsonb;
  v_cases jsonb;
  v_appointments jsonb;
  v_transactions jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select lu.id as lawyer_id, lu.full_name, lu.email, lu.bar_number,
         lu.specialization, lu.commission_rate, lu.is_available, lu.is_active
    into v_lawyer
  from public.lawyer_users lu
  where lu.user_id = v_uid
  limit 1;

  if v_lawyer.lawyer_id is null or not coalesce(v_lawyer.is_active, false) then
    raise exception 'Active lawyer workspace required' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'available_requests', (select count(*) from public.legal_package_requests r where r.assigned_lawyer_id is null and r.status = 'pending'),
    'pending_requests', (select count(*) from public.legal_package_requests r where r.assigned_lawyer_id = v_lawyer.lawyer_id and r.status in ('pending','offered','accepted','paid','scheduled')),
    'active_clients', (select count(*) from public.lawyer_clients c where c.lawyer_id = v_lawyer.lawyer_id and coalesce(c.status, 'active') = 'active'),
    'open_cases', (select count(*) from public.lawyer_cases c where c.lawyer_id = v_lawyer.lawyer_id and c.status not in ('resolved','closed','cancelled')),
    'upcoming_appointments', (select count(*) from public.lawyer_appointments a where a.lawyer_id = v_lawyer.lawyer_id and a.scheduled_at >= now() and coalesce(a.status,'scheduled') not in ('cancelled','completed')),
    'gross_earned_30d', coalesce((select sum(t.total_earned) from public.lawyer_transactions t where t.lawyer_id = v_lawyer.lawyer_id and t.created_at >= now() - interval '30 days'), 0),
    'commission_30d', coalesce((select sum(t.commission_amount) from public.lawyer_transactions t where t.lawyer_id = v_lawyer.lawyer_id and t.created_at >= now() - interval '30 days'), 0),
    'templates_available', (select count(*) from public.lawyer_templates t where t.is_active = true and (t.created_by is null or t.created_by = v_lawyer.lawyer_id)),
    'service_packages_available', (select count(*) from public.legal_service_packages p where p.is_active = true)
  ) into v_summary;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_available
  from (
    select r.id, r.package_id, r.package_name, r.package_category,
           r.quoted_price, r.situation, r.full_name, r.preferred_contact,
           r.request_type, r.city, r.created_at
    from public.legal_package_requests r
    where r.assigned_lawyer_id is null
      and r.status = 'pending'
    order by r.created_at asc
    limit 30
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_requests
  from (
    select r.id, r.package_id, r.package_name, r.package_category,
           r.quoted_price, r.situation, r.full_name, r.preferred_contact,
           r.status, r.city, r.lawyer_notes, r.offered_at, r.paid_at,
           r.consult_at, r.expires_at, r.created_at
    from public.legal_package_requests r
    where r.assigned_lawyer_id = v_lawyer.lawyer_id
    order by r.created_at desc
    limit 30
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_cases
  from (
    select c.id, c.title, c.case_number, c.category, c.status, c.priority,
           c.opened_at, c.closed_at, lc.full_name as client_name
    from public.lawyer_cases c
    left join public.lawyer_clients lc on lc.id = c.client_id
    where c.lawyer_id = v_lawyer.lawyer_id
    order by c.updated_at desc
    limit 15
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_appointments
  from (
    select a.id, a.title, a.appointment_type, a.scheduled_at,
           a.duration_minutes, a.location, a.status, lc.full_name as client_name
    from public.lawyer_appointments a
    left join public.lawyer_clients lc on lc.id = a.client_id
    where a.lawyer_id = v_lawyer.lawyer_id
      and a.scheduled_at >= now() - interval '1 day'
    order by a.scheduled_at asc
    limit 15
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_transactions
  from (
    select t.id, t.client_name, t.case_description, t.total_earned,
           t.commission_rate, t.commission_amount, t.created_at
    from public.lawyer_transactions t
    where t.lawyer_id = v_lawyer.lawyer_id
    order by t.created_at desc
    limit 15
  ) x;

  return jsonb_build_object(
    'lawyer', jsonb_build_object(
      'lawyer_id', v_lawyer.lawyer_id,
      'full_name', v_lawyer.full_name,
      'email', v_lawyer.email,
      'bar_number', v_lawyer.bar_number,
      'specialization', v_lawyer.specialization,
      'commission_rate', v_lawyer.commission_rate,
      'is_available', v_lawyer.is_available
    ),
    'summary', v_summary,
    'available_requests', v_available,
    'requests', v_requests,
    'cases', v_cases,
    'appointments', v_appointments,
    'recent_transactions', v_transactions
  );
end;
$$;

revoke all on function public.rpc_lawyer_offer_legal_intake(uuid, uuid, text) from public;
revoke all on function public.rpc_lawyer_offer_legal_intake(uuid, uuid, text) from anon;
grant execute on function public.rpc_lawyer_offer_legal_intake(uuid, uuid, text) to authenticated;
grant execute on function public.rpc_lawyer_offer_legal_intake(uuid, uuid, text) to service_role;

revoke all on function public.rpc_lawyer_decline_legal_intake(uuid, text) from public;
revoke all on function public.rpc_lawyer_decline_legal_intake(uuid, text) from anon;
grant execute on function public.rpc_lawyer_decline_legal_intake(uuid, text) to authenticated;
grant execute on function public.rpc_lawyer_decline_legal_intake(uuid, text) to service_role;

revoke all on function public.rpc_lawyer_schedule_legal_consult(uuid, timestamptz) from public;
revoke all on function public.rpc_lawyer_schedule_legal_consult(uuid, timestamptz) from anon;
grant execute on function public.rpc_lawyer_schedule_legal_consult(uuid, timestamptz) to authenticated;
grant execute on function public.rpc_lawyer_schedule_legal_consult(uuid, timestamptz) to service_role;

revoke all on function public.lawyer_self_update_safe(uuid, text, boolean, numeric) from public;
revoke all on function public.lawyer_self_update_safe(uuid, text, boolean, numeric) from anon;
grant execute on function public.lawyer_self_update_safe(uuid, text, boolean, numeric) to authenticated;
grant execute on function public.lawyer_self_update_safe(uuid, text, boolean, numeric) to service_role;
