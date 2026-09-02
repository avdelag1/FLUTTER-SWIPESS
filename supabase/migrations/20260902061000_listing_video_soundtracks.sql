alter table public.listings
  add column if not exists video_audio_enabled boolean not null default true,
  add column if not exists background_music_url text,
  add column if not exists background_music_preset text,
  add column if not exists background_music_name text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'listing-audio',
  'listing-audio',
  true,
  15728640,
  array[
    'audio/mpeg',
    'audio/mp4',
    'audio/x-m4a',
    'audio/aac',
    'audio/wav',
    'audio/x-wav',
    'audio/ogg'
  ]::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "listing audio insert own folder" on storage.objects;
create policy "listing audio insert own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'listing-audio'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "listing audio update own folder" on storage.objects;
create policy "listing audio update own folder"
on storage.objects for update to authenticated
using (
  bucket_id = 'listing-audio'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'listing-audio'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "listing audio delete own folder" on storage.objects;
create policy "listing audio delete own folder"
on storage.objects for delete to authenticated
using (
  bucket_id = 'listing-audio'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
