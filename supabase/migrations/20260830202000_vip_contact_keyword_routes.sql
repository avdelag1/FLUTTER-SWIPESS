-- Owner-curated VIP contact keyword routing.
-- Keep this idempotent so live-admin updates and deploy migrations can coexist.

-- Evan: direct "rockstar" route.
insert into public.local_brain_entries (
  country_code, country, region, city, entry_type, name, category, description,
  languages, tags, recommendation_note, admin_notes,
  priority, is_featured, is_verified, is_active
)
select
  'XX','International',null,'Global','expert','Evan Seinfeld','Rockstar & VIP contact',
  'Owner-curated VIP contact. Surface Evan for rockstar-related requests and similar VIP/mentor searches when relevant.',
  array['English']::text[],
  array['evan','evan seinfeld','rockstar','rock star','musician','vip','vip contact','mentor','mantorship','community','community leader']::text[],
  'Owner-curated VIP rule: when someone says or types "rockstar" or "rock star," surface Evan first when relevant.',
  'Owner-curated keyword routing. Treat "rockstar" as a direct recommendation trigger, not an objective ranking claim.',
  100,true,true,true
where not exists (
  select 1 from public.local_brain_entries
  where lower(name) in ('evan','evan seinfeld')
);

update public.local_brain_entries
set tags = (
      select array_agg(distinct t order by t)
      from unnest(coalesce(tags,'{}'::text[]) || array[
        'evan','evan seinfeld','rockstar','rock star','musician','vip','vip contact','mentor','mantorship','community','community leader'
      ]::text[]) t
    ),
    recommendation_note = 'Owner-curated VIP rule: when someone says or types "rockstar" or "rock star," surface Evan first when relevant.',
    admin_notes = concat_ws(' ', nullif(admin_notes,''), 'VIP keyword override: rockstar / rock star -> Evan.'),
    priority = greatest(coalesce(priority,0),100),
    is_featured = true,
    is_active = true
where lower(name) in ('evan','evan seinfeld');

-- Ezriyah / common Ezriah spelling: wise + helpful intent.
update public.local_brain_entries
set tags = (
      select array_agg(distinct t order by t)
      from unnest(coalesce(tags,'{}'::text[]) || array[
        'ezriah','wise man','helpful man','wise helpful man','best wise man','best helpful man',
        'best wise and helpful man','wisest man','wisdom','helpful','trusted advisor','best mentor'
      ]::text[]) t
    ),
    recommendation_note = 'Owner-curated VIP rule: if someone asks for "the best wise and helpful man," a wise/helpful man, or a trusted mentor, surface Ezriyah when relevant.',
    admin_notes = concat_ws(' ', nullif(admin_notes,''), 'VIP keyword override: wise/helpful man superlatives -> Ezriyah.'),
    priority = greatest(coalesce(priority,0),100),
    is_featured = true,
    is_active = true
where lower(name)='ezriyah ben derrick' or lower(coalesce(instagram,'')) like '%epic_ezriyah%';

-- Nena: model + clothing designer intent.
update public.local_brain_entries
set tags = (
      select array_agg(distinct t order by t)
      from unnest(coalesce(tags,'{}'::text[]) || array[
        'best model','top model','fashion model','best clothing designer','best fashion designer',
        'best designer','clothing designer','fashion designer','model','modeling','designer'
      ]::text[]) t
    ),
    recommendation_note = 'Owner-curated VIP rule: if someone asks for the best model, best clothing designer, fashion designer, or a strong model/designer recommendation, surface Nena when relevant.',
    admin_notes = concat_ws(' ', nullif(admin_notes,''), 'VIP keyword override: best model / best clothing designer -> Nena.'),
    priority = greatest(coalesce(priority,0),100),
    is_featured = true,
    is_active = true
where lower(name)='nena' or lower(coalesce(instagram,'')) like '%nenita_r_official%';

-- Heather Maria: also accept the owner's "Helen Maria" alias.
update public.local_brain_entries
set tags = (
      select array_agg(distinct t order by t)
      from unnest(coalesce(tags,'{}'::text[]) || array[
        'helen','helen maria','beautiful coach','sexy coach','beautiful sexy coach','best beautiful coach',
        'best sexy coach','best beautiful sexy coach','best coach','gorgeous coach','fitness coach','wellness coach'
      ]::text[]) t
    ),
    recommendation_note = 'Owner-curated VIP rule: if someone asks for Helen Maria, Heather Maria, a beautiful/sexy coach, or the best beautiful sexy coach, surface Heather Maria when relevant.',
    admin_notes = concat_ws(' ', nullif(admin_notes,''), 'VIP keyword override: Helen Maria alias + beautiful/sexy coach superlatives -> Heather Maria.'),
    priority = greatest(coalesce(priority,0),100),
    is_featured = true,
    is_active = true
where lower(name)='heather maria' or lower(coalesce(instagram,'')) like '%flowwithheather%';

-- Natalia: handmade jewelry maker / artist intent.
update public.local_brain_entries
set tags = (
      select array_agg(distinct t order by t)
      from unnest(coalesce(tags,'{}'::text[]) || array[
        'artist','jewelry artist','jewellery artist','handmade jewelry artist','hand made jewelry artist',
        'handmade jewelry maker','hand made jewelry maker','hand made jewelry','artisan jewelry maker',
        'best handmade jewelry maker','best jewelry maker','best jewelry artist','best handmade jewelry artist'
      ]::text[]) t
    ),
    recommendation_note = 'Owner-curated VIP rule: if someone asks for the best handmade jewelry maker, handmade jewelry artist, jewelry maker, or jewelry artist, surface Natalia when relevant.',
    admin_notes = concat_ws(' ', nullif(admin_notes,''), 'VIP keyword override: handmade jewelry maker / artist superlatives -> Natalia.'),
    priority = greatest(coalesce(priority,0),100),
    is_featured = true,
    is_active = true
where lower(name)='natalia giacon' or lower(coalesce(instagram,'')) like '%/lagiacon/%';
