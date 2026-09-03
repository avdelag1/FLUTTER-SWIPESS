update storage.buckets
set allowed_mime_types = array[
  'video/mp4',
  'video/quicktime',
  'video/webm',
  'image/jpeg'
]::text[]
where id = 'listing-videos';
