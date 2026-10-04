-- ====================================================================
-- MASTER PRODUCTION SECURITY MIGRATION: ONBOARDING RPC & STRICT RLS
-- ====================================================================
-- Description:
-- 1. Uses existing `public.schools.code` column (aligned with live schema).
-- 2. Creates recursion-free authorization helper functions.
-- 3. Creates secure SECURITY DEFINER RPC `register_primary_school_admin`.
-- 4. Creates narrow public lookup RPC `lookup_school_by_code`.
-- 5. Enforces strict, non-recursive RLS policies on public.profiles and public.schools.
-- 6. Removes public USING (true) policies on public.schools to protect private data.
-- ====================================================================

-- SECTION A: AUTHORIZATION HELPER FUNCTIONS (RECURSION-FREE)
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
    SELECT school_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
    SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;


-- SECTION B: SECURE PRIMARY SCHOOL ADMIN ONBOARDING RPC
CREATE OR REPLACE FUNCTION public.register_primary_school_admin(
    p_school_name TEXT,
    p_address TEXT,
    p_admin_name TEXT,
    p_admin_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth_uid UUID;
    v_auth_email TEXT;
    v_school_id UUID;
    v_school_code TEXT;
    v_profile_id UUID;
    v_existing_profile RECORD;
    v_result JSONB;
BEGIN
    -- 1. Validate authenticated context
    v_auth_uid := auth.uid();
    IF v_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request. You must be signed in to onboard a school.';
    END IF;

    -- 2. Extract authenticated user's email from auth.users (Single source of truth)
    SELECT email INTO v_auth_email FROM auth.users WHERE id = v_auth_uid;
    IF v_auth_email IS NULL THEN
        v_auth_email := p_admin_email;
    END IF;

    -- 3. Idempotency Check: Return existing profile if already onboarded for this user
    SELECT * INTO v_existing_profile FROM public.profiles WHERE auth_user_id = v_auth_uid LIMIT 1;
    IF v_existing_profile.id IS NOT NULL THEN
        SELECT json_build_object(
            'profile_id', v_existing_profile.id,
            'auth_user_id', v_auth_uid,
            'school_id', v_existing_profile.school_id,
            'school_name', v_existing_profile.school_name,
            'role', v_existing_profile.role,
            'status', v_existing_profile.status,
            'is_existing', true
        )::JSONB INTO v_result;
        RETURN v_result;
    END IF;

    -- 4. Create new school entity using the existing `code` database column
    v_school_code := 'SCH-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));
    
    INSERT INTO public.schools (
        name,
        code, -- Aligned with live DB column name `code`
        address,
        status
    )
    VALUES (
        TRIM(p_school_name),
        v_school_code,
        TRIM(p_address),
        'ACTIVE'
    )
    RETURNING id INTO v_school_id;

    -- 5. Create primary school admin profile with SERVER-HARDCODED role & status
    INSERT INTO public.profiles (
        auth_user_id,
        school_id,
        school_name,
        name,
        email,
        role,
        status,
        designation
    )
    VALUES (
        v_auth_uid,
        v_school_id,
        TRIM(p_school_name),
        TRIM(p_admin_name),
        TRIM(LOWER(v_auth_email)),
        'school_admin', -- HARDCODED: Server-enforced primary admin role
        'active',       -- HARDCODED: Active status
        'Primary School Administrator'
    )
    RETURNING id INTO v_profile_id;

    -- 6. Construct JSON response (Returns `school_code` key for API compatibility)
    SELECT json_build_object(
        'profile_id', v_profile_id,
        'auth_user_id', v_auth_uid,
        'school_id', v_school_id,
        'school_name', p_school_name,
        'school_code', v_school_code,
        'role', 'school_admin',
        'status', 'active',
        'is_existing', false
    )::JSONB INTO v_result;

    RETURN v_result;
END;
$$;


-- SECTION C: NARROW PUBLIC LOOKUP RPC FOR SCHOOL CODE LOOKUP
CREATE OR REPLACE FUNCTION public.lookup_school_by_code(p_code TEXT)
RETURNS TABLE (
    id UUID,
    name TEXT,
    school_code TEXT,
    logo_url TEXT,
    status TEXT
)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT s.id, s.name, s.code AS school_code, s.logo_url, s.status
    FROM public.schools s
    WHERE UPPER(TRIM(s.code)) = UPPER(TRIM(p_code))
    LIMIT 1;
$$;


-- SECTION D: REQUIRED GRANT / REVOKE STATEMENTS
REVOKE ALL ON FUNCTION public.register_primary_school_admin(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_primary_school_admin(TEXT, TEXT, TEXT, TEXT) TO authenticated;

GRANT EXECUTE ON FUNCTION public.lookup_school_by_code(TEXT) TO authenticated, anon;


-- SECTION E: STRICT RLS POLICIES FOR PUBLIC.PROFILES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "School Admins view school profiles" ON public.profiles;

-- 1. SELECT: Users can read ONLY their own profile matching auth.uid()
CREATE POLICY "Users can read own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth_user_id = auth.uid());

-- 2. UPDATE: Users can update non-privileged fields on their own profile without recursion
CREATE POLICY "Users can update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (
    auth_user_id = auth.uid()
    AND role = public.get_user_role()
    AND school_id = public.get_user_school_id()
);

-- 3. SELECT: School Admins can view profiles in their school using helper functions
CREATE POLICY "School Admins view school profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);


-- SECTION F: STRICT RLS POLICIES FOR PUBLIC.SCHOOLS (PRIVATE DATA PROTECTED)
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read schools" ON public.schools;
DROP POLICY IF EXISTS "Public insert schools" ON public.schools;
DROP POLICY IF EXISTS "Public update schools" ON public.schools;
DROP POLICY IF EXISTS "Users read own school" ON public.schools;
DROP POLICY IF EXISTS "Admins update own school" ON public.schools;

-- 1. SELECT: Authenticated users can read ONLY their own school details
CREATE POLICY "Users read own school"
ON public.schools
FOR SELECT
TO authenticated
USING (id = public.get_user_school_id());

-- 2. UPDATE: School Admins can update ONLY their own school profile
CREATE POLICY "Admins update own school"
ON public.schools
FOR UPDATE
TO authenticated
USING (id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'))
WITH CHECK (id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
