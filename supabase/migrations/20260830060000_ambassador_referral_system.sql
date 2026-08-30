-- Ambassador / Affiliate System Engine

-- 1. Create table for ambassador codes
CREATE TABLE IF NOT EXISTS public.ambassador_codes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    code text NOT NULL UNIQUE,
    commission_rate double precision NOT NULL DEFAULT 0.20,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(user_id)
);

ALTER TABLE public.ambassador_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view active ambassador codes" 
  ON public.ambassador_codes FOR SELECT 
  USING (is_active = true);

CREATE POLICY "Admins can manage ambassador codes" 
  ON public.ambassador_codes FOR ALL 
  USING (public.is_admin_user(auth.uid()));

-- 2. Add tracking to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referred_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3. Ledger for financial tracking
CREATE TABLE IF NOT EXISTS public.ambassador_ledger (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    promoter_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    referred_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type text NOT NULL, -- 'signup', 'token_purchase', 'subscription'
    revenue_usd double precision NOT NULL DEFAULT 0.0,
    commission_usd double precision NOT NULL DEFAULT 0.0,
    status text NOT NULL DEFAULT 'pending', -- 'pending', 'paid', 'cancelled'
    notes text,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ambassador_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Promoters can view their own ledger"
  ON public.ambassador_ledger FOR SELECT
  USING (auth.uid() = promoter_user_id);

CREATE POLICY "Admins can manage ledger"
  ON public.ambassador_ledger FOR ALL
  USING (public.is_admin_user(auth.uid()));

-- 4. Dashboard Stats RPC (Real-time math)
CREATE OR REPLACE FUNCTION public.rpc_get_ambassador_stats(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_total_signups integer;
  v_total_revenue double precision;
  v_unpaid_commission double precision;
  v_paid_commission double precision;
BEGIN
  SELECT count(*) INTO v_total_signups
  FROM public.profiles
  WHERE referred_by_user_id = p_user_id;

  SELECT 
    COALESCE(SUM(revenue_usd), 0.0),
    COALESCE(SUM(CASE WHEN status = 'pending' THEN commission_usd ELSE 0.0 END), 0.0),
    COALESCE(SUM(CASE WHEN status = 'paid' THEN commission_usd ELSE 0.0 END), 0.0)
  INTO v_total_revenue, v_unpaid_commission, v_paid_commission
  FROM public.ambassador_ledger
  WHERE promoter_user_id = p_user_id;

  RETURN jsonb_build_object(
    'total_signups', v_total_signups,
    'total_revenue_usd', v_total_revenue,
    'unpaid_commission_usd', v_unpaid_commission,
    'paid_commission_usd', v_paid_commission
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_get_ambassador_stats(uuid) TO authenticated;
