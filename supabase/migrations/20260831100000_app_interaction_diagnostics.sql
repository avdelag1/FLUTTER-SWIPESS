-- Privacy-minimal interaction diagnostics for finding dead taps, bad navigation,
-- overlap issues and runtime errors from real app sessions.
-- Never stores typed text, chat content, form values, contacts or raw touch pixels.

CREATE TABLE IF NOT EXISTS public.app_interaction_diagnostics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id text NOT NULL,
  event_kind text NOT NULL CHECK (
    event_kind IN ('tap', 'navigation', 'flutter_error', 'platform_error')
  ),
  route_before text,
  route_after text,
  x_norm double precision,
  y_norm double precision,
  outcome text,
  error_type text,
  error_message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_interaction_diagnostics_created
  ON public.app_interaction_diagnostics (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_interaction_diagnostics_user_created
  ON public.app_interaction_diagnostics (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_interaction_diagnostics_route_created
  ON public.app_interaction_diagnostics (route_before, created_at DESC);

ALTER TABLE public.app_interaction_diagnostics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_interaction_diagnostics_insert_own
  ON public.app_interaction_diagnostics;
CREATE POLICY app_interaction_diagnostics_insert_own
  ON public.app_interaction_diagnostics
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

COMMENT ON TABLE public.app_interaction_diagnostics IS
  'Privacy-minimal UI diagnostics: routes, normalized tap positions, navigation outcomes, and sanitized app errors. No typed text or message content is captured.';
