-- Keep Flutter's selected Passport/discovery city aligned with the Super Admin
-- territory activation matrix. Unknown/unconfigured markets intentionally fail
-- open so an incomplete rollout cannot remove existing marketplace features.

create or replace function public.app_market_context(
  p_city text,
  p_country text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_city record;
  v_features jsonb;
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

  if p_city is null or btrim(p_city) = '' then
    return jsonb_build_object(
      'configured', false,
      'effective_open', true,
      'city', p_city,
      'country_name', p_country,
      'features', v_default_features
    );
  end if;

  select c.id, c.slug, c.city_name, c.country_code, c.country_name,
         c.parent_id, c.is_active as city_active,
         coalesce(parent.is_active, true) as parent_active,
         c.currency
    into v_city
  from public.admin_territories c
  left join public.admin_territories parent on parent.id = c.parent_id
  where c.territory_type = 'city'
    and lower(btrim(c.city_name)) = lower(btrim(p_city))
  order by
    case
      when p_country is not null and (
        lower(btrim(c.country_name)) = lower(btrim(p_country)) or
        lower(btrim(c.country_code)) = lower(btrim(p_country))
      ) then 0
      else 1
    end,
    c.created_at
  limit 1;

  if v_city.id is null then
    return jsonb_build_object(
      'configured', false,
      'effective_open', true,
      'city', p_city,
      'country_name', p_country,
      'features', v_default_features
    );
  end if;

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

  return jsonb_build_object(
    'configured', true,
    'id', v_city.id,
    'slug', v_city.slug,
    'city', v_city.city_name,
    'country_code', v_city.country_code,
    'country_name', v_city.country_name,
    'currency', v_city.currency,
    'effective_open', v_city.city_active and v_city.parent_active,
    'features', v_default_features || coalesce(v_features, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.app_market_context(text, text) from public;
revoke all on function public.app_market_context(text, text) from anon;
grant execute on function public.app_market_context(text, text) to authenticated;
grant execute on function public.app_market_context(text, text) to service_role;
