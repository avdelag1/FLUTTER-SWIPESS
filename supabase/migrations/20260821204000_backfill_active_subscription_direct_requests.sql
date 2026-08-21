-- Give currently active paid marketplace subscribers the same finite Direct
-- Request allowance new purchases receive. Idempotent by transaction note.
INSERT INTO public.tokens(
  user_id,token_type,amount,source,
  remaining_activations,total_activations,used_activations,
  activation_type,notes,expires_at
)
SELECT
  us.user_id,
  'messages',
  CASE sp.name
    WHEN 'Basic Client' THEN 15
    WHEN 'Premium Client' THEN 25
    WHEN 'Unlimited Client' THEN 50
  END,
  'subscription_direct_requests',
  CASE sp.name
    WHEN 'Basic Client' THEN 15
    WHEN 'Premium Client' THEN 25
    WHEN 'Unlimited Client' THEN 50
  END,
  CASE sp.name
    WHEN 'Basic Client' THEN 15
    WHEN 'Premium Client' THEN 25
    WHEN 'Unlimited Client' THEN 50
  END,
  0,
  'subscription',
  'subscription_direct_requests:' || COALESCE(us.transaction_id, us.id::text),
  us.end_date
FROM public.user_subscriptions us
JOIN public.subscription_packages sp ON sp.id=us.package_id
WHERE us.is_active=true
  AND us.payment_status='paid'
  AND sp.name IN ('Basic Client','Premium Client','Unlimited Client')
  AND (us.end_date IS NULL OR us.end_date>now())
  AND NOT EXISTS (
    SELECT 1 FROM public.tokens t
    WHERE t.user_id=us.user_id
      AND t.source='subscription_direct_requests'
      AND t.notes='subscription_direct_requests:' ||
        COALESCE(us.transaction_id, us.id::text)
  );
