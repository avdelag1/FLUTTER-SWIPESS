-- Live Local Brain semantic indexing + administrator ranking control.
-- This migration intentionally sits after the provenance/trust migrations so
-- source_name, source_type, trust_level and last_verified_at already exist.

alter table public.local_brain_entries
  add column if not exists auto_tags text[] not null default '{}'::text[];

comment on column public.local_brain_entries.priority is
  'Admin AI ranking control. Higher values are preferred among relevant Local Brain matches; Swipess clients treat 0-100 as the normal control range.';

create or replace function public.local_brain_build_auto_tags(e public.local_brain_entries)
returns text[]
language plpgsql
stable
set search_path = public
as $$
declare
  tokens text[] := '{}'::text[];
  identity_blob text;
  service_blob text;
  part text;
  handle text;
  stopwords text[] := array[
    'the','and','for','with','from','that','this','what','where','who','your','their','about','into',
    'through','during','before','after','above','below','between','under','again','once','here','when',
    'why','how','all','each','few','more','most','other','some','such','only','own','same','than','too',
    'very','can','will','just','are','was','been','have','has','had','does','did','doing','would','could',
    'should','may','might','must','shall','para','con','por','que','una','uno','unos','unas','los','las',
    'del','como','pero','muy','mas','she','her','him','his','they','them','our','you','not','but'
  ];
begin
  identity_blob := lower(extensions.unaccent(concat_ws(' ',
    coalesce(e.name, ''), coalesce(e.category, ''), coalesce(e.description, ''),
    coalesce(e.country, ''), coalesce(e.region, ''), coalesce(e.city, ''),
    coalesce(e.neighborhood, ''), coalesce(e.entry_type, ''), coalesce(e.recommendation_note, '')
  )));
  service_blob := lower(extensions.unaccent(concat_ws(' ', coalesce(e.name, ''), coalesce(e.category, ''))));

  for part in select unnest(regexp_split_to_array(lower(extensions.unaccent(coalesce(e.name, ''))), E'[^a-z0-9]+')) loop
    if length(part) >= 2 and not part = any (stopwords) then tokens := array_append(tokens, part); end if;
  end loop;
  for part in select unnest(regexp_split_to_array(lower(extensions.unaccent(coalesce(e.category, ''))), E'[^a-z0-9]+')) loop
    if length(part) >= 3 and not part = any (stopwords) then tokens := array_append(tokens, part); end if;
  end loop;

  if coalesce(e.country, '') <> '' then tokens := array_append(tokens, lower(e.country)); end if;
  if identity_blob ~ '\mcanad(a|ian)?\M' then tokens := tokens || array['canada','canadian']; end if;
  if identity_blob ~ '\mmexic(o|an)?\M' then tokens := tokens || array['mexico','mexican']; end if;
  if identity_blob ~ '\m(american|usa|united states)\M' then tokens := tokens || array['american','usa','united states']; end if;
  if identity_blob ~ '\m(british|uk|england)\M' then tokens := tokens || array['british','uk','england']; end if;
  if identity_blob ~ '\m(australia|australian)\M' then tokens := tokens || array['australia','australian']; end if;
  if identity_blob ~ '\m(spanish|spain|espanol|español)\M' then tokens := tokens || array['spanish','spain','espanol','español']; end if;
  if identity_blob ~ '\m(french|france)\M' then tokens := tokens || array['french','france']; end if;
  if identity_blob ~ '\m(italian|italy)\M' then tokens := tokens || array['italian','italy']; end if;
  if identity_blob ~ '\m(colombia|colombian)\M' then tokens := tokens || array['colombia','colombian']; end if;
  if identity_blob ~ '\m(brazil|brasil|brazilian)\M' then tokens := tokens || array['brazil','brasil','brazilian']; end if;
  if identity_blob ~ '\m(argentina|argentinian)\M' then tokens := tokens || array['argentina','argentinian']; end if;

  if coalesce(e.city, '') <> '' and lower(e.city) <> 'global' then tokens := array_append(tokens, lower(e.city)); end if;
  if coalesce(e.neighborhood, '') <> '' then tokens := array_append(tokens, lower(e.neighborhood)); end if;
  if coalesce(e.region, '') <> '' then tokens := array_append(tokens, lower(e.region)); end if;

  if e.entry_type = 'person' then
    tokens := tokens || array['person','people','contact','someone'];
  elsif e.entry_type in ('expert','professional') then
    tokens := tokens || array['expert','professional','specialist'];
  elsif e.entry_type = 'service' then
    tokens := tokens || array['service','services','hire'];
  elsif e.entry_type = 'business' then
    tokens := tokens || array['business','local business'];
  elsif e.entry_type = 'place' then
    tokens := tokens || array['place','spot','location'];
  end if;

  handle := substring(lower(coalesce(e.instagram, '')) from '(?:instagram\.com/|@)([a-z0-9._]+)');
  if handle is not null and length(handle) >= 3 then tokens := array_append(tokens, handle); end if;

  if identity_blob ~ '\m(women|woman|female|girl|girls|lady|ladies|feminine|mamacita)\M' then
    tokens := tokens || array['woman','women','female','girl','girls','lady','ladies','mamacita'];
  end if;
  if identity_blob ~ '\m(men|man|male|guy|guys|masculine|mens)\M' then
    tokens := tokens || array['man','men','male','guy','guys','mens'];
  end if;

  if service_blob ~ '\m(fitness|workout|gym|trainer|strength)\M' then
    tokens := tokens || array['fitness','trainer','personal trainer','workout','gym','exercise','strength','entrenadora','gimnasio'];
  end if;
  if service_blob ~ '\myoga\M' then tokens := tokens || array['yoga','wellness','yoga class','yoga teacher']; end if;
  if service_blob ~ '\mpilates\M' then tokens := tokens || array['pilates','wellness','pilates class','pilates instructor']; end if;
  if service_blob ~ '\m(massage|masseuse|masaje|masajista|spa|bodywork)\M' then
    tokens := tokens || array['massage','masseuse','massage therapist','masaje','masajista','spa','bodywork','relaxation','therapist'];
  end if;
  if service_blob ~ '\m(dance|dancing|salsa|bachata|dance school|dance class|dance classes)\M' then
    tokens := tokens || array['dance','dancing','salsa','bachata','dance class','dance lesson','classes','activity','things to do'];
  end if;
  if service_blob ~ '\m(tour|tours|tour guide|guide|guides|excursion|excursions)\M' then
    tokens := tokens || array['tour','tours','guide','tour guide','excursion','activity','things to do'];
  end if;
  if service_blob ~ '\m(experience|experiences)\M' then tokens := tokens || array['experience','experiences','activity','things to do']; end if;
  if service_blob ~ '\m(adventure|adventures)\M' then tokens := tokens || array['adventure','activity','things to do']; end if;
  if service_blob ~ '\m(diving|dive|scuba|snorkel|snorkeling)\M' then
    tokens := tokens || array['diving','dive','scuba','scuba diving','snorkel','snorkeling','water activity'];
  end if;
  if service_blob ~ '\m(hotel|hotels|hostel|hostels|resort|resorts|lodging|accommodation|hospitality)\M' then
    tokens := tokens || array['hotel','hostel','resort','lodging','accommodation','stay','hospitality'];
  end if;
  if service_blob ~ '\m(transport|transportation|driver|taxi|shuttle|transfer|airport transfer)\M' then
    tokens := tokens || array['transport','transportation','driver','taxi','shuttle','transfer','airport transfer','ride'];
  end if;
  if service_blob ~ '\m(jewel|jewels|jewelry|jewellery|jeweller|jeweler|joyeria|joyería|necklace|bracelet|ring|rings|earring|earrings)\M' then
    tokens := tokens || array['jewelry','jeweller','jeweler','jewellery','joyeria','joyería','necklace','bracelet','ring','earring','artisan'];
  end if;
  if service_blob ~ '\m(coach|mentor|advisor|relationship|dating|personal development|life coach)\M' then
    tokens := tokens || array['coach','mentor','advisor','relationship','dating','life coach','personal development','guidance'];
  end if;
  if service_blob ~ '\m(poet|poetry|poem|spoken word|writer|writing)\M' then
    tokens := tokens || array['poet','poetry','poem','spoken word','writer','writing','creative'];
  end if;
  if service_blob ~ '\m(connector|local help|introduction|fixer|concierge)\M' then
    tokens := tokens || array['connector','local help','introduction','fixer','concierge','help','trusted local'];
  end if;
  if service_blob ~ '\m(fashion|stylist|clothing|apparel|wardrobe|moda)\M' then
    tokens := tokens || array['fashion','stylist','clothing','apparel','wardrobe','moda','outfit'];
  end if;
  if service_blob ~ '\m(plumber|plumbing|electrician|electrical|mechanic|cleaner|cleaning|chef|driver|handyman|nanny)\M' then
    tokens := tokens || array['worker','service','professional','hire','local service'];
  end if;
  if service_blob ~ '\m(lawyer|abogado|attorney|legal)\M' then tokens := tokens || array['lawyer','abogado','attorney','legal']; end if;
  if service_blob ~ '\m(restaurant|restaurants|food|dining|pizza|burger|burgers|chef)\M' then tokens := tokens || array['restaurant','food','dining','eat','comida','restaurante']; end if;
  if service_blob ~ '\m(event|events)\M' then tokens := tokens || array['event','events','activity']; end if;
  if service_blob ~ '\m(party|parties|nightlife)\M' then tokens := tokens || array['party','nightlife','event']; end if;
  if service_blob ~ '\mdj\M' then tokens := tokens || array['dj','music','nightlife','event']; end if;
  if service_blob ~ '\m(festival|festivals)\M' then tokens := tokens || array['festival','event','events']; end if;

  for part in select unnest(coalesce(e.languages, '{}'::text[])) loop
    if length(lower(btrim(part))) >= 3 then tokens := array_append(tokens, lower(btrim(part))); end if;
  end loop;

  return coalesce((
    select array_agg(t order by t)
    from (
      select distinct lower(btrim(x)) as t
      from unnest(tokens) x
      where length(btrim(x)) >= 2 and lower(btrim(x)) not in (select unnest(stopwords))
      limit 80
    ) deduped
  ), '{}'::text[]);
end;
$$;

create or replace function public.local_brain_apply_auto_tags()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.auto_tags := public.local_brain_build_auto_tags(new);
  return new;
end;
$$;

drop trigger if exists trg_local_brain_auto_tags on public.local_brain_entries;
create trigger trg_local_brain_auto_tags
before insert or update on public.local_brain_entries
for each row execute function public.local_brain_apply_auto_tags();

update public.local_brain_entries e set auto_tags = public.local_brain_build_auto_tags(e);

create or replace function public.rpc_preview_local_brain_auto_tags(p_entry jsonb)
returns text[]
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  fake public.local_brain_entries;
begin
  if auth.uid() is null or not coalesce(public.local_brain_staff_can_manage(), false) then
    raise exception 'Not authorized to preview Local Brain auto tags.' using errcode = '42501';
  end if;

  fake.country := coalesce(nullif(btrim(p_entry->>'country'), ''), '');
  fake.country_code := coalesce(nullif(upper(btrim(p_entry->>'country_code')), ''), 'MX');
  fake.region := nullif(btrim(p_entry->>'region'), '');
  fake.city := coalesce(nullif(btrim(p_entry->>'city'), ''), 'Tulum');
  fake.entry_type := lower(coalesce(nullif(btrim(p_entry->>'entry_type'), ''), 'person'));
  fake.name := coalesce(nullif(btrim(p_entry->>'name'), ''), '');
  fake.category := coalesce(nullif(btrim(p_entry->>'category'), ''), '');
  fake.description := nullif(btrim(p_entry->>'description'), '');
  fake.instagram := nullif(btrim(p_entry->>'instagram'), '');
  fake.neighborhood := nullif(btrim(p_entry->>'neighborhood'), '');
  fake.recommendation_note := nullif(btrim(p_entry->>'recommendation_note'), '');
  fake.languages := '{}'::text[];
  if jsonb_typeof(p_entry->'languages') = 'array' then
    select coalesce(array_agg(distinct btrim(x)) filter (where btrim(x) <> ''), '{}'::text[])
      into fake.languages from jsonb_array_elements_text(p_entry->'languages') as x;
  elsif coalesce(p_entry->>'languages', '') <> '' then
    select coalesce(array_agg(distinct btrim(x)) filter (where btrim(x) <> ''), '{}'::text[])
      into fake.languages from unnest(string_to_array(p_entry->>'languages', ',')) as x;
  end if;
  fake.tags := '{}'::text[];
  return public.local_brain_build_auto_tags(fake);
end;
$$;

revoke all on function public.rpc_preview_local_brain_auto_tags(jsonb) from public, anon;
grant execute on function public.rpc_preview_local_brain_auto_tags(jsonb) to authenticated;

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
  languages text[], price_level text, tags text[], auto_tags text[], recommendation_note text,
  is_featured boolean, is_verified boolean, priority integer, linked_profile_user_id uuid,
  linked_listing_id uuid, swipess_profile_user_id uuid, swipess_listing_id uuid,
  card_image_url text, distance_km double precision
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
  exception when others then v_allowed := false;
  end;
  if not v_allowed then return; end if;

  return query
  with base as (
    select
      e.*,
      extensions.unaccent(lower(concat_ws(' ',
        e.name, e.category, e.description, e.neighborhood, e.city, e.region, e.country,
        array_to_string(e.tags, ' '), array_to_string(coalesce(e.auto_tags, '{}'::text[]), ' '),
        array_to_string(e.languages, ' '), e.recommendation_note, e.source_name, e.source_type
      ))) as search_blob,
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
        when nullif(trim(coalesce(p_city, '')), '') is not null
          and (lower(p_city) like '%' || lower(e.city) || '%' or lower(e.city) like '%' || lower(p_city) || '%') then 2
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
    s.country, s.latitude, s.longitude, s.service_radius_km, s.hours, s.languages, s.price_level, s.tags, s.auto_tags,
    s.recommendation_note, s.is_featured, s.is_verified, s.priority, s.linked_profile_user_id, s.linked_listing_id,
    coalesce(s.linked_profile_user_id, matched_profile.user_id) as swipess_profile_user_id,
    s.linked_listing_id as swipess_listing_id,
    coalesce(nullif(s.photo_url, ''), matched_profile.image_url, linked_listing.image_url) as card_image_url,
    s.calculated_distance_km
  from scored s
  left join lateral (
    select p.user_id,
      coalesce(nullif(p.profile_photo_url, ''), nullif(p.avatar_url, ''), nullif(p.avatar, ''), p.profile_images[1]) as image_url
    from public.profiles p
    where p.is_active = true and (
      (s.linked_profile_user_id is not null and p.user_id = s.linked_profile_user_id)
      or (s.linked_profile_user_id is null and (
        (nullif(trim(s.email), '') is not null and lower(coalesce(p.email, '')) = lower(s.email))
        or (length(regexp_replace(coalesce(s.phone, ''), '[^0-9]', '', 'g')) >= 7
            and regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g') = regexp_replace(s.phone, '[^0-9]', '', 'g'))
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
     or s.exact_name_in_query
     or s.exact_token_matches > 0
     or s.fuzzy_score >= 0.32
     or s.edit_distance <= 2
     or (s.edit_distance <= 3 and exists (select 1 from tokens t where length(t.token) >= 7))
  order by
    s.exact_name_in_query desc,
    s.location_rank desc,
    case when s.exact_token_matches >= 2 then 2 when s.exact_token_matches = 1 then 1 else 0 end desc,
    s.priority desc,
    s.edit_distance asc,
    s.fuzzy_score desc,
    s.trust_rank desc,
    s.is_featured desc,
    s.is_verified desc,
    s.freshness_rank desc,
    s.source_rank desc,
    s.calculated_distance_km asc nulls last,
    s.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 8), 20));
end;
$$;

revoke all on function public.rpc_search_local_brain(text,text,double precision,double precision,integer) from public, anon;
grant execute on function public.rpc_search_local_brain(text,text,double precision,double precision,integer) to authenticated;
revoke all on function public.local_brain_build_auto_tags(public.local_brain_entries) from public, anon, authenticated;
revoke all on function public.local_brain_apply_auto_tags() from public, anon, authenticated;
