-- Remove the owner/test contact from the curated admin Local Brain permanently.
-- This migration intentionally runs after the original seed migration so fresh
-- environments cannot re-introduce the record during a full migration replay.
delete from public.local_brain_entries
where lower(name) = 'alejandro villarreal'
   or lower(coalesce(instagram, '')) like '%instagram.com/avdelag%'
   or regexp_replace(coalesce(whatsapp, ''), '[^0-9]', '', 'g') = '529843160529';
