-- Map presence status (Instagram-style) + return status in profile RPC.

ALTER TABLE public.client_profiles
  ADD COLUMN IF NOT EXISTS map_status text;

COMMENT ON COLUMN public.client_profiles.map_status IS
  'Optional map presence: work, chill, eat, travel, party, fitness';

CREATE OR REPLACE FUNCTION public.get_passport_map_profiles(
  p_user_lat double precision,
  p_user_lon double precision,
  p_radius_km double precision DEFAULT 50,
  p_limit integer DEFAULT 180,
  p_exclude_user_id uuid DEFAULT NULL
)
RETURNS TABLE (
  user_id uuid,
  name text,
  city text,
  bio text,
  age integer,
  occupation text,
  profile_images jsonb,
  latitude double precision,
  longitude double precision,
  location_updated_at timestamptz,
  map_visible boolean,
  map_status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT
    cp.user_id,
    cp.name,
    cp.city,
    cp.bio,
    cp.age,
    cp.occupation,
    cp.profile_images,
    cp.latitude::double precision,
    cp.longitude::double precision,
    cp.location_updated_at,
    cp.map_visible,
    cp.map_status
  FROM public.client_profiles cp
  LEFT JOIN public.profiles p ON p.id = cp.user_id
  WHERE COALESCE(cp.map_visible, true) = true
    AND COALESCE(cp.map_force_hidden, false) = false
    AND cp.latitude IS NOT NULL
    AND cp.longitude IS NOT NULL
    AND (p_exclude_user_id IS NULL OR cp.user_id IS DISTINCT FROM p_exclude_user_id)
    AND public.haversine_km(
      p_user_lat, p_user_lon, cp.latitude::double precision, cp.longitude::double precision
    ) <= GREATEST(COALESCE(p_radius_km, 50), 1)
    AND public._discovery_profile_visible(
      auth.uid(),
      cp.user_id,
      COALESCE(p.average_rating, 0),
      COALESCE(p.total_reviews, 0),
      COALESCE(NULLIF(p.bio, ''), NULLIF(cp.vap_bio, ''), cp.bio, ''),
      GREATEST(
        COALESCE(array_length(p.images, 1), 0),
        CASE
          WHEN jsonb_typeof(cp.profile_images) = 'array'
            THEN jsonb_array_length(cp.profile_images)
          ELSE 0
        END
      ),
      COALESCE(p.verified, false)
    )
  ORDER BY public.haversine_km(
    p_user_lat, p_user_lon, cp.latitude::double precision, cp.longitude::double precision
  )
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 180), 400));
$$;

REVOKE ALL ON FUNCTION public.get_passport_map_profiles(
  double precision, double precision, double precision, integer, uuid
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_passport_map_profiles(
  double precision, double precision, double precision, integer, uuid
) TO anon, authenticated;
