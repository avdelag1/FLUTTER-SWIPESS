-- Google Play Real-Time Developer Notifications (RTDN) are delivered via
-- Cloud Pub/Sub. Keep an idempotent server-side ledger so retries cannot apply
-- a subscription lifecycle event twice.

CREATE TABLE IF NOT EXISTS public.google_play_server_notifications (
  event_key text PRIMARY KEY,
  purchase_token text,
  notification_type integer,
  package_name text,
  event_time timestamptz,
  status text NOT NULL DEFAULT 'processing',
  raw jsonb NOT NULL DEFAULT '{}'::jsonb,
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS google_play_server_notifications_purchase_token_idx
  ON public.google_play_server_notifications(purchase_token, created_at DESC);

ALTER TABLE public.google_play_server_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.google_play_server_notifications FROM PUBLIC, anon, authenticated;
