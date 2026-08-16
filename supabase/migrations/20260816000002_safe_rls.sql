-- Migration 2: Safe RLS

-- 1. saved_searches
ALTER TABLE public.saved_searches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own saved searches" ON public.saved_searches;
CREATE POLICY "Users can manage their own saved searches" 
  ON public.saved_searches 
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid()) 
  WITH CHECK (user_id = auth.uid());

-- 2. user_visual_preferences
ALTER TABLE public.user_visual_preferences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own preferences" ON public.user_visual_preferences;
CREATE POLICY "Users can manage their own preferences" 
  ON public.user_visual_preferences 
  FOR ALL 
  TO authenticated
  USING (user_id = auth.uid()) 
  WITH CHECK (user_id = auth.uid());

-- 3. platform_analytics
ALTER TABLE public.platform_analytics ENABLE ROW LEVEL SECURITY;
-- No client policy. Service_role inherently bypasses RLS,
-- so backend analytics logic can continue to write to this table.
