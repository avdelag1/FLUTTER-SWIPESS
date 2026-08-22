-- Fix events table
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view published events" ON events FOR SELECT USING (is_published = true);

-- Fix digital_contracts table
ALTER TABLE digital_contracts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own contracts" ON digital_contracts FOR ALL USING (auth.uid() = owner_id OR auth.uid() = client_id);

-- Fix user_roles table (which was causing the 42501 permission error)
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own roles" ON user_roles FOR SELECT USING (auth.uid() = user_id);
