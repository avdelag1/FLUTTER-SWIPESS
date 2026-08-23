-- Listing-specific legal document verification for properties, yachts and motorcycles.
-- Owners can upload private proof docs; public users only see a verified badge after approval.

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS has_verified_documents boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS owner_verified_at timestamptz;

DO $$
BEGIN
  ALTER TABLE public.listings
    ADD CONSTRAINT listings_verification_status_check
    CHECK (verification_status IN ('unverified', 'pending', 'approved', 'rejected'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.listing_legal_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  file_path text NOT NULL,
  mime_type text,
  file_size integer NOT NULL DEFAULT 0 CHECK (file_size >= 0),
  document_type text NOT NULL DEFAULT 'ownership_proof',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  review_notes text,
  reviewed_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (listing_id, file_path)
);

CREATE INDEX IF NOT EXISTS listing_legal_documents_listing_id_idx
  ON public.listing_legal_documents(listing_id);
CREATE INDEX IF NOT EXISTS listing_legal_documents_owner_id_idx
  ON public.listing_legal_documents(owner_id);
CREATE INDEX IF NOT EXISTS listing_legal_documents_status_idx
  ON public.listing_legal_documents(status);

ALTER TABLE public.listing_legal_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owners can read own listing legal docs" ON public.listing_legal_documents;
CREATE POLICY "Owners can read own listing legal docs"
  ON public.listing_legal_documents
  FOR SELECT
  TO authenticated
  USING (owner_id = (select auth.uid()));

DROP POLICY IF EXISTS "Owners can insert legal docs for own listings" ON public.listing_legal_documents;
CREATE POLICY "Owners can insert legal docs for own listings"
  ON public.listing_legal_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    owner_id = (select auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.listings l
      WHERE l.id = listing_id
        AND l.owner_id = (select auth.uid())
        AND l.category IN ('property', 'yacht', 'motorcycle')
    )
  );

DROP POLICY IF EXISTS "Owners can delete pending own listing legal docs" ON public.listing_legal_documents;
CREATE POLICY "Owners can delete pending own listing legal docs"
  ON public.listing_legal_documents
  FOR DELETE
  TO authenticated
  USING (owner_id = (select auth.uid()) AND status = 'pending');

GRANT SELECT, INSERT, DELETE ON public.listing_legal_documents TO authenticated;
REVOKE ALL ON public.listing_legal_documents FROM anon;

INSERT INTO storage.buckets (id, name, public)
VALUES ('legal-documents', 'legal-documents', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can upload own legal document files" ON storage.objects;
CREATE POLICY "Users can upload own legal document files"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'legal-documents'
    AND (
      (storage.foldername(name))[1] = (select auth.uid())::text
      OR (
        (storage.foldername(name))[1] = 'listing-documents'
        AND (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

DROP POLICY IF EXISTS "Users can read own legal document files" ON storage.objects;
CREATE POLICY "Users can read own legal document files"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'legal-documents'
    AND (
      (storage.foldername(name))[1] = (select auth.uid())::text
      OR (
        (storage.foldername(name))[1] = 'listing-documents'
        AND (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

DROP POLICY IF EXISTS "Users can delete own legal document files" ON storage.objects;
CREATE POLICY "Users can delete own legal document files"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'legal-documents'
    AND (
      (storage.foldername(name))[1] = (select auth.uid())::text
      OR (
        (storage.foldername(name))[1] = 'listing-documents'
        AND (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

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
BEGIN
  v_listing_id := COALESCE(NEW.listing_id, OLD.listing_id);

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

  UPDATE public.listings l
  SET
    has_verified_documents = v_has_approved,
    verification_status = CASE
      WHEN v_has_approved THEN 'approved'
      WHEN v_has_pending THEN 'pending'
      WHEN v_has_rejected THEN 'rejected'
      ELSE 'unverified'
    END,
    owner_verified_at = CASE
      WHEN v_has_approved THEN COALESCE(l.owner_verified_at, now())
      ELSE NULL
    END,
    updated_at = now()
  WHERE l.id = v_listing_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE ALL ON FUNCTION public.sync_listing_document_verification() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS listing_legal_documents_sync_verification ON public.listing_legal_documents;
CREATE TRIGGER listing_legal_documents_sync_verification
AFTER INSERT OR UPDATE OF status OR DELETE
ON public.listing_legal_documents
FOR EACH ROW
EXECUTE FUNCTION public.sync_listing_document_verification();

UPDATE public.listings l
SET
  has_verified_documents = EXISTS (
    SELECT 1 FROM public.listing_legal_documents d
    WHERE d.listing_id = l.id AND d.status = 'approved'
  ),
  verification_status = CASE
    WHEN EXISTS (
      SELECT 1 FROM public.listing_legal_documents d
      WHERE d.listing_id = l.id AND d.status = 'approved'
    ) THEN 'approved'
    WHEN EXISTS (
      SELECT 1 FROM public.listing_legal_documents d
      WHERE d.listing_id = l.id AND d.status = 'pending'
    ) THEN 'pending'
    ELSE COALESCE(NULLIF(l.verification_status, ''), 'unverified')
  END;