-- Worker listing creation already sends the selected languages as a text array.
-- Keep the live listings schema aligned so worker publishes do not need the
-- repository's missing-column fallback before they can save.
alter table public.listings
  add column if not exists languages text[] not null default '{}'::text[];
