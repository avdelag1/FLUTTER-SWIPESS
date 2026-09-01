-- Allow authorized admins to grant or revoke the public blue listing badge
-- even when no legal document was submitted. Manual approvals are explicit,
-- auditable admin decisions and remain authoritative until revoked.

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS verification_method text NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS verified_by uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS verification_notes text;

DO $$
BEGIN
  ALTER TABLE public.listings
    ADD CONSTRAINT listings_verification_method_check
    CHECK (verification_method IN ('none', 'document', 'manual'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.rpc_admin_set_listing_verification(
  p_listing_id uuid,
  p_verified boolean,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_admin uuid := auth.uid();
  v_listing public.listings%ROWTYPE;
BEGIN
  IF v_admin IS NULL OR NOT public.is_admin_user(v_admin) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  UPDATE public.listings
  SET
    verification_status = CASE WHEN p_verified THEN 'approved' ELSE 'unverified' END,
    verification_method = CASE WHEN p_verified THEN 'manual' ELSE 'none' END,
    has_verified_documents = false,
    owner_verified_at = CASE WHEN p_verified THEN now() ELSE NULL END,
    verified_by = CASE WHEN p_verified THEN v_admin ELSE NULL END,
    verification_notes = NULLIF(trim(COALESCE(p_note, '')), ''),
    updated_at = now()
  WHERE id = p_listing_id
  RETURNING * INTO v_listing;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Listing not found';
  END IF;

  RETURN jsonb_build_object(
    'listing_id', v_listing.id,
    'verified', p_verified,
    'verification_status', v_listing.verification_status,
    'verification_method', v_listing.verification_method
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_set_listing_verification(uuid, boolean, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_admin_set_listing_verification(uuid, boolean, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.sync_listing_document_verification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_listing_id uuid;
  v_has_approved boolean;
  v_has_pending boolean;
  v_has_rejected boolean;
  v_reviewed_by uuid;
BEGIN
  v_listing_id := COALESCE(NEW.listing_id, OLD.listing_id);

  -- A manual admin approval is authoritative until an admin explicitly revokes it.
  IF EXISTS (
    SELECT 1
    FROM public.listings l
    WHERE l.id = v_listing_id
      AND l.verification_status = 'approved'
      AND l.verification_method = 'manual'
  ) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.listing_legal_documents d
    WHERE d.listing_id = v_listing_id AND d.status = 'approved'
  ) INTO v_has_approved;

  SELECT EXISTS (
    SELECT 1 FROM public.listing_legal_documents d
    WHERE d.listing_id = v_listing_id AND d.status = 'pending'
  ) INTO v_has_pending;

  SELECT EXISTS (
    SELECT 1 FROM public.listing_legal_documents d
    WHERE d.listing_id = v_listing_id AND d.status = 'rejected'
  ) INTO v_has_rejected;

  SELECT d.reviewed_by
  INTO v_reviewed_by
  FROM public.listing_legal_documents d
  WHERE d.listing_id = v_listing_id AND d.status = 'approved'
  ORDER BY d.reviewed_at DESC NULLS LAST, d.created_at DESC
  LIMIT 1;

  UPDATE public.listings l
  SET
    has_verified_documents = v_has_approved,
    verification_status = CASE
      WHEN v_has_approved THEN 'approved'
      WHEN v_has_pending THEN 'pending'
      WHEN v_has_rejected THEN 'rejected'
      ELSE 'unverified'
    END,
    verification_method = CASE WHEN v_has_approved THEN 'document' ELSE 'none' END,
    owner_verified_at = CASE
      WHEN v_has_approved THEN COALESCE(l.owner_verified_at, now())
      ELSE NULL
    END,
    verified_by = CASE WHEN v_has_approved THEN v_reviewed_by ELSE NULL END,
    updated_at = now()
  WHERE l.id = v_listing_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE ALL ON FUNCTION public.sync_listing_document_verification()
  FROM PUBLIC, anon, authenticated;
