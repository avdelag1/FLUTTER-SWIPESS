-- Hotfix: stop public app RLS policies from failing on direct user_roles checks.
-- The browser was seeing 403 on events and digital_contracts because policies
-- referenced public.user_roles without the exposed roles having SELECT rights.
-- RLS still protects rows: authenticated users can only read their own roles;
-- anon has no auth.uid() and sees no user_roles rows.

GRANT SELECT ON public.user_roles TO anon, authenticated;

GRANT SELECT ON public.events TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.digital_contracts TO authenticated;

DROP POLICY IF EXISTS "admin_all_events" ON public.events;
CREATE POLICY "admin_all_events"
  ON public.events
  FOR ALL
  TO authenticated
  USING (public.is_admin_user((select auth.uid())))
  WITH CHECK (public.is_admin_user((select auth.uid())));

DROP POLICY IF EXISTS "Anyone can view published events" ON public.events;
CREATE POLICY "Anyone can view published events"
  ON public.events
  FOR SELECT
  TO anon, authenticated
  USING (is_published = true);
