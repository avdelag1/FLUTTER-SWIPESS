-- Passport map visibility (Instagram-style ghost mode) + profile RPC.

ALTER TABLE public.client_profiles
  ADD COLUMN IF NOT EXISTS map_visible boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS map_force_hidden boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS location_source text,
  ADD COLUMN IF NOT EXISTS location_updated_at timestamptz;

CREATE TABLE IF NOT EXISTS public.app_map_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  default_map_visible boolean NOT NULL DEFAULT true,
  require_photo_for_map boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.app_map_settings (id, default_map_visible, require_photo_for_map)
VALUES (1, true, false)
ON CONFLICT (id) DO NOTHING;

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
  map_visible boolean
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
    cp.map_visible
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
