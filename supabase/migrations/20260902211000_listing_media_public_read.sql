-- Keep public listing media readable and allow Storage upsert flows to satisfy
-- Supabase's SELECT requirement for public buckets.
--
-- Production already has these policies; this migration records the fix in git
-- so fresh environments and future resets stay aligned with production.

update storage.buckets
set public = true
where id in ('listing-videos', 'listing-audio');

drop policy if exists "listing videos public read" on storage.objects;
create policy "listing videos public read"
on storage.objects for select to public
using (bucket_id = 'listing-videos');

drop policy if exists "listing audio public read" on storage.objects;
create policy "listing audio public read"
on storage.objects for select to public
using (bucket_id = 'listing-audio');
