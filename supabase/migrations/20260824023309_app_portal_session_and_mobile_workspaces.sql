-- App-facing role/session contracts shared by Flutter with the Admin, Business,
-- Lawyer and territory backends. Privileged memberships are always resolved
-- from auth.uid(); the client never supplies a trusted role or user id.

create or replace function public.app_session_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_profile record;
  v_admin record;
  v_business record;
  v_lawyer record;
  v_city record;
  v_territory_staff record;
  v_features jsonb;
  v_platform jsonb;
  v_default_features constant jsonb := jsonb_build_object(
    'properties', true,
    'workers', true,
    'yachts', true,
    'events', true,
    'legal', true,
    'local_id', true,
    'motorcycles', true,
    'bicycles', true,
    'premium', true,
    'tokens', true,
    'ai', true,
    'seekers', true
  );
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select p.id, p.email, p.full_name, p.city, p.country, p.active_mode,
         p.is_active, p.is_banned, p.is_suspended, p.is_blocked,
         p.verified, p.onboarding_completed
    into v_profile
  from public.profiles p
  where p.id = v_uid or p.user_id = v_uid
  order by case when p.id = v_uid then 0 else 1 end
  limit 1;

  select a.id, a.role, a.is_active, a.full_name, a.email
    into v_admin
  from public.admin_users a
  where a.user_id = v_uid
  limit 1;

  select bo.id as owner_id, bo.business_id, bo.role, bo.is_active as owner_active,
         coalesce(bo.business_name, pb.name) as business_name,
         pb.name as partner_name, pb.business_type, pb.is_active as business_active,
         pb.commission_rate, pb.logo_url
    into v_business
  from public.business_owners bo
  left join public.partner_businesses pb on pb.id = bo.business_id
  where bo.user_id = v_uid
  limit 1;

  select lu.id as lawyer_id, lu.role, lu.is_active, lu.is_available,
         lu.full_name, lu.email, lu.bar_number, lu.specialization, lu.commission_rate
    into v_lawyer
  from public.lawyer_users lu
  where lu.user_id = v_uid
  limit 1;

  -- Run the SELECT even for cityless profiles so the record has a known tuple
  -- shape and simply contains NULL fields when no configured city matches.
  select c.id, c.slug, c.city_name, c.country_code, c.country_name,
         c.parent_id, c.is_active as city_active,
         coalesce(parent.is_active, true) as parent_active,
         c.currency
    into v_city
  from public.admin_territories c
  left join public.admin_territories parent on parent.id = c.parent_id
  where c.territory_type = 'city'
    and v_profile.city is not null
    and btrim(v_profile.city) <> ''
    and lower(btrim(c.city_name)) = lower(btrim(v_profile.city))
  order by
    case
      when v_profile.country is not null and (
        lower(btrim(c.country_name)) = lower(btrim(v_profile.country)) or
        lower(btrim(c.country_code)) = lower(btrim(v_profile.country))
      ) then 0
      else 1
    end,
    c.created_at
  limit 1;

  if v_city.id is not null then
    select coalesce(jsonb_object_agg(x.feature_key, x.effective_enabled), '{}'::jsonb)
      into v_features
    from (
      select cf.feature_key,
             (v_city.city_active
              and v_city.parent_active
              and cf.is_enabled
              and coalesce(pf.is_enabled, true)) as effective_enabled
      from public.territory_features cf
      left join public.territory_features pf
        on pf.territory_id = v_city.parent_id
       and pf.feature_key = cf.feature_key
      where cf.territory_id = v_city.id
    ) x;
    v_features := v_default_features || coalesce(v_features, '{}'::jsonb);
  else
    v_features := v_default_features;
  end if;

  select coalesce(sc.meta, '{}'::jsonb)
    into v_platform
  from public.site_content sc
  where sc.page_key = 'platform_config'
    and sc.section_key = 'platform_config'
    and sc.is_published = true
    and sc.is_visible = true
  order by sc.updated_at desc
  limit 1;

  v_platform := jsonb_build_object(
    'maintenanceMode', false,
    'userRegistration', true,
    'autoVerification', false,
    'requireEmailVerification', true,
    'moderationLevel', 'medium'
  ) || coalesce(v_platform, '{}'::jsonb);

  select tsu.id as staff_id, tsu.role, tsa.id as assignment_id,
         tsa.territory_id, at.name as territory_name, at.slug as territory_slug,
         (tsu.is_active and tsa.is_active and at.is_active and coalesce(parent.is_active, true)) as effective_active
    into v_territory_staff
  from public.territory_staff_users tsu
  join public.territory_staff_assignments tsa
    on tsa.staff_id = tsu.id and tsa.is_active = true
  join public.admin_territories at on at.id = tsa.territory_id
  left join public.admin_territories parent on parent.id = at.parent_id
  where tsu.user_id = v_uid
  order by tsa.created_at desc
  limit 1;

  return jsonb_build_object(
    'user_id', v_uid,
    'profile', jsonb_build_object(
      'id', coalesce(v_profile.id, v_uid),
      'email', v_profile.email,
      'full_name', v_profile.full_name,
      'city', v_profile.city,
      'country', v_profile.country,
      'active_mode', v_profile.active_mode,
      'is_active', coalesce(v_profile.is_active, true),
      'is_banned', coalesce(v_profile.is_banned, false),
      'is_suspended', coalesce(v_profile.is_suspended, false),
      'is_blocked', coalesce(v_profile.is_blocked, false),
      'verified', coalesce(v_profile.verified, false),
      'onboarding_completed', coalesce(v_profile.onboarding_completed, false)
    ),
    'roles', jsonb_build_object(
      'admin', jsonb_build_object(
        'active', coalesce(v_admin.is_active, false),
        'id', v_admin.id,
        'role', v_admin.role,
        'full_name', v_admin.full_name,
        'email', v_admin.email
      ),
      'business', jsonb_build_object(
        'active', coalesce(v_business.owner_active, false)
                  and coalesce(v_business.business_active, false)
                  and v_business.business_id is not null,
        'membership_active', coalesce(v_business.owner_active, false),
        'owner_id', v_business.owner_id,
        'business_id', v_business.business_id,
        'business_name', v_business.business_name,
        'business_type', v_business.business_type,
        'business_active', coalesce(v_business.business_active, false),
        'commission_rate', v_business.commission_rate,
        'logo_url', v_business.logo_url
      ),
      'lawyer', jsonb_build_object(
        'active', coalesce(v_lawyer.is_active, false),
        'lawyer_id', v_lawyer.lawyer_id,
        'role', v_lawyer.role,
        'full_name', v_lawyer.full_name,
        'email', v_lawyer.email,
        'bar_number', v_lawyer.bar_number,
        'specialization', v_lawyer.specialization,
        'is_available', coalesce(v_lawyer.is_available, false),
        'commission_rate', v_lawyer.commission_rate
      ),
      'territory', jsonb_build_object(
        'active', coalesce(v_territory_staff.effective_active, false),
        'staff_id', v_territory_staff.staff_id,
        'role', v_territory_staff.role,
        'assignment_id', v_territory_staff.assignment_id,
        'territory_id', v_territory_staff.territory_id,
        'territory_name', v_territory_staff.territory_name,
        'territory_slug', v_territory_staff.territory_slug
      )
    ),
    'territory', case when v_city.id is null then
      jsonb_build_object(
        'configured', false,
        'effective_open', true,
        'features', v_features
      )
    else
      jsonb_build_object(
        'configured', true,
        'id', v_city.id,
        'slug', v_city.slug,
        'city', v_city.city_name,
        'country_code', v_city.country_code,
        'country_name', v_city.country_name,
        'currency', v_city.currency,
        'effective_open', v_city.city_active and v_city.parent_active,
        'features', v_features
      )
    end,
    'platform', v_platform
  );
end;
$$;

create or replace function public.app_business_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_owner record;
  v_summary jsonb;
  v_recent_scans jsonb;
  v_recent_transactions jsonb;
  v_promos jsonb;
  v_commissions jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select bo.id as owner_id, bo.business_id, bo.full_name, bo.email,
         coalesce(bo.business_name, pb.name) as business_name,
         pb.business_type, pb.address, pb.logo_url, pb.phone, pb.email as business_email,
         pb.whatsapp, pb.website, pb.instagram, pb.discount_tiers,
         pb.commission_rate, bo.is_active as owner_active, pb.is_active as business_active
    into v_owner
  from public.business_owners bo
  join public.partner_businesses pb on pb.id = bo.business_id
  where bo.user_id = v_uid
  limit 1;

  if v_owner.owner_id is null
     or not coalesce(v_owner.owner_active, false)
     or not coalesce(v_owner.business_active, false) then
    raise exception 'Active business workspace required' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'scans_today', (select count(*) from public.qr_scans s where s.business_id = v_owner.business_id and s.scan_timestamp >= date_trunc('day', now())),
    'scans_30d', (select count(*) from public.qr_scans s where s.business_id = v_owner.business_id and s.scan_timestamp >= now() - interval '30 days'),
    'scans_total', (select count(*) from public.qr_scans s where s.business_id = v_owner.business_id),
    'customers_total', (select count(distinct s.scanned_user_id) from public.qr_scans s where s.business_id = v_owner.business_id),
    'transactions_30d', (select count(*) from public.business_transactions t where t.business_id = v_owner.business_id and t.created_at >= now() - interval '30 days'),
    'gross_sales_30d', coalesce((select sum(t.total_amount) from public.business_transactions t where t.business_id = v_owner.business_id and t.created_at >= now() - interval '30 days'), 0),
    'discounts_30d', coalesce((select sum(t.discount_amount) from public.business_transactions t where t.business_id = v_owner.business_id and t.created_at >= now() - interval '30 days'), 0),
    'commission_30d', coalesce((select sum(t.commission_amount) from public.business_transactions t where t.business_id = v_owner.business_id and t.created_at >= now() - interval '30 days'), 0),
    'active_promos', (select count(*) from public.business_customer_promos p where p.business_id = v_owner.business_id and p.status = 'active' and (p.expires_at is null or p.expires_at > now()))
  ) into v_summary;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_recent_scans
  from (
    select s.id, s.scanned_user_id, s.scan_timestamp,
           p.full_name as customer_name, p.avatar_url as customer_avatar
    from public.qr_scans s
    left join public.profiles p on p.id = s.scanned_user_id
    where s.business_id = v_owner.business_id
    order by s.scan_timestamp desc
    limit 12
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_recent_transactions
  from (
    select t.id, t.user_id, t.order_description, t.total_amount,
           t.discount_percentage, t.discount_amount, t.commission_amount,
           t.created_at, p.full_name as customer_name
    from public.business_transactions t
    left join public.profiles p on p.id = t.user_id
    where t.business_id = v_owner.business_id
    order by t.created_at desc
    limit 12
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_promos
  from (
    select p.id, p.user_id, p.code, p.title, p.message, p.discount_percent,
           p.status, p.expires_at, p.redeemed_at, p.created_at
    from public.business_customer_promos p
    where p.business_id = v_owner.business_id
    order by p.created_at desc
    limit 20
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_commissions
  from (
    select c.id, c.amount, c.note, c.status, c.created_at
    from public.commission_payment_submissions c
    where c.portal = 'owner' and c.business_id = v_owner.business_id
    order by c.created_at desc
    limit 20
  ) x;

  return jsonb_build_object(
    'business', jsonb_build_object(
      'owner_id', v_owner.owner_id,
      'business_id', v_owner.business_id,
      'business_name', v_owner.business_name,
      'business_type', v_owner.business_type,
      'address', v_owner.address,
      'logo_url', v_owner.logo_url,
      'phone', v_owner.phone,
      'email', v_owner.business_email,
      'whatsapp', v_owner.whatsapp,
      'website', v_owner.website,
      'instagram', v_owner.instagram,
      'discount_tiers', v_owner.discount_tiers,
      'commission_rate', v_owner.commission_rate
    ),
    'summary', v_summary,
    'recent_scans', v_recent_scans,
    'recent_transactions', v_recent_transactions,
    'customer_promos', v_promos,
    'commission_submissions', v_commissions
  );
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
    'pending_requests', (select count(*) from public.legal_package_requests r where r.assigned_lawyer_id = v_lawyer.lawyer_id and r.status in ('pending','offered','accepted','paid')),
    'active_clients', (select count(*) from public.lawyer_clients c where c.lawyer_id = v_lawyer.lawyer_id and coalesce(c.status, 'active') = 'active'),
    'open_cases', (select count(*) from public.lawyer_cases c where c.lawyer_id = v_lawyer.lawyer_id and c.status not in ('resolved','closed','cancelled')),
    'upcoming_appointments', (select count(*) from public.lawyer_appointments a where a.lawyer_id = v_lawyer.lawyer_id and a.scheduled_at >= now() and coalesce(a.status,'scheduled') not in ('cancelled','completed')),
    'gross_earned_30d', coalesce((select sum(t.total_earned) from public.lawyer_transactions t where t.lawyer_id = v_lawyer.lawyer_id and t.created_at >= now() - interval '30 days'), 0),
    'commission_30d', coalesce((select sum(t.commission_amount) from public.lawyer_transactions t where t.lawyer_id = v_lawyer.lawyer_id and t.created_at >= now() - interval '30 days'), 0),
    'templates_available', (select count(*) from public.lawyer_templates t where t.is_active = true and (t.created_by is null or t.created_by = v_lawyer.lawyer_id)),
    'service_packages_available', (select count(*) from public.legal_service_packages p where p.is_active = true)
  ) into v_summary;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_requests
  from (
    select r.id, r.package_name, r.package_category, r.quoted_price, r.situation,
           r.full_name, r.preferred_contact, r.status, r.city,
           r.offered_at, r.paid_at, r.consult_at, r.expires_at, r.created_at
    from public.legal_package_requests r
    where r.assigned_lawyer_id = v_lawyer.lawyer_id
    order by r.created_at desc
    limit 15
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
    'requests', v_requests,
    'cases', v_cases,
    'appointments', v_appointments,
    'recent_transactions', v_transactions
  );
end;
$$;

create or replace function public.app_lawyer_set_availability(p_available boolean)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  update public.lawyer_users
  set is_available = p_available,
      updated_at = now()
  where user_id = v_uid
    and is_active = true;

  if not found then
    raise exception 'Active lawyer workspace required' using errcode = '42501';
  end if;

  return true;
end;
$$;

revoke all on function public.app_session_context() from public;
revoke all on function public.app_session_context() from anon;
grant execute on function public.app_session_context() to authenticated;
grant execute on function public.app_session_context() to service_role;

revoke all on function public.app_business_workspace() from public;
revoke all on function public.app_business_workspace() from anon;
grant execute on function public.app_business_workspace() to authenticated;
grant execute on function public.app_business_workspace() to service_role;

revoke all on function public.app_lawyer_workspace() from public;
revoke all on function public.app_lawyer_workspace() from anon;
grant execute on function public.app_lawyer_workspace() to authenticated;
grant execute on function public.app_lawyer_workspace() to service_role;

revoke all on function public.app_lawyer_set_availability(boolean) from public;
revoke all on function public.app_lawyer_set_availability(boolean) from anon;
grant execute on function public.app_lawyer_set_availability(boolean) to authenticated;
grant execute on function public.app_lawyer_set_availability(boolean) to service_role;
