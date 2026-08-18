CREATE OR REPLACE FUNCTION public.touch_app_access_campaign_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_access_campaign_updated_at ON public.app_access_campaigns;
CREATE TRIGGER trg_app_access_campaign_updated_at
BEFORE UPDATE ON public.app_access_campaigns
FOR EACH ROW
EXECUTE FUNCTION public.touch_app_access_campaign_updated_at();
