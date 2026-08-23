-- Restore the Storage bucket used by the current admin photo manager.
-- Public delivery is intentional because the app stores/displays public URLs;
-- Storage API management stays restricted to authenticated admins.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'admin-uploads',
  'admin-uploads',
  true,
  10485760,
  array['image/jpeg','image/jpg','image/png','image/webp']::text[]
)
on conflict (id) do nothing;

drop policy if exists "admin_uploads_admin_manage" on storage.objects;

create policy "admin_uploads_admin_manage"
on storage.objects
for all
to authenticated
using (
  bucket_id = 'admin-uploads'
  and is_admin_user((select auth.uid()))
)
with check (
  bucket_id = 'admin-uploads'
  and is_admin_user((select auth.uid()))
);
