-- Fix the production media-upload regression introduced when the listing-video
-- storage policy called _has_paid_listing_video_access() after EXECUTE had been
-- revoked from authenticated users. PostgreSQL is free to evaluate permissive
-- RLS expressions in any order, so that denied helper could also poison image
-- inserts into storage.objects and surface as a generic HTTP 400.

begin;

drop policy if exists "listing videos insert own folder" on storage.objects;
create policy "listing videos insert own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "listing videos update own folder" on storage.objects;
create policy "listing videos update own folder"
on storage.objects for update to authenticated
using (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

-- Older clients/RPCs may still call the compatibility helper directly. Its
-- current product rule is simply authenticated access.
grant execute on function public._has_paid_listing_video_access(uuid) to authenticated;

-- Dashboard quick filters request eight listings. Ensure a real listing video
-- is inside that tiny preview set when one exists, without changing the normal
-- 24-card discovery deck or Recommended ranking.
create or replace function public.app_get_smart_listings(
  p_category text default 'property'::text,
  p_city text default null::text,
  p_country text default null::text,
  p_limit integer default 30,
  p_offset integer default 0
)
returns setof public.listings
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_category text := lower(btrim(coalesce(p_category, 'property')));
  v_market jsonb;
  v_features jsonb;
  v_market_open boolean;
  v_requested_feature text;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_market := public.app_market_context(p_city, p_country);
  v_features := coalesce(v_market->'features', '{}'::jsonb);
  v_market_open := coalesce((v_market->>'effective_open')::boolean, true);

  v_requested_feature := case v_category
    when 'property' then 'properties'
    when 'services' then 'workers'
    when 'worker' then 'workers'
    when 'yacht' then 'yachts'
    when 'motorcycle' then 'motorcycles'
    when 'bicycle' then 'bicycles'
    else null
  end;

  if not v_market_open then return; end if;

  if v_category not in ('all', 'recommended', 'popular')
     and v_requested_feature is not null
     and coalesce((v_features->>v_requested_feature)::boolean, true) = false then
    return;
  end if;

  return query
  select l.*
  from public.listings l
  where coalesce(l.is_active, true) = true
    and coalesce(l.status, 'active') = 'active'
    and l.owner_id is distinct from v_uid
    and (
      v_category in ('all', 'recommended', 'popular')
      or lower(coalesce(l.category, '')) = v_category
      or (v_category = 'services' and lower(coalesce(l.category, '')) = 'worker')
      or (v_category = 'worker' and lower(coalesce(l.category, '')) = 'services')
    )
    and (
      p_city is null or btrim(p_city) = ''
      or lower(btrim(coalesce(l.city, ''))) = lower(btrim(p_city))
    )
    and (
      p_country is null or btrim(p_country) = ''
      or l.country is null or btrim(l.country) = ''
      or lower(btrim(l.country)) = lower(btrim(p_country))
    )
    and (
      case lower(coalesce(l.category, ''))
        when 'property' then coalesce((v_features->>'properties')::boolean, true)
        when 'services' then coalesce((v_features->>'workers')::boolean, true)
        when 'worker' then coalesce((v_features->>'workers')::boolean, true)
        when 'yacht' then coalesce((v_features->>'yachts')::boolean, true)
        when 'motorcycle' then coalesce((v_features->>'motorcycles')::boolean, true)
        when 'bicycle' then coalesce((v_features->>'bicycles')::boolean, true)
        else true
      end
    )
    and public._discovery_listing_visible(
      v_uid,
      l.id,
      l.price,
      l.hourly_rate,
      l.description,
      l.images
    )
  order by
    case
      when coalesce(p_limit, 30) <= 8
       and nullif(btrim(coalesce(l.video_url, '')), '') is not null
      then 1 else 0
    end desc,
    case when coalesce(l.verification_status, 'unverified') = 'approved' then 1 else 0 end desc,
    case when v_category = 'popular' then coalesce(l.likes, 0) end desc nulls last,
    case when v_category = 'popular' then coalesce(l.views, 0) end desc nulls last,
    case when v_category = 'recommended' then coalesce(l.likes, 0) end desc nulls last,
    l.created_at desc nulls last,
    l.id
  limit greatest(1, least(coalesce(p_limit, 30), 100))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

commit;
