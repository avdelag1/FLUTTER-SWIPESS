-- Turn saved_searches.alerts_enabled into a real server-side alert engine.
-- One notification per user/listing, even if several saved searches overlap.

create table if not exists public.saved_search_match_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  saved_search_id uuid not null references public.saved_searches(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, listing_id)
);

alter table public.saved_search_match_deliveries enable row level security;
revoke all on public.saved_search_match_deliveries from anon, authenticated;

create index if not exists saved_search_match_deliveries_search_idx
  on public.saved_search_match_deliveries(saved_search_id, created_at desc);

create index if not exists saved_searches_alerts_enabled_idx
  on public.saved_searches(user_id)
  where alerts_enabled = true;

create or replace function public.notify_saved_search_matches()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_search record;
  v_delivery_id uuid;
  v_search_city text;
  v_search_category text;
  v_min_price numeric;
  v_max_price numeric;
  v_listing_title text;
begin
  -- Only discoverable supply listings can trigger alerts. Seeker/request rows
  -- are demand, not inventory, and should never wake saved-search users.
  if coalesce(new.is_active, true) is not true
     or coalesce(new.status, 'active') <> 'active'
     or coalesce(new.listing_type, '') = 'request'
     or coalesce(new.mode, '') = 'seek' then
    return new;
  end if;

  v_listing_title := coalesce(nullif(trim(new.title), ''), 'A new listing');

  for v_search in
    select id, user_id, search_name, filters
    from public.saved_searches
    where alerts_enabled = true
      and user_id <> new.owner_id
  loop
    v_search_city := nullif(trim(coalesce(v_search.filters->>'city', '')), '');
    v_search_category := nullif(trim(coalesce(v_search.filters->>'category', '')), '');
    v_min_price := case
      when nullif(v_search.filters->>'min_price', '') is null then null
      when (v_search.filters->>'min_price') ~ '^-?[0-9]+([.][0-9]+)?$'
        then (v_search.filters->>'min_price')::numeric
      else null
    end;
    v_max_price := case
      when nullif(v_search.filters->>'max_price', '') is null then null
      when (v_search.filters->>'max_price') ~ '^-?[0-9]+([.][0-9]+)?$'
        then (v_search.filters->>'max_price')::numeric
      else null
    end;

    if v_search_city is not null
       and lower(v_search_city) <> lower(coalesce(new.city, '')) then
      continue;
    end if;

    if v_search_category is not null
       and lower(v_search_category) <> lower(coalesce(new.category, '')) then
      continue;
    end if;

    if v_min_price is not null
       and (new.price is null or new.price < v_min_price) then
      continue;
    end if;

    if v_max_price is not null
       and (new.price is null or new.price > v_max_price) then
      continue;
    end if;

    insert into public.saved_search_match_deliveries (
      user_id, saved_search_id, listing_id
    ) values (
      v_search.user_id, v_search.id, new.id
    )
    on conflict (user_id, listing_id) do nothing
    returning id into v_delivery_id;

    if v_delivery_id is null then
      continue;
    end if;

    insert into public.notifications (
      user_id,
      notification_type,
      title,
      message,
      link_url,
      related_property_id,
      metadata,
      is_read
    ) values (
      v_search.user_id,
      'system_announcement'::public.notification_type,
      'New match · ' || v_search.search_name,
      v_listing_title || case
        when new.city is not null and trim(new.city) <> '' then ' · ' || new.city
        else ''
      end,
      '/listing/' || new.id::text,
      new.id,
      jsonb_build_object(
        'kind', 'saved_search_match',
        'saved_search_id', v_search.id,
        'listing_id', new.id,
        'category', new.category,
        'city', new.city,
        'price', new.price,
        'currency', new.currency
      ),
      false
    );

    update public.saved_searches
    set last_matched_at = now()
    where id = v_search.id;
  end loop;

  return new;
end;
$$;

revoke all on function public.notify_saved_search_matches() from public, anon, authenticated;

drop trigger if exists on_listing_saved_search_match on public.listings;
create trigger on_listing_saved_search_match
after insert or update of status, is_active, category, city, price, listing_type, mode
on public.listings
for each row
execute function public.notify_saved_search_matches();
