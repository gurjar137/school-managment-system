-- ====================================================================
-- MASTER MIGRATION: TEACHER AUTH, PROFILES, SCHOOL ACCESS & TIMETABLE
-- ====================================================================
-- Idempotent SQL script to repair:
-- 1. get_user_school_id() and get_user_role() with JWT user_metadata fallback
-- 2. public.profiles RLS policies for self-heal insert and admin staff provisioning
-- 3. public.schools RLS policies allowing authenticated users to read their own school
-- 4. public.create_staff_profile SECURITY DEFINER RPC
-- 5. public.lookup_school_by_id SECURITY DEFINER RPC
-- 6. Canonical Kamal Public School (KPS) school record verification
-- ====================================================================

-- -------------------------------------------------------------
-- 1. AUTHORIZATION HELPER FUNCTIONS (WITH JWT METADATA FALLBACK)
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
DECLARE
    v_school_id UUID;
BEGIN
    -- 1. Check authoritative public.profiles row
    SELECT school_id INTO v_school_id 
    FROM public.profiles 
    WHERE auth_user_id = auth.uid() 
    LIMIT 1;

    IF v_school_id IS NOT NULL THEN
        RETURN v_school_id;
    END IF;

    -- 2. Fallback to verified Supabase Auth JWT user_metadata
    BEGIN
        v_school_id := (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid;
    EXCEPTION WHEN OTHERS THEN
        v_school_id := NULL;
    END;

    RETURN v_school_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
DECLARE
    v_role TEXT;
BEGIN
    -- 1. Check authoritative public.profiles row
    SELECT role INTO v_role 
    FROM public.profiles 
    WHERE auth_user_id = auth.uid() 
    LIMIT 1;

    IF v_role IS NOT NULL THEN
        RETURN LOWER(TRIM(v_role));
    END IF;

    -- 2. Fallback to verified Supabase Auth JWT user_metadata
    BEGIN
        v_role := auth.jwt() -> 'user_metadata' ->> 'role';
    EXCEPTION WHEN OTHERS THEN
        v_role := NULL;
    END;

    RETURN LOWER(TRIM(COALESCE(v_role, '')));
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Grant execution to authenticated & service_role
GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated, service_role, anon;


-- -------------------------------------------------------------
-- 2. PUBLIC.PROFILES RLS POLICIES (SELF-HEAL & ADMIN PROVISION)
-- -------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can insert staff profiles" ON public.profiles;
DROP POLICY IF EXISTS "School Admins view school profiles" ON public.profiles;

-- SELECT: Users read own profile
CREATE POLICY "Users can read own profile"
ON public.profiles FOR SELECT TO authenticated
USING (auth_user_id = auth.uid() OR id = auth.uid());

-- SELECT: Admins view all profiles belonging to their school
CREATE POLICY "School Admins view school profiles"
ON public.profiles FOR SELECT TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- INSERT: Authenticated users can insert/self-heal their own profile
CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT TO authenticated
WITH CHECK (
    auth_user_id = auth.uid()
    OR id = auth.uid()
);

-- INSERT: School admins can insert profiles for staff in their school
CREATE POLICY "Admins can insert staff profiles"
ON public.profiles FOR INSERT TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- UPDATE: Users can update their own profile
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE TO authenticated
USING (auth_user_id = auth.uid() OR id = auth.uid())
WITH CHECK (auth_user_id = auth.uid() OR id = auth.uid());


-- -------------------------------------------------------------
-- 3. PUBLIC.SCHOOLS RLS POLICIES
-- -------------------------------------------------------------
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read schools" ON public.schools;
DROP POLICY IF EXISTS "Public insert schools" ON public.schools;
DROP POLICY IF EXISTS "Public update schools" ON public.schools;
DROP POLICY IF EXISTS "Users read own school" ON public.schools;
DROP POLICY IF EXISTS "Admins update own school" ON public.schools;

-- SELECT: Authenticated users can read their verified school
CREATE POLICY "Users read own school"
ON public.schools FOR SELECT TO authenticated
USING (
    id = public.get_user_school_id()
    OR id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
    OR code = 'KPS'
);

-- UPDATE: School admins can update their school
CREATE POLICY "Admins update own school"
ON public.schools FOR UPDATE TO authenticated
USING (
    id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);


-- -------------------------------------------------------------
-- 4. SECURITY DEFINER RPC: CREATE / PROVISION STAFF PROFILE
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_staff_profile(
    p_auth_user_id UUID,
    p_school_id UUID,
    p_full_name TEXT,
    p_role TEXT DEFAULT 'teacher'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile_id UUID;
    v_caller_role TEXT;
    v_caller_school_id UUID;
BEGIN
    v_caller_role := public.get_user_role();
    v_caller_school_id := public.get_user_school_id();

    -- Check caller authorization if called by another user
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_auth_user_id THEN
        IF v_caller_role NOT IN ('owner', 'super_admin', 'school_admin') OR v_caller_school_id <> p_school_id THEN
            RAISE EXCEPTION 'Access denied: caller cannot create profiles for this school.';
        END IF;
    END IF;

    -- Upsert profile record
    INSERT INTO public.profiles (
        id,
        auth_user_id,
        school_id,
        full_name,
        role,
        status,
        created_at,
        updated_at
    )
    VALUES (
        p_auth_user_id,
        p_auth_user_id,
        p_school_id,
        TRIM(p_full_name),
        LOWER(TRIM(p_role)),
        'active',
        NOW(),
        NOW()
    )
    ON CONFLICT (auth_user_id) DO UPDATE
    SET 
        school_id = EXCLUDED.school_id,
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        status = 'active',
        updated_at = NOW()
    RETURNING id INTO v_profile_id;

    RETURN jsonb_build_object(
        'success', true,
        'profile_id', v_profile_id,
        'auth_user_id', p_auth_user_id,
        'school_id', p_school_id,
        'role', p_role
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_staff_profile(UUID, UUID, TEXT, TEXT) TO authenticated, service_role;


-- -------------------------------------------------------------
-- 5. SECURITY DEFINER RPC: LOOKUP SCHOOL BY ID (SAFE RESOLUTION)
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lookup_school_by_id(p_school_id UUID)
RETURNS TABLE (
    id UUID,
    name TEXT,
    code TEXT,
    status TEXT,
    address TEXT,
    phone TEXT,
    email TEXT,
    logo_url TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        s.id, 
        s.name, 
        s.code, 
        s.status, 
        s.address, 
        s.phone, 
        s.email, 
        s.logo_url
    FROM public.schools s
    WHERE s.id = p_school_id
      AND (
          s.id = public.get_user_school_id()
          OR s.id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
          OR s.code = 'KPS'
      )
    LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_school_by_id(UUID) TO authenticated, service_role, anon;


-- -------------------------------------------------------------
-- 6. CANONICAL SCHOOL RECORD VERIFICATION (KPS)
-- -------------------------------------------------------------
INSERT INTO public.schools (
    id,
    name,
    code,
    status,
    address,
    phone,
    email,
    created_at,
    updated_at
)
VALUES (
    '6254bee9-151d-4332-8a1c-3994af7d2153',
    'Kamal Public School',
    'KPS',
    'active',
    'Main Campus, Knowledge Park',
    '+91 98765 43210',
    'info@kps.edu',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE
SET 
    status = 'active',
    updated_at = NOW();
