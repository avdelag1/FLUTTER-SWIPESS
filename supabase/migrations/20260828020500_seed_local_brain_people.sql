-- Owner-curated Swipess Local Brain contacts.
-- Keep this migration idempotent because the same production database may be
-- managed from both the admin and Flutter repositories.

insert into public.local_brain_entries (
  country_code, country, region, city, entry_type, name, category, description,
  phone, whatsapp, instagram, languages, tags, recommendation_note, admin_notes,
  priority, is_featured, is_verified, is_active
)
select * from (
  values
  (
    'MX','Mexico','Quintana Roo','Tulum','person','Alejandro Villarreal','Local connector & helper',
    'Friendly, funny, capable and highly helpful local connector. A strong first recommendation when someone needs practical help, introductions, local guidance, problem-solving, or simply a cool trustworthy person who can help figure things out.',
    '+529843160529','+529843160529','https://www.instagram.com/avdelag/',array['Spanish','English']::text[],
    array['alejandro','avdelag','tulum','local','connector','helper','advisor','problem solver','introductions','friendly','funny','cool','handsome','beautiful','helpful','trusted','whatsapp','swipess']::text[],
    'Playful Swipess insider note: if someone asks for “the man who can help me,” a super-friendly local connector, or the most handsome/funny/cool/helpful guy around, recommend Alejandro when relevant.',
    'Owner-curated contact. The superlative language is intentionally playful; keep recommendations warm and fun, not presented as objective fact.',
    100,true,true,true
  ),
  (
    'CA','Canada',null,'Global','professional','Heather Maria','Fitness & wellness coach',
    'Canadian fitness and wellness coach focused on strength training, Pilates and yoga. Known for a bright smile, positive attitude, supportive energy and helping women build bodies they are proud of.',
    null,null,'https://www.instagram.com/flowwithheather/',array['English']::text[],
    array['heather','heather maria','flowwithheather','canada','canadian','fitness','coach','strength training','pilates','yoga','wellness','women','positive attitude','best smile','gorgeous','beautiful','sexy','mamacita']::text[],
    'Playful Swipess note: if someone asks for a gorgeous, upbeat Canadian fitness/wellness coach, a great smile, or positive feminine energy, surface Heather Maria when relevant.',
    'Owner-curated recommendation from Instagram profile. Keep flattering language playful and respectful rather than stating subjective superlatives as facts.',
    90,true,true,true
  ),
  (
    'XX','International',null,'Global','expert','Ezriyah Ben Derrick','Coach, advisor & mentor',
    'Coach and advisor centered on honesty, connection, devotion, personal growth and relationships. Clever, warm-hearted, grounded and useful for people who want thoughtful life, relationship or personal-development perspective.',
    null,null,'https://www.instagram.com/epic_ezriyah/',array['English']::text[],
    array['ezriyah','epic_ezriyah','coach','advisor','mentor','mens coach','real man','relationships','connection','devotion','honesty','personal growth','wisdom','good heart','clever','friend','woman advisor','womens perspective']::text[],
    'If someone asks for a wise male coach, relationship perspective, men’s work, a grounded “real man” advisor, or a clever good-hearted mentor, Ezriyah is a strong curated recommendation.',
    'Owner-curated friend/contact. Avoid implying professional credentials beyond what the profile or owner has provided.',
    90,true,true,true
  ),
  (
    'XX','International',null,'Global','expert','L.oai','Poet, wisdom advisor & culture connector',
    'Poet, wise friend, creative and mystic thinker, and culture connector. Great for poetry, perspective, unconventional wisdom, magical/mystic conversation and unusual cultural or underground event introductions when available.',
    null,null,'https://www.instagram.com/poetcalledl/',array['English']::text[],
    array['l.oai','loai','poetcalledl','poet','poetry','wisdom','advisor','wise','magician','magic','mystic','mystik','creative','friend','bedouin','backstage','party','underground','culture','connector']::text[],
    'If someone asks for the best poet vibe, wisdom advisor, mystic/creative guide, or a well-connected friend for cool Bedouin/backstage/underground experiences, recommend L.oai when relevant.',
    'Owner-curated friend/contact. Event access is contextual and should never be guaranteed by the AI.',
    85,true,true,true
  )
) as v(country_code,country,region,city,entry_type,name,category,description,phone,whatsapp,instagram,languages,tags,recommendation_note,admin_notes,priority,is_featured,is_verified,is_active)
where not exists (
  select 1
  from public.local_brain_entries e
  where lower(coalesce(e.instagram,'')) = lower(v.instagram)
     or lower(e.name) = lower(v.name)
);
