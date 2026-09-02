-- Listing creation and editing expose one optional video for every supported
-- marketplace category. Keep the server guardrail aligned with that product
-- behavior so a successful media upload cannot be rejected at the listing row
-- insert step simply because of its category.
update public.platform_media_rules
set video_enabled = true
where content_type in ('property', 'worker', 'motorcycle', 'bicycle', 'yacht');
