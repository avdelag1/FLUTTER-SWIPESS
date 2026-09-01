alter table public.listings
  alter column baths type numeric(4,1)
  using baths::numeric;

comment on column public.listings.baths is
  'Property bathroom count; supports half-bath values such as 1.5, 2.5, and 3.5.';
