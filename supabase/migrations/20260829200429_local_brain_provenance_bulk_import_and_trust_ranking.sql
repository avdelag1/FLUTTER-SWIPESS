-- Extend the existing Local Brain without changing the client-facing search RPC shape.
-- Adds provenance/trust metadata plus a staff-only JSON bulk import RPC.

alter table public.local_brain_entries
  add column if not exists source_type text not null default 'manual',
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists source_external_id text,
  add column if not exists source_license text,
  add column if not exists trust_level text not null default 'standard',
  add column if not exists last_verified_at timestamptz,
  add column if not exists imported_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'local_brain_entries_source_type_check'
      and conrelid = 'public.local_brain_entries'::regclass
  ) then
    alter table public.local_brain_entries
      add constraint local_brain_entries_source_type_check
      check (source_type in ('manual','denue','siem','sectur','osm','instagram','facebook','whatsapp','referral','csv','other'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'local_brain_entries_trust_level_check'
      and conrelid = 'public.local_brain_entries'::regclass
  ) then
    alter table public.local_brain_entries
      add constraint local_brain_entries_trust_level_check
      check (trust_level in ('standard','trusted','recommended','official'));
  end if;
end
$$;

create index if not exists local_brain_entries_source_idx
  on public.local_brain_entries (source_type, source_external_id)
  where source_external_id is not null and btrim(source_external_id) <> '';

create index if not exists local_brain_entries_trust_city_idx
  on public.local_brain_entries (lower(city), is_active, trust_level, priority desc);

create or replace function public.rpc_import_local_brain_entries(p_rows jsonb)
returns table (inserted integer, updated integer, skipped integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb;
  v_existing_id uuid;
  v_inserted integer := 0;
  v_updated integer := 0;
  v_skipped integer := 0;
  v_name text;
  v_city text;
  v_category text;
  v_entry_type text;
  v_source_type text;
  v_source_external_id text;
  v_email text;
  v_phone text;
  v_whatsapp text;
  v_website text;
  v_instagram text;
  v_phone_digits text;
  v_whatsapp_digits text;
  v_tags text[] := '{}'::text[];
  v_languages text[] := '{}'::text[];
  v_trust text;
  v_is_verified boolean;
  v_is_featured boolean;
  v_is_active boolean;
  v_last_verified_at timestamptz;
  v_lat double precision;
  v_lon double precision;
  v_radius double precision;
  v_priority integer;
begin
  if auth.uid() is null or not coalesce(public.local_brain_staff_can_manage(), false) then
    raise exception 'Not authorized to import Local Brain entries.' using errcode = '42501';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'p_rows must be a JSON array.';
  end if;
  if jsonb_array_length(p_rows) > 500 then
    raise exception 'Bulk import is limited to 500 rows per request.';
  end if;

  for v_row in select value from jsonb_array_elements(p_rows)
  loop
    begin
      if jsonb_typeof(v_row) <> 'object' then
        v_skipped := v_skipped + 1;
        continue;
      end if;

      v_name := nullif(btrim(v_row->>'name'), '');
      v_city := coalesce(nullif(btrim(v_row->>'city'), ''), 'Tulum');
      v_category := nullif(btrim(v_row->>'category'), '');
      if v_name is null or v_category is null then
        v_skipped := v_skipped + 1;
        continue;
      end if;

      v_entry_type := lower(coalesce(nullif(btrim(v_row->>'entry_type'), ''), 'business'));
      if v_entry_type not in ('person','business','place','service','expert','professional') then v_entry_type := 'business'; end if;

      v_source_type := lower(coalesce(nullif(btrim(v_row->>'source_type'), ''), 'csv'));
      if v_source_type not in ('manual','denue','siem','sectur','osm','instagram','facebook','whatsapp','referral','csv','other') then v_source_type := 'other'; end if;

      v_trust := lower(coalesce(nullif(btrim(v_row->>'trust_level'), ''), 'standard'));
      if v_trust not in ('standard','trusted','recommended','official') then v_trust := 'standard'; end if;

      v_source_external_id := nullif(btrim(v_row->>'source_external_id'), '');
      v_email := nullif(lower(btrim(v_row->>'email')), '');
      v_phone := nullif(btrim(v_row->>'phone'), '');
      v_whatsapp := nullif(btrim(v_row->>'whatsapp'), '');
      v_website := nullif(lower(btrim(v_row->>'website')), '');
      v_instagram := nullif(lower(btrim(v_row->>'instagram')), '');
      v_phone_digits := regexp_replace(coalesce(v_phone, ''), '[^0-9]', '', 'g');
      v_whatsapp_digits := regexp_replace(coalesce(v_whatsapp, ''), '[^0-9]', '', 'g');

      if jsonb_typeof(v_row->'tags') = 'array' then
        select coalesce(array_agg(distinct btrim(x)) filter (where btrim(x) <> ''), '{}'::text[])
          into v_tags from jsonb_array_elements_text(v_row->'tags') as x;
      else
        select coalesce(array_agg(distinct btrim(x)) filter (where btrim(x) <> ''), '{}'::text[])
          into v_tags from unnest(string_to_array(coalesce(v_row->>'tags', ''), ',')) as x;
      end if;

      if jsonb_typeof(v_row->'languages') = 'array' then
        select coalesce(array_agg(distinct btrim(x)) filter (where btrim(x) <> ''), '{}'::text[])
          into v_languages from jsonb_array_elements_text(v_row->'languages') as x;
      else
        select coalesce(array_agg(distinct btrim(x)) filter (where btrim(x) <> ''), '{}'::text[])
          into v_languages from unnest(string_to_array(coalesce(v_row->>'languages', ''), ',')) as x;
      end if;

      v_is_verified := lower(coalesce(v_row->>'is_verified', 'false')) in ('true','1','yes');
      v_is_featured := lower(coalesce(v_row->>'is_featured', 'false')) in ('true','1','yes');
      v_is_active := lower(coalesce(v_row->>'is_active', 'true')) not in ('false','0','no');
      v_last_verified_at := case when nullif(btrim(v_row->>'last_verified_at'), '') is null then null else (v_row->>'last_verified_at')::timestamptz end;
      v_lat := case when nullif(btrim(v_row->>'latitude'), '') is null then null else (v_row->>'latitude')::double precision end;
      v_lon := case when nullif(btrim(v_row->>'longitude'), '') is null then null else (v_row->>'longitude')::double precision end;
      v_radius := case when nullif(btrim(v_row->>'service_radius_km'), '') is null then null else (v_row->>'service_radius_km')::double precision end;
      v_priority := case when nullif(btrim(v_row->>'priority'), '') is null then 0 else (v_row->>'priority')::integer end;

      v_existing_id := null;
      select e.id into v_existing_id
      from public.local_brain_entries e
      where
        (v_source_external_id is not null and e.source_type = v_source_type and e.source_external_id = v_source_external_id)
        or (v_email is not null and lower(coalesce(e.email, '')) = v_email)
        or (length(v_phone_digits) >= 7 and regexp_replace(coalesce(e.phone, ''), '[^0-9]', '', 'g') = v_phone_digits)
        or (length(v_whatsapp_digits) >= 7 and regexp_replace(coalesce(e.whatsapp, ''), '[^0-9]', '', 'g') = v_whatsapp_digits)
        or (v_website is not null and lower(trim(trailing '/' from coalesce(e.website, ''))) = trim(trailing '/' from v_website))
        or (v_instagram is not null and lower(trim(trailing '/' from coalesce(e.instagram, ''))) = trim(trailing '/' from v_instagram))
        or (lower(e.name) = lower(v_name) and lower(e.city) = lower(v_city) and lower(e.category) = lower(v_category))
      order by
        case
          when v_source_external_id is not null and e.source_type = v_source_type and e.source_external_id = v_source_external_id then 0
          when v_email is not null and lower(coalesce(e.email, '')) = v_email then 1
          when length(v_phone_digits) >= 7 and regexp_replace(coalesce(e.phone, ''), '[^0-9]', '', 'g') = v_phone_digits then 2
          when length(v_whatsapp_digits) >= 7 and regexp_replace(coalesce(e.whatsapp, ''), '[^0-9]', '', 'g') = v_whatsapp_digits then 3
          when v_website is not null and lower(trim(trailing '/' from coalesce(e.website, ''))) = trim(trailing '/' from v_website) then 4
          when v_instagram is not null and lower(trim(trailing '/' from coalesce(e.instagram, ''))) = trim(trailing '/' from v_instagram) then 5
          else 6
        end,
        e.updated_at desc
      limit 1;

      if v_existing_id is null then
        insert into public.local_brain_entries (
          country_code, country, region, city, entry_type, name, category, description,
          phone, whatsapp, email, website, instagram, facebook, tiktok, youtube, x_url, telegram,
          photo_url, address, neighborhood, latitude, longitude, service_radius_km, hours,
          languages, price_level, tags, recommendation_note, admin_notes, priority,
          is_featured, is_verified, is_active, source_type, source_name, source_url,
          source_external_id, source_license, trust_level, last_verified_at, imported_at
        ) values (
          upper(coalesce(nullif(btrim(v_row->>'country_code'), ''), 'MX')),
          coalesce(nullif(btrim(v_row->>'country'), ''), 'Mexico'), nullif(btrim(v_row->>'region'), ''), v_city,
          v_entry_type, v_name, v_category, nullif(btrim(v_row->>'description'), ''), v_phone, v_whatsapp,
          nullif(btrim(v_row->>'email'), ''), nullif(btrim(v_row->>'website'), ''), nullif(btrim(v_row->>'instagram'), ''),
          nullif(btrim(v_row->>'facebook'), ''), nullif(btrim(v_row->>'tiktok'), ''), nullif(btrim(v_row->>'youtube'), ''),
          nullif(btrim(v_row->>'x_url'), ''), nullif(btrim(v_row->>'telegram'), ''), nullif(btrim(v_row->>'photo_url'), ''),
          nullif(btrim(v_row->>'address'), ''), nullif(btrim(v_row->>'neighborhood'), ''), v_lat, v_lon, v_radius,
          nullif(btrim(v_row->>'hours'), ''), v_languages, nullif(btrim(v_row->>'price_level'), ''), v_tags,
          nullif(btrim(v_row->>'recommendation_note'), ''), nullif(btrim(v_row->>'admin_notes'), ''), v_priority,
          v_is_featured, v_is_verified, v_is_active, v_source_type, nullif(btrim(v_row->>'source_name'), ''),
          nullif(btrim(v_row->>'source_url'), ''), v_source_external_id, nullif(btrim(v_row->>'source_license'), ''),
          v_trust, v_last_verified_at, now()
        );
        v_inserted := v_inserted + 1;
      else
        update public.local_brain_entries e set
          country_code = coalesce(nullif(upper(btrim(v_row->>'country_code')), ''), e.country_code),
          country = coalesce(nullif(btrim(v_row->>'country'), ''), e.country),
          region = coalesce(nullif(btrim(v_row->>'region'), ''), e.region),
          city = coalesce(nullif(btrim(v_row->>'city'), ''), e.city),
          entry_type = case when v_row ? 'entry_type' then v_entry_type else e.entry_type end,
          name = coalesce(v_name, e.name), category = coalesce(v_category, e.category),
          description = coalesce(nullif(btrim(v_row->>'description'), ''), e.description),
          phone = coalesce(v_phone, e.phone), whatsapp = coalesce(v_whatsapp, e.whatsapp),
          email = coalesce(nullif(btrim(v_row->>'email'), ''), e.email), website = coalesce(nullif(btrim(v_row->>'website'), ''), e.website),
          instagram = coalesce(nullif(btrim(v_row->>'instagram'), ''), e.instagram), facebook = coalesce(nullif(btrim(v_row->>'facebook'), ''), e.facebook),
          tiktok = coalesce(nullif(btrim(v_row->>'tiktok'), ''), e.tiktok), youtube = coalesce(nullif(btrim(v_row->>'youtube'), ''), e.youtube),
          x_url = coalesce(nullif(btrim(v_row->>'x_url'), ''), e.x_url), telegram = coalesce(nullif(btrim(v_row->>'telegram'), ''), e.telegram),
          photo_url = coalesce(nullif(btrim(v_row->>'photo_url'), ''), e.photo_url), address = coalesce(nullif(btrim(v_row->>'address'), ''), e.address),
          neighborhood = coalesce(nullif(btrim(v_row->>'neighborhood'), ''), e.neighborhood), latitude = coalesce(v_lat, e.latitude),
          longitude = coalesce(v_lon, e.longitude), service_radius_km = coalesce(v_radius, e.service_radius_km),
          hours = coalesce(nullif(btrim(v_row->>'hours'), ''), e.hours),
          languages = (select coalesce(array_agg(distinct x order by x), '{}'::text[]) from unnest(coalesce(e.languages, '{}'::text[]) || coalesce(v_languages, '{}'::text[])) as x where btrim(x) <> ''),
          price_level = coalesce(nullif(btrim(v_row->>'price_level'), ''), e.price_level),
          tags = (select coalesce(array_agg(distinct x order by x), '{}'::text[]) from unnest(coalesce(e.tags, '{}'::text[]) || coalesce(v_tags, '{}'::text[])) as x where btrim(x) <> ''),
          recommendation_note = coalesce(nullif(btrim(v_row->>'recommendation_note'), ''), e.recommendation_note),
          admin_notes = coalesce(nullif(btrim(v_row->>'admin_notes'), ''), e.admin_notes), priority = greatest(e.priority, v_priority),
          is_featured = e.is_featured or v_is_featured, is_verified = e.is_verified or v_is_verified,
          is_active = case when v_row ? 'is_active' then v_is_active else e.is_active end,
          source_type = case when v_source_external_id is not null or nullif(btrim(v_row->>'source_name'), '') is not null then v_source_type else e.source_type end,
          source_name = coalesce(nullif(btrim(v_row->>'source_name'), ''), e.source_name), source_url = coalesce(nullif(btrim(v_row->>'source_url'), ''), e.source_url),
          source_external_id = coalesce(v_source_external_id, e.source_external_id), source_license = coalesce(nullif(btrim(v_row->>'source_license'), ''), e.source_license),
          trust_level = case
            when (case v_trust when 'official' then 4 when 'recommended' then 3 when 'trusted' then 2 else 1 end)
               > (case e.trust_level when 'official' then 4 when 'recommended' then 3 when 'trusted' then 2 else 1 end)
            then v_trust else e.trust_level end,
          last_verified_at = case when v_last_verified_at is null then e.last_verified_at when e.last_verified_at is null then v_last_verified_at else greatest(e.last_verified_at, v_last_verified_at) end,
          imported_at = now()
        where e.id = v_existing_id;
        v_updated := v_updated + 1;
      end if;
    exception when others then
      v_skipped := v_skipped + 1;
    end;
  end loop;

  return query select v_inserted, v_updated, v_skipped;
end;
$$;

revoke all on function public.rpc_import_local_brain_entries(jsonb) from public;
grant execute on function public.rpc_import_local_brain_entries(jsonb) to authenticated;

drop function if exists public.rpc_search_local_brain(text,text,double precision,double precision,integer);

create function public.rpc_search_local_brain(
  p_query text,
  p_city text default null,
  p_lat double precision default null,
  p_lon double precision default null,
  p_limit integer default 8
)
returns table (
  id uuid, entry_type text, name text, category text, description text, phone text, whatsapp text,
  email text, website text, instagram text, facebook text, tiktok text, youtube text, x_url text,
  telegram text, photo_url text, address text, neighborhood text, city text, region text, country text,
  latitude double precision, longitude double precision, service_radius_km double precision, hours text,
  languages text[], price_level text, tags text[], recommendation_note text, is_featured boolean,
  is_verified boolean, priority integer, linked_profile_user_id uuid, linked_listing_id uuid,
  swipess_profile_user_id uuid, swipess_listing_id uuid, card_image_url text, distance_km double precision
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
      extensions.unaccent(lower(concat_ws(' ', e.name, e.category, e.description, e.neighborhood, e.city, e.region, e.country,
        array_to_string(e.tags, ' '), array_to_string(e.languages, ' '), e.recommendation_note, e.source_name, e.source_type))) as search_blob,
      extensions.unaccent(lower(e.name)) as normalized_name,
      case e.trust_level when 'official' then 4 when 'recommended' then 3 when 'trusted' then 2 else 1 end as trust_rank,
      case when e.source_type in ('denue','siem','sectur') then 2 when e.source_type = 'osm' then 1 else 0 end as source_rank,
      case when e.last_verified_at is null then 0 when e.last_verified_at >= now() - interval '180 days' then 2 when e.last_verified_at >= now() - interval '365 days' then 1 else 0 end as freshness_rank,
      case
        when p_lat is not null and p_lon is not null and e.latitude is not null and e.longitude is not null then
          6371.0 * acos(least(1.0, greatest(-1.0,
            cos(radians(p_lat)) * cos(radians(e.latitude)) * cos(radians(e.longitude) - radians(p_lon))
            + sin(radians(p_lat)) * sin(radians(e.latitude))
          )))
        else null
      end as calculated_distance_km,
      case
        when nullif(trim(coalesce(p_city, '')), '') is not null and (lower(p_city) like '%' || lower(e.city) || '%' or lower(e.city) like '%' || lower(p_city) || '%') then 2
        when lower(e.city) = 'global' then 1 else 0
      end as location_rank
    from public.local_brain_entries e
    where e.is_active = true
  ), tokens as (
    select distinct token
    from regexp_split_to_table(extensions.unaccent(lower(coalesce(p_query, ''))), E'\\s+') as token
    where length(token) >= 3
      and token not in ('the','and','for','with','from','that','this','what','where','who','find','best','near','nearby','local','please','want','need','looking','around','give','show','get','can','you','me','somebody','someone','something','una','uno','unos','unas','que','por','para','con','del','los','las','donde','quien','busco','buscar','mejor','cerca','locales','alguien','algo','quiero','necesito')
  ), scored as (
    select
      b.*,
      coalesce((select count(*)::integer from tokens t where b.search_blob like '%' || t.token || '%'), 0) as exact_token_matches,
      coalesce((select max(extensions.similarity(t.token, term)) from tokens t cross join lateral regexp_split_to_table(b.search_blob, E'\\s+') term where length(term) >= 4), 0::real) as fuzzy_score,
      coalesce((select min(extensions.levenshtein(t.token, term)) from tokens t cross join lateral regexp_split_to_table(b.search_blob, E'\\s+') term where length(t.token) >= 5 and length(term) >= 5 and abs(length(t.token)-length(term)) <= 3), 99) as edit_distance,
      (extensions.unaccent(lower(coalesce(p_query, ''))) like '%' || b.normalized_name || '%') as exact_name_in_query
    from base b
  )
  select
    s.id, s.entry_type, s.name, s.category, s.description, s.phone, s.whatsapp, s.email, s.website, s.instagram,
    s.facebook, s.tiktok, s.youtube, s.x_url, s.telegram, s.photo_url, s.address, s.neighborhood, s.city, s.region,
    s.country, s.latitude, s.longitude, s.service_radius_km, s.hours, s.languages, s.price_level, s.tags,
    s.recommendation_note, s.is_featured, s.is_verified, s.priority, s.linked_profile_user_id, s.linked_listing_id,
    coalesce(s.linked_profile_user_id, matched_profile.user_id) as swipess_profile_user_id,
    s.linked_listing_id as swipess_listing_id,
    coalesce(nullif(s.photo_url, ''), matched_profile.image_url, linked_listing.image_url) as card_image_url,
    s.calculated_distance_km
  from scored s
  left join lateral (
    select p.user_id, coalesce(nullif(p.profile_photo_url, ''), nullif(p.avatar_url, ''), nullif(p.avatar, ''), p.profile_images[1]) as image_url
    from public.profiles p
    where p.is_active = true and (
      (s.linked_profile_user_id is not null and p.user_id = s.linked_profile_user_id)
      or (s.linked_profile_user_id is null and (
        (nullif(trim(s.email), '') is not null and lower(coalesce(p.email, '')) = lower(s.email))
        or (length(regexp_replace(coalesce(s.phone, ''), '[^0-9]', '', 'g')) >= 7 and regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g') = regexp_replace(s.phone, '[^0-9]', '', 'g'))
      ))
    )
    order by case when s.linked_profile_user_id is not null and p.user_id = s.linked_profile_user_id then 0 else 1 end
    limit 1
  ) matched_profile on true
  left join lateral (
    select l.id, l.images[1] as image_url from public.listings l
    where s.linked_listing_id is not null and l.id = s.linked_listing_id and l.is_active = true and l.status = 'active'
    limit 1
  ) linked_listing on true
  where nullif(trim(coalesce(p_query, '')), '') is null
     or s.exact_name_in_query or s.exact_token_matches > 0 or s.fuzzy_score >= 0.32 or s.edit_distance <= 2
     or (s.edit_distance <= 3 and exists (select 1 from tokens t where length(t.token) >= 7))
  order by
    s.location_rank desc, s.exact_name_in_query desc, s.exact_token_matches desc, s.edit_distance asc,
    s.fuzzy_score desc, s.trust_rank desc, s.is_featured desc, s.is_verified desc, s.freshness_rank desc,
    s.source_rank desc, s.calculated_distance_km asc nulls last, s.priority desc, s.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 8), 20));
end;
$$;

revoke all on function public.rpc_search_local_brain(text,text,double precision,double precision,integer) from public;
grant execute on function public.rpc_search_local_brain(text,text,double precision,double precision,integer) to authenticated;
