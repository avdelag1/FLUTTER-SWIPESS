alter table public.listings
  add column if not exists display_order integer;

with ranked as (
  select id,
         row_number() over (
           partition by owner_id
           order by created_at desc nulls last, id
         ) - 1 as pos
  from public.listings
)
update public.listings l
set display_order = ranked.pos
from ranked
where ranked.id = l.id
  and l.display_order is null;

alter table public.listings
  alter column display_order set default 0;

update public.listings set display_order = 0 where display_order is null;
alter table public.listings alter column display_order set not null;

create index if not exists listings_owner_display_order_idx
  on public.listings(owner_id, display_order, created_at desc);

create or replace function public.rpc_filter_discoverable_listing_ids(p_ids uuid[])
returns uuid[]
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select coalesce(array_agg(l.id), array[]::uuid[])
  from public.listings l
  where l.id = any(coalesce(p_ids, array[]::uuid[]))
    and l.owner_id is distinct from auth.uid()
    and public._discovery_listing_visible(
      auth.uid(), l.id, l.price, l.hourly_rate, l.description, l.images
    );
$$;

revoke all on function public.rpc_filter_discoverable_listing_ids(uuid[]) from public;
grant execute on function public.rpc_filter_discoverable_listing_ids(uuid[]) to authenticated;

create or replace function public.rpc_reorder_my_listings(p_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_ids, array[]::uuid[])) as requested(id)
    left join public.listings l on l.id = requested.id
    where l.id is null or l.owner_id is distinct from auth.uid()
  ) then
    raise exception 'One or more listings are not owned by the current user';
  end if;

  update public.listings l
  set display_order = ordered.pos
  from (
    select id, ordinality::integer - 1 as pos
    from unnest(coalesce(p_ids, array[]::uuid[])) with ordinality as u(id, ordinality)
  ) ordered
  where l.id = ordered.id
    and l.owner_id = auth.uid();
end;
$$;

revoke all on function public.rpc_reorder_my_listings(uuid[]) from public;
grant execute on function public.rpc_reorder_my_listings(uuid[]) to authenticated;
