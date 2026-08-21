-- Persist stable subscription-chain identifiers so asynchronous store renewal,
-- revoke and refund notifications can map back to the correct Swipess account.
-- `transaction_id` remains the latest validated transaction/order identifier.

ALTER TABLE public.user_subscriptions
  ADD COLUMN IF NOT EXISTS original_transaction_id text,
  ADD COLUMN IF NOT EXISTS app_account_token uuid,
  ADD COLUMN IF NOT EXISTS store text;

CREATE INDEX IF NOT EXISTS user_subscriptions_original_transaction_idx
  ON public.user_subscriptions(original_transaction_id)
  WHERE original_transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS user_subscriptions_app_account_token_idx
  ON public.user_subscriptions(app_account_token)
  WHERE app_account_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS user_subscriptions_store_transaction_idx
  ON public.user_subscriptions(store, transaction_id)
  WHERE transaction_id IS NOT NULL;
