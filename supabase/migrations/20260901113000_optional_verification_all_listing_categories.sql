-- Optional verification is available to every listing category.
-- Documents stay private; only an admin-approved verification badge is public.

drop policy if exists "Owners can upload listing legal docs" on public.listing_legal_documents;
create policy "Owners can upload listing legal docs"
on public.listing_legal_documents
for insert
to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1
    from public.listings l
    where l.id = listing_id
      and l.owner_id = (select auth.uid())
      and lower(coalesce(l.category, '')) in ('property','yacht','motorcycle','bicycle','worker')
  )
);

-- Free accounts can keep six active listings.
update public.account_content_limits
set max_active_listings = 6,
    updated_at = now()
where tier = 'free';
