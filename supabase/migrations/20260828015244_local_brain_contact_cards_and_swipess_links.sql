alter table public.local_brain_entries
  add column if not exists photo_url text,
  add column if not exists facebook text,
  add column if not exists tiktok text,
  add column if not exists youtube text,
  add column if not exists x_url text,
  add column if not exists telegram text,
  add column if not exists linked_profile_user_id uuid,
  add column if not exists linked_listing_id uuid references public.listings(id) on delete set null;

create index if not exists local_brain_entries_linked_profile_idx
  on public.local_brain_entries (linked_profile_user_id)
  where linked_profile_user_id is not null;
create index if not exists local_brain_entries_linked_listing_idx
  on public.local_brain_entries (linked_listing_id)
  where linked_listing_id is not null;

drop function if exists public.rpc_search_local_brain(text,text,double precision,double precision,integer);

create function public.rpc_search_local_brain(
  p_query text,
  p_city text default null,
  p_lat double precision default null,
  p_lon double precision default null,
  p_limit integer default 8
)
returns table (
  id uuid,
  entry_type text,
  name text,
  category text,
  description text,
  phone text,
  whatsapp text,
  email text,
  website text,
  instagram text,
  facebook text,
  tiktok text,
  youtube text,
  x_url text,
  telegram text,
  photo_url text,
  address text,
  neighborhood text,
  city text,
  region text,
  country text,
  latitude double precision,
  longitude double precision,
  service_radius_km double precision,
  hours text,
  languages text[],
  price_level text,
  tags text[],
  recommendation_note text,
  is_featured boolean,
  is_verified boolean,
  priority integer,
  linked_profile_user_id uuid,
  linked_listing_id uuid,
  swipess_profile_user_id uuid,
  swipess_listing_id uuid,
  card_image_url text,
  distance_km double precision
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_allowed boolean := false;
begin
  if auth.uid() is null then return; end if;

  begin
    select coalesce(public.rpc_has_premium_feature_access(), false) into v_allowed;
  exception when others then
    v_allowed := false;
  end;
  if not v_allowed then return; end if;

  return query
  with base as (
    select
      e.*,
      lower(concat_ws(' ', e.name, e.category, e.description, e.neighborhood, e.city, e.region, e.country,
        array_to_string(e.tags, ' '), array_to_string(e.languages, ' '), e.recommendation_note)) as search_blob,
      case
        when p_lat is not null and p_lon is not null and e.latitude is not null and e.longitude is not null then
          6371.0 * acos(least(1.0, greatest(-1.0,
            cos(radians(p_lat)) * cos(radians(e.latitude)) * cos(radians(e.longitude) - radians(p_lon))
            + sin(radians(p_lat)) * sin(radians(e.latitude))
          )))
        else null
      end as calculated_distance_km,
      case
        when nullif(trim(coalesce(p_city, '')), '') is null then false
        when lower(p_city) like '%' || lower(e.city) || '%' then true
        when lower(e.city) like '%' || lower(p_city) || '%' then true
        else false
      end as city_match
    from public.local_brain_entries e
    where e.is_active = true
  ), scored as (
    select
      b.*,
      (
        select count(*)::integer
        from regexp_split_to_table(lower(coalesce(p_query, '')), E'\\s+') as token
        where length(token) >= 3
          and token not in ('the','and','for','with','from','that','this','what','where','who','find','best','near','nearby','local','please','want','need','looking','around','give','show','get','can','you','me','una','uno','unos','unas','que','por','para','con','del','los','las','donde','quien','busco','buscar','mejor','cerca','locales')
          and b.search_blob like '%' || token || '%'
      ) as token_matches,
      (lower(coalesce(p_query, '')) like '%' || lower(b.name) || '%') as exact_name_in_query
    from base b
  )
  select
    s.id, s.entry_type, s.name, s.category, s.description,
    s.phone, s.whatsapp, s.email, s.website, s.instagram,
    s.facebook, s.tiktok, s.youtube, s.x_url, s.telegram, s.photo_url,
    s.address, s.neighborhood, s.city, s.region, s.country,
    s.latitude, s.longitude, s.service_radius_km, s.hours,
    s.languages, s.price_level, s.tags, s.recommendation_note,
    s.is_featured, s.is_verified, s.priority,
    s.linked_profile_user_id, s.linked_listing_id,
    coalesce(s.linked_profile_user_id, matched_profile.user_id) as swipess_profile_user_id,
    s.linked_listing_id as swipess_listing_id,
    coalesce(nullif(s.photo_url, ''), matched_profile.image_url, linked_listing.image_url) as card_image_url,
    s.calculated_distance_km
  from scored s
  left join lateral (
    select
      p.user_id,
      coalesce(nullif(p.profile_photo_url, ''), nullif(p.avatar_url, ''), nullif(p.avatar, ''), p.profile_images[1]) as image_url
    from public.profiles p
    where p.is_active = true
      and (
        (s.linked_profile_user_id is not null and p.user_id = s.linked_profile_user_id)
        or (
          s.linked_profile_user_id is null
          and (
            (nullif(trim(s.email), '') is not null and lower(coalesce(p.email, '')) = lower(s.email))
            or (
              length(regexp_replace(coalesce(s.phone, ''), '[^0-9]', '', 'g')) >= 7
              and regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g') = regexp_replace(s.phone, '[^0-9]', '', 'g')
            )
          )
        )
      )
    order by case when s.linked_profile_user_id is not null and p.user_id = s.linked_profile_user_id then 0 else 1 end
    limit 1
  ) matched_profile on true
  left join lateral (
    select l.id, l.images[1] as image_url
    from public.listings l
    where s.linked_listing_id is not null
      and l.id = s.linked_listing_id
      and l.is_active = true
      and l.status = 'active'
    limit 1
  ) linked_listing on true
  where nullif(trim(coalesce(p_query, '')), '') is null
     or s.exact_name_in_query
     or s.token_matches > 0
  order by
    s.city_match desc,
    s.exact_name_in_query desc,
    s.token_matches desc,
    s.calculated_distance_km asc nulls last,
    s.is_featured desc,
    s.is_verified desc,
    s.priority desc,
    s.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 8), 20));
end;
$$;

revoke all on function public.rpc_search_local_brain(text,text,double precision,double precision,integer) from public;
grant execute on function public.rpc_search_local_brain(text,text,double precision,double precision,integer) to authenticated;
