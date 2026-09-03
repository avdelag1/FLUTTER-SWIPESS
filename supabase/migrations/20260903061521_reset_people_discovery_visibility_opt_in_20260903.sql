-- People discovery is explicit opt-in only.
-- Normal listing search/filter activity must never publish a member as a
-- Buyer, Renter, Seeker or Roommate.

update public.client_profiles cp
set
  intentions = coalesce(
    (
      select jsonb_agg(to_jsonb(t.value))
      from jsonb_array_elements_text(coalesce(cp.intentions, '[]'::jsonb)) as t(value)
      where t.value not in ('buyer', 'renter', 'seeker', 'hire_service')
        and t.value !~ '^(buy_|rent_|hire_)'
    ),
    '[]'::jsonb
  ),
  roommate_available = false;

alter table public.client_profiles
  alter column intentions set default '[]'::jsonb,
  alter column roommate_available set default false;
