-- Event promotion/admin uploads are only performed by signed-in users.
-- Keep the public bucket readable, but do not allow anonymous object creation.

drop policy if exists "Allow public uploads to event-images"
  on storage.objects;

drop policy if exists "Authenticated users can upload event images"
  on storage.objects;

create policy "Authenticated users can upload event images"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'event-images');
