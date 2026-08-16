-- Migration 1: Privilege Escalation Protection

-- 1. admin_users table
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- Drop the vulnerable permissive policies
DROP POLICY IF EXISTS "Admin users can insert admin_users" ON public.admin_users;
DROP POLICY IF EXISTS "Admin users can update own record" ON public.admin_users;

-- Create restrictive policies for modifications to ensure only existing admins can manage admins
CREATE POLICY "Only existing admins can insert admin_users"
  ON public.admin_users
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin_user(auth.uid()));

CREATE POLICY "Only existing admins can update admin_users"
  ON public.admin_users
  FOR UPDATE
  TO authenticated
  USING (public.is_admin_user(auth.uid()))
  WITH CHECK (public.is_admin_user(auth.uid()));

CREATE POLICY "Only existing admins can delete admin_users"
  ON public.admin_users
  FOR DELETE
  TO authenticated
  USING (public.is_admin_user(auth.uid()));

-- 2. user_roles table
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Prevent self-escalation to admin in user_roles. Normal users can manage client/owner.
CREATE POLICY "Prevent self-escalation to admin in user_roles" 
  ON public.user_roles 
  AS RESTRICTIVE
  FOR ALL
  TO authenticated
  USING (
    role != 'admin' OR 
    public.is_admin_user(auth.uid())
  )
  WITH CHECK (
    role != 'admin' OR 
    public.is_admin_user(auth.uid())
  );

-- 3. profiles table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Protect both INSERT and UPDATE using a restrictive policy.
-- The column is TEXT, so we block 'admin' and 'super_admin' explicitly unless authorized.
CREATE POLICY "Prevent self-escalation to admin in profiles"
  ON public.profiles
  AS RESTRICTIVE
  FOR ALL
  TO authenticated
  USING (
    role NOT IN ('admin', 'super_admin') OR 
    public.is_admin_user(auth.uid())
  )
  WITH CHECK (
    role NOT IN ('admin', 'super_admin') OR 
    public.is_admin_user(auth.uid())
  );
