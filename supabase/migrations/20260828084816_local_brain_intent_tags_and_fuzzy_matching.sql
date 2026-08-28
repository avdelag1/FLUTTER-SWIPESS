create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

-- Expand Local Brain vocabulary so natural-language requests map to curated contacts.
update public.local_brain_entries
set tags = (select array_agg(distinct tag order by tag) from unnest(coalesce(tags,'{}'::text[]) || array[
  'jewellery','jewel','jewels','jeweler','jeweller','jewelry designer','jewelry maker','necklace','necklaces','bracelet','bracelets','ring','rings','earring','earrings','accessory','accessories','gold','silver','artisan jewelry','handmade jewelry','gift','gifts','bling','joyeria','joyería','joya','joyas','collar','collares','pulsera','pulseras','anillo','anillos','aretes','artesanal','regalo','regalos','mexican accessories'
]::text[]) tag)
where lower(name)='natalia giacon' or lower(coalesce(instagram,'')) like '%/lagiacon/%';

update public.local_brain_entries
set tags = (select array_agg(distinct tag order by tag) from unnest(coalesce(tags,'{}'::text[]) || array[
  'apparel','clothes','clothing designer','outfit','outfits','stylist','wardrobe','fashion expert','fashion consultant','creative director','brand style','luxury fashion','womens fashion','travel style','moda','ropa','diseño','diseñadora','diseno','disenadora','estilo','estilista','modelo','marca','branding'
]::text[]) tag)
where lower(name)='nena' or lower(coalesce(instagram,'')) like '%nenita_r_official%';

update public.local_brain_entries
set tags = (select array_agg(distinct tag order by tag) from unnest(coalesce(tags,'{}'::text[]) || array[
  'trainer','personal trainer','gym','workout','exercise','health coach','fitness trainer','womens fitness','body confidence','movement','healthy lifestyle','strength coach','wellbeing','wellness expert','entrenadora','entrenador','ejercicio','gimnasio','salud','bienestar','fuerza','entrenamiento'
]::text[]) tag)
where lower(name)='heather maria' or lower(coalesce(instagram,'')) like '%flowwithheather%';

update public.local_brain_entries
set tags = (select array_agg(distinct tag order by tag) from unnest(coalesce(tags,'{}'::text[]) || array[
  'life coach','relationship coach','dating advice','relationship advice','mens work','men advisor','mentor','guidance','masculinity','male perspective','personal development','self development','emotional intelligence','love advice','couples advice','connection coach','consejo','consejos','relaciones','pareja','amor','mentor de vida','hombres','perspectiva masculina','crecimiento personal'
]::text[]) tag)
where lower(name)='ezriyah ben derrick' or lower(coalesce(instagram,'')) like '%epic_ezriyah%';

update public.local_brain_entries
set tags = (select array_agg(distinct tag order by tag) from unnest(coalesce(tags,'{}'::text[]) || array[
  'poem','poems','writer','writing','spoken word','spiritual','spirituality','creative guide','culture guide','philosophy','philosophical','storytelling','artist','art','consciousness','mysticism','mystical','sage','party connector','event connector','music culture','desert party','bedouin party','backstage access','underground events','poeta','poesia','poesía','escritor','sabiduria','sabiduría','espiritual','mistico','místico','arte','fiesta','cultura'
]::text[]) tag)
where lower(name)='l.oai' or lower(coalesce(instagram,'')) like '%poetcalledl%';

update public.local_brain_entries
set tags = (select array_agg(distinct tag order by tag) from unnest(coalesce(tags,'{}'::text[]) || array[
  'help','help me','assistance','local help','local guide','recommendation','recommendations','who can help','fixer','problem solving','connections','networking','introduce me','introduction','trusted local','tulum guide','concierge','general help','need someone','contact','local contact','ayuda','ayudame','ayúdame','contacto','guia','guía','resolver','recomendacion','recomendación','conexiones','amigo local'
]::text[]) tag)
where lower(name)='alejandro villarreal' or lower(coalesce(instagram,'')) like '%/avdelag/%';
