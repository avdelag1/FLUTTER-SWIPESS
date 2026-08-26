-- Automatically grant the package's promised Direct Requests whenever a paid
-- subscription becomes active or renews. This makes StoreKit/Play writes and
-- the Premium UI converge on the same backend entitlement path.

CREATE OR REPLACE FUNCTION public.service_sync_subscription_direct_requests()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_package_name text;
  v_product_id text;
  v_transaction_key text;
BEGIN
  IF NEW.user_id IS NULL
     OR COALESCE(NEW.is_active, false) IS NOT TRUE
     OR COALESCE(NEW.payment_status, '') <> 'paid' THEN
    RETURN NEW;
  END IF;

  SELECT sp.name
    INTO v_package_name
  FROM public.subscription_packages sp
  WHERE sp.id = NEW.package_id;

  v_product_id := CASE lower(COALESCE(v_package_name, ''))
    WHEN 'basic client' THEN 'Swipess.plus.monthly.v3'
    WHEN 'premium client' THEN 'Swipess.plus.semestral.v3'
    WHEN 'unlimited client' THEN 'Swipess.plus.annual.v3'
    ELSE NULL
  END;

  v_transaction_key := NULLIF(trim(COALESCE(NEW.transaction_id, '')), '');
  IF v_product_id IS NULL OR v_transaction_key IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM public.service_grant_subscription_direct_requests(
    NEW.user_id,
    v_product_id,
    v_transaction_key,
    NEW.end_date
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.service_sync_subscription_direct_requests()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_subscription_direct_requests
  ON public.user_subscriptions;
CREATE TRIGGER trg_sync_subscription_direct_requests
AFTER INSERT OR UPDATE OF package_id, transaction_id, is_active, payment_status, end_date
ON public.user_subscriptions
FOR EACH ROW
EXECUTE FUNCTION public.service_sync_subscription_direct_requests();

-- Top up any historical subscription grant that was created under the old
-- 6 / 12 / 30 configuration. Used credits remain used; only the missing
-- promised amount is added to the same token row.
WITH targets AS (
  SELECT
    g.transaction_key,
    g.token_row_id,
    g.amount AS old_amount,
    CASE g.product_id
      WHEN 'Swipess.plus.monthly.v3' THEN 20
      WHEN 'swipess.plus.monthly.v2' THEN 20
      WHEN 'Swipess.plus.semestral.v3' THEN 50
      WHEN 'swipess.plus.semestral.v2' THEN 50
      WHEN 'Swipess.plus.annual.v3' THEN 150
      WHEN 'swipess.plus.annual.v2' THEN 150
      ELSE g.amount
    END AS target_amount
  FROM public.subscription_direct_request_grants g
)
UPDATE public.tokens t
SET
  amount = COALESCE(t.amount, 0) + (x.target_amount - x.old_amount),
  total_activations = COALESCE(t.total_activations, 0) + (x.target_amount - x.old_amount),
  remaining_activations = COALESCE(t.remaining_activations, 0) + (x.target_amount - x.old_amount),
  updated_at = now()
FROM targets x
WHERE t.id = x.token_row_id
  AND x.target_amount > x.old_amount;

UPDATE public.subscription_direct_request_grants g
SET amount = CASE g.product_id
  WHEN 'Swipess.plus.monthly.v3' THEN GREATEST(g.amount, 20)
  WHEN 'swipess.plus.monthly.v2' THEN GREATEST(g.amount, 20)
  WHEN 'Swipess.plus.semestral.v3' THEN GREATEST(g.amount, 50)
  WHEN 'swipess.plus.semestral.v2' THEN GREATEST(g.amount, 50)
  WHEN 'Swipess.plus.annual.v3' THEN GREATEST(g.amount, 150)
  WHEN 'swipess.plus.annual.v2' THEN GREATEST(g.amount, 150)
  ELSE g.amount
END;

-- Backfill active paid subscriptions that never received a grant at all.
DO $$
DECLARE
  r record;
  v_product_id text;
BEGIN
  FOR r IN
    SELECT
      us.user_id,
      us.transaction_id,
      us.end_date,
      sp.name AS package_name
    FROM public.user_subscriptions us
    JOIN public.subscription_packages sp ON sp.id = us.package_id
    WHERE COALESCE(us.is_active, false) IS TRUE
      AND COALESCE(us.payment_status, '') = 'paid'
      AND NULLIF(trim(COALESCE(us.transaction_id, '')), '') IS NOT NULL
  LOOP
    v_product_id := CASE lower(COALESCE(r.package_name, ''))
      WHEN 'basic client' THEN 'Swipess.plus.monthly.v3'
      WHEN 'premium client' THEN 'Swipess.plus.semestral.v3'
      WHEN 'unlimited client' THEN 'Swipess.plus.annual.v3'
      ELSE NULL
    END;

    IF v_product_id IS NOT NULL THEN
      PERFORM public.service_grant_subscription_direct_requests(
        r.user_id,
        v_product_id,
        r.transaction_id,
        r.end_date
      );
    END IF;
  END LOOP;
END;
$$;
