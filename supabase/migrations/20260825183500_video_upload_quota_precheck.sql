-- Refuse new listing-video uploads when the signed-in account has no listing capacity.
-- This protects video storage even before the listing insert reaches its hard DB trigger.
drop policy if exists "listing videos insert own folder" on storage.objects;
create policy "listing videos insert own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and coalesce(((public.content_quota_status()->>'can_create_listing')::boolean), false)
);
