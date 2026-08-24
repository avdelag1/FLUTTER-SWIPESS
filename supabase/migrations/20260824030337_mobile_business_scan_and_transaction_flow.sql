-- Secure mobile Business portal mutations. The app only sends a scanned QR
-- payload / transaction inputs; business identity, customer identity,
-- discounts and commission math are resolved and validated server-side.

create or replace function public.app_business_scan_member(
  p_payload text,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_business record;
  v_user_id uuid;
  v_match text;
  v_scan_id uuid;
  v_member jsonb;
  v_subscription jsonb;
  v_stats jsonb;
  v_recent jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select bo.business_id, pb.name, pb.discount_tiers, pb.commission_rate
    into v_business
  from public.business_owners bo
  join public.partner_businesses pb on pb.id = bo.business_id
  where bo.user_id = v_uid
    and bo.is_active = true
    and pb.is_active = true
  limit 1;

  if v_business.business_id is null then
    raise exception 'Active business workspace required' using errcode = '42501';
  end if;

  v_match := substring(coalesce(p_payload, '') from '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})');
  if v_match is null then
    raise exception 'Invalid SWIPESS Local ID QR';
  end if;
  v_user_id := v_match::uuid;

  if not exists (
    select 1
    from public.profiles p
    where (p.id = v_user_id or p.user_id = v_user_id)
      and coalesce(p.is_active, true) = true
      and coalesce(p.is_banned, false) = false
      and coalesce(p.is_suspended, false) = false
      and coalesce(p.is_blocked, false) = false
  ) and not exists (
    select 1 from public.client_profiles cp where cp.user_id = v_user_id
  ) then
    raise exception 'SWIPESS member not found or unavailable';
  end if;

  insert into public.qr_scans (
    business_id, scanned_user_id, scanned_by, notes
  ) values (
    v_business.business_id,
    v_user_id,
    v_uid,
    nullif(btrim(coalesce(p_notes, '')), '')
  ) returning id into v_scan_id;

  select jsonb_build_object(
    'user_id', v_user_id,
    'name', coalesce(vc.name, cp.name, p.full_name, 'SWIPESS member'),
    'age', coalesce(vc.age, cp.age, p.age),
    'nationality', coalesce(vc.nationality, cp.nationality, p.nationality),
    'city', coalesce(vc.city, cp.vap_city, cp.city, p.city),
    'country', coalesce(vc.country, cp.country, p.country),
    'years_in_city', coalesce(vc.years_in_city, cp.vap_years_in_city, cp.years_in_city),
    'occupation', coalesce(vc.occupation, cp.vap_occupation, cp.occupation),
    'bio', coalesce(vc.bio, cp.vap_bio, cp.bio, p.bio),
    'avatar_url', coalesce(
      vc.id_photo_url,
      vc.avatar_url,
      cp.vap_avatar,
      case when jsonb_typeof(cp.profile_images) = 'array' then cp.profile_images->>0 else null end,
      p.avatar_url,
      p.profile_photo_url
    ),
    'verified', coalesce(p.verified, false)
  )
    into v_member
  from (select 1) anchor
  left join public.vap_id_cards vc on vc.user_id = v_user_id
  left join public.client_profiles cp on cp.user_id = v_user_id
  left join lateral (
    select px.*
    from public.profiles px
    where px.id = v_user_id or px.user_id = v_user_id
    order by case when px.id = v_user_id then 0 else 1 end
    limit 1
  ) p on true;

  select coalesce((
    select jsonb_build_object(
      'active', true,
      'name', sp.name,
      'tier', sp.tier,
      'end_date', us.end_date
    )
    from public.user_subscriptions us
    left join public.subscription_packages sp on sp.id = us.package_id
    where us.user_id = v_user_id
      and us.is_active = true
      and (us.end_date is null or us.end_date > now())
    order by us.created_at desc
    limit 1
  ), jsonb_build_object('active', false)) into v_subscription;

  select jsonb_build_object(
    'visits_total', (
      select count(*) from public.qr_scans s
      where s.business_id = v_business.business_id
        and s.scanned_user_id = v_user_id
    ),
    'gross_spend_total', coalesce((
      select sum(t.total_amount) from public.business_transactions t
      where t.business_id = v_business.business_id and t.user_id = v_user_id
    ), 0),
    'discount_saved_total', coalesce((
      select sum(t.discount_amount) from public.business_transactions t
      where t.business_id = v_business.business_id and t.user_id = v_user_id
    ), 0),
    'direct_requests_remaining', coalesce((
      select sum(coalesce(tok.remaining_activations, 0))
      from public.tokens tok
      where tok.user_id = v_user_id
        and (tok.expires_at is null or tok.expires_at > now())
    ), 0)
  ) into v_stats;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_recent
  from (
    select t.id, t.order_description, t.total_amount, t.discount_percentage,
           t.discount_amount, t.commission_amount, t.created_at
    from public.business_transactions t
    where t.business_id = v_business.business_id
      and t.user_id = v_user_id
    order by t.created_at desc
    limit 5
  ) x;

  return jsonb_build_object(
    'scan_id', v_scan_id,
    'business_id', v_business.business_id,
    'business_name', v_business.name,
    'discount_tiers', v_business.discount_tiers,
    'commission_rate', v_business.commission_rate,
    'member', v_member,
    'subscription', v_subscription,
    'stats', v_stats,
    'recent_transactions', v_recent
  );
end;
$$;

create or replace function public.app_business_record_transaction(
  p_scan_id uuid,
  p_total_amount numeric,
  p_discount_percentage numeric default 0,
  p_order_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_business record;
  v_scan record;
  v_discount numeric := coalesce(p_discount_percentage, 0);
  v_discount_amount numeric;
  v_net numeric;
  v_commission numeric;
  v_transaction_id uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select bo.business_id, pb.discount_tiers, pb.commission_rate
    into v_business
  from public.business_owners bo
  join public.partner_businesses pb on pb.id = bo.business_id
  where bo.user_id = v_uid
    and bo.is_active = true
    and pb.is_active = true
  limit 1;

  if v_business.business_id is null then
    raise exception 'Active business workspace required' using errcode = '42501';
  end if;

  if p_total_amount is null or p_total_amount <= 0 or p_total_amount > 100000000 then
    raise exception 'Transaction total must be greater than zero';
  end if;
  if v_discount < 0 or v_discount > 100 then
    raise exception 'Discount must be between 0 and 100';
  end if;
  if v_discount > 0 and not exists (
    select 1
    from jsonb_array_elements_text(coalesce(v_business.discount_tiers, '[]'::jsonb)) j(value)
    where j.value::numeric = v_discount
  ) then
    raise exception 'Discount is not enabled for this business';
  end if;

  select s.id, s.scanned_user_id
    into v_scan
  from public.qr_scans s
  where s.id = p_scan_id
    and s.business_id = v_business.business_id
  limit 1;

  if v_scan.id is null then
    raise exception 'Valid business scan required';
  end if;

  v_discount_amount := round(p_total_amount * v_discount / 100.0, 2);
  v_net := greatest(round(p_total_amount - v_discount_amount, 2), 0);
  v_commission := round(v_net * coalesce(v_business.commission_rate, 0) / 100.0, 2);

  insert into public.business_transactions (
    business_id, user_id, scan_id, order_description,
    total_amount, discount_percentage, discount_amount, commission_amount
  ) values (
    v_business.business_id,
    v_scan.scanned_user_id,
    v_scan.id,
    nullif(btrim(coalesce(p_order_description, '')), ''),
    round(p_total_amount, 2),
    v_discount,
    v_discount_amount,
    v_commission
  ) returning id into v_transaction_id;

  return jsonb_build_object(
    'ok', true,
    'transaction_id', v_transaction_id,
    'scan_id', v_scan.id,
    'gross_amount', round(p_total_amount, 2),
    'discount_percentage', v_discount,
    'discount_amount', v_discount_amount,
    'customer_pays', v_net,
    'commission_amount', v_commission
  );
end;
$$;

create or replace function public.send_business_customer_promo(
  p_user_id uuid,
  p_discount_percent numeric,
  p_title text default 'Partner Promo',
  p_message text default null,
  p_expires_hours integer default 168
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_business_id uuid;
  v_business_name text;
  v_discount_tiers jsonb;
  v_code text;
  v_promo_id uuid;
  v_expires timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select bo.business_id, pb.name, pb.discount_tiers
    into v_business_id, v_business_name, v_discount_tiers
  from public.business_owners bo
  join public.partner_businesses pb on pb.id = bo.business_id
  where bo.user_id = auth.uid()
    and bo.is_active = true
    and pb.is_active = true
  limit 1;

  if v_business_id is null then
    raise exception 'Active business workspace required' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'Missing customer';
  end if;
  if p_discount_percent is null or p_discount_percent < 1 or p_discount_percent > 100 then
    raise exception 'Discount must be between 1 and 100';
  end if;
  if not exists (
    select 1
    from jsonb_array_elements_text(coalesce(v_discount_tiers, '[]'::jsonb)) j(value)
    where j.value::numeric = p_discount_percent
  ) then
    raise exception 'Discount is not enabled for this business';
  end if;
  if not exists (
    select 1 from public.profiles p where p.id = p_user_id or p.user_id = p_user_id
  ) and not exists (
    select 1 from public.client_profiles cp where cp.user_id = p_user_id
  ) then
    raise exception 'Customer not found';
  end if;

  v_code := 'SWP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  v_expires := now() + make_interval(hours => greatest(coalesce(p_expires_hours, 168), 1));

  insert into public.business_customer_promos (
    business_id, user_id, code, title, message, discount_percent, status, expires_at, created_by
  ) values (
    v_business_id,
    p_user_id,
    v_code,
    coalesce(nullif(trim(p_title), ''), 'Partner Promo'),
    nullif(trim(p_message), ''),
    p_discount_percent,
    'active',
    v_expires,
    auth.uid()
  ) returning id into v_promo_id;

  begin
    insert into public.notifications (
      user_id, title, message, notification_type, link_url, metadata, is_read
    ) values (
      p_user_id,
      coalesce(v_business_name, 'Partner') || ' sent you a promo',
      coalesce(nullif(trim(p_message), ''), 'Show code ' || v_code || ' for ' || p_discount_percent::text || '% off on your next visit.'),
      'system_announcement',
      '/client/perks',
      jsonb_build_object(
        'kind', 'business_promo',
        'promo_id', v_promo_id,
        'code', v_code,
        'discount_percent', p_discount_percent,
        'business_id', v_business_id,
        'business_name', v_business_name
      ),
      false
    );
  exception when others then
    null;
  end;

  return jsonb_build_object(
    'ok', true,
    'promo_id', v_promo_id,
    'code', v_code,
    'expires_at', v_expires
  );
end;
$$;

revoke all on function public.app_business_scan_member(text, text) from public;
revoke all on function public.app_business_scan_member(text, text) from anon;
grant execute on function public.app_business_scan_member(text, text) to authenticated;
grant execute on function public.app_business_scan_member(text, text) to service_role;

revoke all on function public.app_business_record_transaction(uuid, numeric, numeric, text) from public;
revoke all on function public.app_business_record_transaction(uuid, numeric, numeric, text) from anon;
grant execute on function public.app_business_record_transaction(uuid, numeric, numeric, text) to authenticated;
grant execute on function public.app_business_record_transaction(uuid, numeric, numeric, text) to service_role;

revoke all on function public.send_business_customer_promo(uuid, numeric, text, text, integer) from public;
revoke all on function public.send_business_customer_promo(uuid, numeric, text, text, integer) from anon;
grant execute on function public.send_business_customer_promo(uuid, numeric, text, text, integer) to authenticated;
grant execute on function public.send_business_customer_promo(uuid, numeric, text, text, integer) to service_role;
