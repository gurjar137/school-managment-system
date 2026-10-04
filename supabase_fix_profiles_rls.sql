-- ====================================================================
-- SECURE RLS MIGRATION SCRIPT FOR PUBLIC.PROFILES
-- ====================================================================
-- Description: Sets up production Row Level Security policies on public.profiles.
-- Enforces zero anonymous access, prevents user impersonation on INSERT/UPDATE,
-- and eliminates RLS subquery recursion using SECURITY DEFINER helper functions.
-- ====================================================================

-- SECTION 1: HELPER FUNCTIONS FOR RECURSION-FREE AUTHORIZATION
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
    SELECT school_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
    SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;


-- SECTION 2: RLS POLICY REPAIR ON PUBLIC.PROFILES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Clean up any legacy or insecure policies
DROP POLICY IF EXISTS "Public read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "School Admins view school profiles" ON public.profiles;

-- 1. SELECT: Authenticated users can read ONLY their own profile
CREATE POLICY "Users can read own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth_user_id = auth.uid());

-- 2. INSERT: Authenticated users can insert ONLY their own profile matching auth.uid()
-- Disallows anonymous insertions and prevents creating profiles for other auth users
CREATE POLICY "Users can insert own profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth_user_id = auth.uid());

-- 3. UPDATE: Authenticated users can update ONLY their own profile
CREATE POLICY "Users can update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (auth_user_id = auth.uid());

-- 4. SELECT: School Admins can view profiles in their own school without subquery recursion
CREATE POLICY "School Admins view school profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);
