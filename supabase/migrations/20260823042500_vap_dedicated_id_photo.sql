-- A Virtual ID/PEARL identity photo is separate from the user's normal profile avatar.
ALTER TABLE public.vap_id_cards
  ADD COLUMN IF NOT EXISTS id_photo_url text;

COMMENT ON COLUMN public.vap_id_cards.id_photo_url IS
  'Dedicated identity photo for the Virtual ID/PEARL card; does not overwrite the normal profile avatar.';
