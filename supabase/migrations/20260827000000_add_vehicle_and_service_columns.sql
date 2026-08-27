ALTER TABLE public.listings
ADD COLUMN IF NOT EXISTS vehicle_brand text,
ADD COLUMN IF NOT EXISTS vehicle_model text,
ADD COLUMN IF NOT EXISTS year integer,
ADD COLUMN IF NOT EXISTS mileage integer,
ADD COLUMN IF NOT EXISTS service_category text;
