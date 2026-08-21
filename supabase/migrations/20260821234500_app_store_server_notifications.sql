-- Idempotent ledger and ordering fields for App Store Server Notifications V2.

ALTER TABLE public.user_subscriptions
  ADD COLUMN IF NOT EXISTS store_signed_date timestamptz,
  ADD COLUMN IF NOT EXISTS store_environment text;

CREATE TABLE IF NOT EXISTS public.app_store_server_notifications (
  notification_uuid text PRIMARY KEY,
  notification_type text NOT NULL,
  subtype text,
  signed_date timestamptz,
  environment text,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  product_id text,
  transaction_id text,
  original_transaction_id text,
  status text NOT NULL DEFAULT 'processing'
    CHECK (status IN ('processing','processed','ignored','error')),
  error_message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_store_server_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_store_server_notifications FROM PUBLIC, anon, authenticated;

CREATE INDEX IF NOT EXISTS app_store_notifications_transaction_idx
  ON public.app_store_server_notifications(original_transaction_id, signed_date DESC)
  WHERE original_transaction_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS app_store_notifications_user_idx
  ON public.app_store_server_notifications(user_id, signed_date DESC)
  WHERE user_id IS NOT NULL;
