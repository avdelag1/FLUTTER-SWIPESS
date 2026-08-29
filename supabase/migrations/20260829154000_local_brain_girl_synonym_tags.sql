-- Improve keyword matching for feminine descriptor searches like "canadian girl".
update public.local_brain_entries
set tags = array(
  select distinct unnest(coalesce(tags, '{}'::text[]) || array['girl', 'girls', 'female']::text[])
)
where lower(name) = 'heather maria';
