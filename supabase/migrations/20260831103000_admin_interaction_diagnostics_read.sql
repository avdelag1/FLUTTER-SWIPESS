-- Super/Admin users can inspect privacy-minimal UI diagnostics from the admin app.
-- End users still only have INSERT permission for their own events.

DROP POLICY IF EXISTS app_interaction_diagnostics_select_admin
  ON public.app_interaction_diagnostics;

CREATE POLICY app_interaction_diagnostics_select_admin
  ON public.app_interaction_diagnostics
  FOR SELECT TO authenticated
  USING (public._is_active_admin(auth.uid()));
