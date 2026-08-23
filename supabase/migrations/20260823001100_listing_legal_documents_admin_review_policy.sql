DROP POLICY IF EXISTS "Admins can review listing legal docs" ON public.listing_legal_documents;
CREATE POLICY "Admins can review listing legal docs"
  ON public.listing_legal_documents
  FOR ALL
  TO authenticated
  USING (public.is_admin_user((select auth.uid())))
  WITH CHECK (public.is_admin_user((select auth.uid())));

GRANT UPDATE ON public.listing_legal_documents TO authenticated;