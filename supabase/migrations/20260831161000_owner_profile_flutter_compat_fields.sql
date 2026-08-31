-- Flutter public/current owner profile readers expect `city` and `bio`.
-- Production owner_profiles still used the older Capacitor names
-- `business_location` and `business_description`, which caused PostgREST 400s.

alter table public.owner_profiles
  add column if not exists city text,
  add column if not exists bio text;

update public.owner_profiles
set city = coalesce(nullif(btrim(city), ''), nullif(btrim(business_location), '')),
    bio = coalesce(nullif(btrim(bio), ''), nullif(btrim(business_description), ''))
where city is null or btrim(city) = '' or bio is null or btrim(bio) = '';
