-- Store lifecycle notifications need to distinguish natural expiry from a
-- refund/revocation. Existing code continues to use pending/paid/failed/cancelled.

ALTER TABLE public.user_subscriptions
  DROP CONSTRAINT IF EXISTS user_subscriptions_payment_status_check;

ALTER TABLE public.user_subscriptions
  ADD CONSTRAINT user_subscriptions_payment_status_check
  CHECK (payment_status = ANY (ARRAY[
    'pending'::text,
    'paid'::text,
    'failed'::text,
    'cancelled'::text,
    'expired'::text,
    'revoked'::text
  ]));
