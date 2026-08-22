-- Premium Direct Request allowances aligned with the customer-facing plans.
CREATE OR REPLACE FUNCTION public.grant_subscription_direct_requests()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_name text;
  v_amount integer := 0;
  v_note text;
BEGIN
  IF COALESCE(NEW.is_active,false) IS NOT TRUE
     OR COALESCE(NEW.payment_status,'') <> 'paid' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.transaction_id IS NOT DISTINCT FROM NEW.transaction_id
     AND COALESCE(OLD.is_active,false) = COALESCE(NEW.is_active,false)
     AND COALESCE(OLD.payment_status,'') = COALESCE(NEW.payment_status,'') THEN
    RETURN NEW;
  END IF;

  SELECT sp.name INTO v_name
  FROM public.subscription_packages sp
  WHERE sp.id = NEW.package_id;

  v_amount := CASE v_name
    WHEN 'Basic Client' THEN 20
    WHEN 'Premium Client' THEN 50
    WHEN 'Unlimited Client' THEN 150
    ELSE 0
  END;

  IF v_amount <= 0 THEN RETURN NEW; END IF;

  v_note := 'subscription_direct_requests:' ||
    COALESCE(NEW.transaction_id, NEW.id::text);

  IF EXISTS (
    SELECT 1 FROM public.tokens t
    WHERE t.user_id = NEW.user_id
      AND t.source = 'subscription_direct_requests'
      AND t.notes = v_note
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.tokens(
    user_id, token_type, amount, source,
    remaining_activations, total_activations, used_activations,
    activation_type, notes, expires_at
  ) VALUES (
    NEW.user_id, 'messages', v_amount, 'subscription_direct_requests',
    v_amount, v_amount, 0,
    'subscription', v_note, NEW.end_date
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.grant_subscription_direct_requests() FROM PUBLIC, anon, authenticated;
