-- Extend listing verification to serious professional/service listings.
-- Private evidence remains visible only to the owner and authorized admins.

DROP POLICY IF EXISTS "Owners can insert legal docs for own listings"
  ON public.listing_legal_documents;

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
        AND l.category IN ('property', 'yacht', 'motorcycle', 'worker')
    )
  );

-- The admin review RLS policy already restricts updates to active admins. This
-- table privilege is still required by Postgres before that RLS policy can run.
GRANT UPDATE ON public.listing_legal_documents TO authenticated;
