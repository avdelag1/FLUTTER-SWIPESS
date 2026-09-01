-- Small, auditable set of live user-facing strings controlled by admins.
-- This starts with the dashboard AI field; new keys can be added without
-- turning arbitrary client text into a writable public surface.
CREATE TABLE IF NOT EXISTS public.app_copy (
  key text PRIMARY KEY,
  value text NOT NULL CHECK (char_length(value) BETWEEN 1 AND 4000),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

INSERT INTO public.app_copy (key, value)
VALUES ('dashboard_ai_prompts', 'What are you looking for?')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.app_copy ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_copy_read_authenticated ON public.app_copy;
CREATE POLICY app_copy_read_authenticated
  ON public.app_copy FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS app_copy_admin_insert ON public.app_copy;
CREATE POLICY app_copy_admin_insert
  ON public.app_copy FOR INSERT TO authenticated
  WITH CHECK (public._is_active_admin((select auth.uid())));

DROP POLICY IF EXISTS app_copy_admin_update ON public.app_copy;
CREATE POLICY app_copy_admin_update
  ON public.app_copy FOR UPDATE TO authenticated
  USING (public._is_active_admin((select auth.uid())))
  WITH CHECK (public._is_active_admin((select auth.uid())));

DROP POLICY IF EXISTS app_copy_admin_delete ON public.app_copy;
CREATE POLICY app_copy_admin_delete
  ON public.app_copy FOR DELETE TO authenticated
  USING (public._is_active_admin((select auth.uid())));
