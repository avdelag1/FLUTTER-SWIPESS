-- Public events feed for the app when premium RLS blocks direct table reads.
-- Dashboard teasers already bypass RLS; this restores the full Events screen.

create or replace function public.rpc_public_events_feed(p_limit integer default 100)
returns table (
  id uuid,
  title text,
  description text,
  category text,
  image_url text,
  image_urls jsonb,
  video_url text,
  video_audio_enabled boolean,
  background_music_url text,
  event_date timestamptz,
  event_end_date timestamptz,
  location text,
  location_detail text,
  organizer_name text,
  organizer_photo_url text,
  organizer_whatsapp text,
  promo_text text,
  discount_tag text,
  is_free boolean,
  price_text text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select
    e.id,
    e.title,
    e.description,
    e.category,
    e.image_url,
    e.image_urls,
    e.video_url,
    coalesce(e.video_audio_enabled, true),
    e.background_music_url,
    e.event_date,
    e.event_end_date,
    e.location,
    e.location_detail,
    e.organizer_name,
    e.organizer_photo_url,
    e.organizer_whatsapp,
    e.promo_text,
    e.discount_tag,
    coalesce(e.is_free, false),
    e.price_text,
    e.created_at
  from public.events e
  where e.is_published = true
    and e.is_approved = true
  order by e.created_at desc nulls last
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
$$;

revoke all on function public.rpc_public_events_feed(integer) from public;
grant execute on function public.rpc_public_events_feed(integer) to anon, authenticated;
