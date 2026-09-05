-- Studio's native 30fps renderer stores a tiny JSON manifest in the existing
-- listing-videos bucket before the Vercel worker renders the final MP4.
-- Keep every existing media MIME type and add application/json idempotently.
update storage.buckets
set allowed_mime_types = case
  when allowed_mime_types is null then array['application/json']::text[]
  when not ('application/json' = any(allowed_mime_types)) then
    array_append(allowed_mime_types, 'application/json')
  else allowed_mime_types
end
where id = 'listing-videos';
