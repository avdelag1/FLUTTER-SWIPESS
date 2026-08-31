-- Real member perks feed. No demo/mock offers.
-- A member only sees businesses that actually scanned them, sent them a promo,
-- or recorded a transaction for them.

create or replace function public.rpc_my_resident_perks()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_offers jsonb;
  v_history jsonb;
  v_partners jsonb;
  v_saved numeric;
  v_scans integer;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
    into v_offers
  from (
    select p.id,
           p.business_id,
           pb.name as business_name,
           pb.logo_url,
           p.code,
           p.title,
           p.message,
           p.discount_percent,
           p.status,
           p.expires_at,
           p.redeemed_at,
           p.created_at
    from public.business_customer_promos p
    join public.partner_businesses pb on pb.id = p.business_id
    where p.user_id = v_uid
      and coalesce(p.status, 'active') <> 'cancelled'
    order by p.created_at desc
    limit 100
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
    into v_history
  from (
    select t.id,
           t.business_id,
           pb.name as business_name,
           pb.logo_url,
           t.order_description,
           t.total_amount,
           t.discount_percentage,
           t.discount_amount,
           t.created_at
    from public.business_transactions t
    join public.partner_businesses pb on pb.id = t.business_id
    where t.user_id = v_uid
    order by t.created_at desc
    limit 100
  ) x;

  select coalesce(sum(t.discount_amount), 0)
    into v_saved
  from public.business_transactions t
  where t.user_id = v_uid;

  select count(*)::int
    into v_scans
  from public.qr_scans s
  where s.scanned_user_id = v_uid;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.business_name), '[]'::jsonb)
    into v_partners
  from (
    select distinct pb.id as business_id,
           pb.name as business_name,
           pb.logo_url
    from public.partner_businesses pb
    where exists (
      select 1
      from public.business_customer_promos p
      where p.user_id = v_uid
        and p.business_id = pb.id
    )
    or exists (
      select 1
      from public.business_transactions t
      where t.user_id = v_uid
        and t.business_id = pb.id
    )
    or exists (
      select 1
      from public.qr_scans s
      where s.scanned_user_id = v_uid
        and s.business_id = pb.id
    )
  ) x;

  return jsonb_build_object(
    'offers', v_offers,
    'history', v_history,
    'partners', v_partners,
    'saved', coalesce(v_saved, 0),
    'scans', coalesce(v_scans, 0)
  );
end;
$$;

revoke all on function public.rpc_my_resident_perks() from public;
grant execute on function public.rpc_my_resident_perks() to authenticated;
