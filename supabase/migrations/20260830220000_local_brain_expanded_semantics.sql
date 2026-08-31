-- Expand AI brain with broad semantic bridges matching human queries to app concepts

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
  service_blob := lower(extensions.unaccent(concat_ws(' ', coalesce(e.name, ''), coalesce(e.category, ''), coalesce(e.description, ''), coalesce(e.recommendation_note, ''))));

  -- Exact tokenization
  for part in select unnest(regexp_split_to_array(lower(extensions.unaccent(coalesce(e.name, ''))), E'[^a-z0-9]+')) loop
    if length(part) >= 2 and not part = any (stopwords) then tokens := array_append(tokens, part); end if;
  end loop;
  for part in select unnest(regexp_split_to_array(lower(extensions.unaccent(coalesce(e.category, ''))), E'[^a-z0-9]+')) loop
    if length(part) >= 3 and not part = any (stopwords) then tokens := array_append(tokens, part); end if;
  end loop;

  -- Geo & identity basics
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

  -- Entry type basic synonyms
  if e.entry_type = 'person' then
    tokens := tokens || array['person','people','contact','someone'];
  elsif e.entry_type in ('expert','professional') then
    tokens := tokens || array['expert','professional','specialist'];
  elsif e.entry_type = 'service' then
    tokens := tokens || array['service','services','hire'];
  elsif e.entry_type = 'business' then
    tokens := tokens || array['business','local business'];
  elsif e.entry_type = 'place' then
    tokens := tokens || array['place','spot','location','venue'];
  end if;

  handle := substring(lower(coalesce(e.instagram, '')) from '(?:instagram\.com/|@)([a-z0-9._]+)');
  if handle is not null and length(handle) >= 3 then tokens := array_append(tokens, handle); end if;

  -- Broad Demographics
  if identity_blob ~ '\m(women|woman|female|girl|girls|lady|ladies|feminine|mamacita)\M' then
    tokens := tokens || array['woman','women','female','girl','girls','lady','ladies','mamacita'];
  end if;
  if identity_blob ~ '\m(men|man|male|guy|guys|masculine|mens)\M' then
    tokens := tokens || array['man','men','male','guy','guys','mens'];
  end if;

  -- NEW: Massively expanded semantic bridging for concierge intelligence
  
  -- Spiritual, Healer, Mystic
  if service_blob ~ '\m(shaman|healer|ceremony|ayahuasca|medicine|curandero|curandera|mystic|magic|magician|spiritual)\M' then
    tokens := tokens || array['shaman','spiritual guide','healer','ceremony','mystic','magic','spiritual','medicine','curandero','curandera','guru'];
  end if;
  
  -- Wise, Mentor, Guide
  if service_blob ~ '\m(wise|wisdom|guru|mentor|guide|advisor|counselor|advice)\M' then
    tokens := tokens || array['wise','wisdom','mentor','guide','advisor','guru','advice','counselor'];
  end if;

  -- Real Estate, Properties, Accommodation
  if service_blob ~ '\m(property|properties|house|houses|villa|villas|apartment|apartments|condo|condos|airbnb|real estate|realtor|mansion)\M' then
    tokens := tokens || array['property','properties','house','villa','apartment','condo','airbnb','stay','accommodation','real estate','rent','buy','investment','mansion'];
  end if;

  -- Rooms/Bedrooms logic
  if service_blob ~ '\m(bed|beds|bedroom|bedrooms|br|room|rooms)\M' then
    tokens := tokens || array['bedroom','bedrooms','room','rooms'];
  end if;

  -- Pricing: Cheap/Budget
  if service_blob ~ '\m(cheap|affordable|budget|inexpensive|low cost|deal|value)\M' then
    tokens := tokens || array['cheap','affordable','budget','inexpensive','deal','value'];
  end if;

  -- Pricing: Luxury/VIP
  if service_blob ~ '\m(luxury|expensive|premium|high end|exclusive|vip|elite|best|top|luxurious)\M' then
    tokens := tokens || array['luxury','premium','exclusive','vip','high end','elite','best','top','luxurious','expensive'];
  end if;

  -- Photography/Video
  if service_blob ~ '\m(photo|photos|photographer|photography|video|videographer|drone|content creator|filmmaker|camera|shoot)\M' then
    tokens := tokens || array['photographer','videographer','photos','pictures','video','camera','content creator','drone','shoot','photoshoot','filmmaker'];
  end if;

  -- Chef/Food
  if service_blob ~ '\m(chef|cook|private chef|catering|meal prep|food|restaurant|culinary|dining|eat)\M' then
    tokens := tokens || array['chef','cook','private chef','catering','food','culinary','meal','dinner','restaurant','dining','eat'];
  end if;

  -- Boat/Yacht
  if service_blob ~ '\m(boat|boats|yacht|yachts|sailing|catamaran|sail|charter)\M' then
    tokens := tokens || array['boat','boats','yacht','yachts','sailing','catamaran','sea','ocean','charter'];
  end if;

  -- Vehicles/Rentals
  if service_blob ~ '\m(scooter|scooters|bike|bikes|atv|atvs|motorcycle|motorcycles|rental|rentals|car|cars|vehicle|transport)\M' then
    tokens := tokens || array['rental','rentals','scooter','bike','atv','motorcycle','car','vehicle','transport','ride'];
  end if;

  -- Beauty/Stylist
  if service_blob ~ '\m(hair|stylist|makeup|nails|beauty|salon|barber|haircut|grooming)\M' then
    tokens := tokens || array['beauty','hair','makeup','nails','salon','stylist','barber','haircut','grooming'];
  end if;

  -- Medical/Health
  if service_blob ~ '\m(doctor|dentist|hospital|clinic|medical|health|pharmacy|nurse|care)\M' then
    tokens := tokens || array['doctor','dentist','medical','health','clinic','hospital','pharmacy','care','nurse'];
  end if;

  
  -- Worker/Service broad match (Original logic)
  if service_blob ~ '\m(plumber|plumbing|electrician|electrical|mechanic|cleaner|cleaning|chef|driver|handyman|nanny)\M' then
    tokens := tokens || array['worker','service','professional','hire','local service'];
  end if;

  -- Handyman/Fix
  if service_blob ~ '\m(fix|repair|handyman|plumber|electrician|mechanic|maintenance|worker)\M' then
    tokens := tokens || array['repair','fix','handyman','maintenance','worker','service','help','plumber','electrician','mechanic'];
  end if;

  -- Original service tags logic maintained below
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
  if service_blob ~ '\m(lawyer|abogado|attorney|legal)\M' then tokens := tokens || array['lawyer','abogado','attorney','legal']; end if;
  if service_blob ~ '\m(event|events)\M' then tokens := tokens || array['event','events','activity']; end if;
  if service_blob ~ '\m(party|parties|nightlife|club|bar|drinking|nightclub|drinks)\M' then
    tokens := tokens || array['party','nightlife','event','club','bar','nightclub','going out','drinks','fun','dancing'];
  end if;
  if service_blob ~ '\m(dj|music|musician|producer|techno|house music|live music)\M' then
    tokens := tokens || array['dj','music','nightlife','event','musician','producer','techno','house music','live music','party'];
  end if;
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

revoke all on function public.local_brain_build_auto_tags(public.local_brain_entries) from public, anon, authenticated;

-- Re-run the auto-tags builder to apply the new semantic bridges to existing entries
select public.local_brain_apply_auto_tags();

