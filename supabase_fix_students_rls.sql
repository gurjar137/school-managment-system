-- ====================================================================
-- MASTER MIGRATION: STUDENTS TABLE RLS PERMISSION & AUTHORIZATION FIX
-- ====================================================================
-- Description:
-- 1. Updates `register_primary_school_admin` RPC to insert into `full_name`
--    (aligning with live `public.profiles` schema).
-- 2. Ensures non-recursive helper functions `get_user_school_id()` and `get_user_role()`.
-- 3. Configures non-recursive, school-isolated RLS policy for `public.students` INSERT.
-- ====================================================================

-- SECTION 1: FIX PRIMARY SCHOOL ADMIN ONBOARDING RPC
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
BEGIN
    v_auth_uid := auth.uid();
    IF v_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request. You must be signed in to onboard a school.';
    END IF;

    SELECT email INTO v_auth_email FROM auth.users WHERE id = v_auth_uid;
    IF v_auth_email IS NULL THEN
        v_auth_email := p_admin_email;
    END IF;

    SELECT * INTO v_existing_profile FROM public.profiles WHERE auth_user_id = v_auth_uid LIMIT 1;
    IF v_existing_profile.id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'school_id', v_existing_profile.school_id,
            'profile_id', v_existing_profile.id,
            'role', v_existing_profile.role,
            'message', 'Existing primary admin profile retrieved.'
        );
    END IF;

    v_school_code := 'SCH-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));

    INSERT INTO public.schools (
        name,
        code,
        address,
        status
    )
    VALUES (
        TRIM(p_school_name),
        v_school_code,
        p_address,
        'active'
    )
    RETURNING id INTO v_school_id;

    INSERT INTO public.profiles (
        auth_user_id,
        school_id,
        full_name,
        role,
        status
    )
    VALUES (
        v_auth_uid,
        v_school_id,
        TRIM(p_admin_name),
        'school_admin',
        'active'
    )
    RETURNING id INTO v_profile_id;

    RETURN jsonb_build_object(
        'success', true,
        'school_id', v_school_id,
        'school_code', v_school_code,
        'profile_id', v_profile_id,
        'role', 'school_admin'
    );
END;
$$;

-- SECTION 2: NON-RECURSIVE AUTHORIZATION HELPERS
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
    SELECT school_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
    SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

-- SECTION 3: STRICT STUDENTS RLS POLICIES
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School Admin can insert own school students" ON public.students;
DROP POLICY IF EXISTS "Admins can insert students" ON public.students;
DROP POLICY IF EXISTS "Enable insert for authenticated admins" ON public.students;

CREATE POLICY "School Admin can insert own school students"
ON public.students
FOR INSERT
TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

DROP POLICY IF EXISTS "School users can view own school students" ON public.students;
CREATE POLICY "School users can view own school students"
ON public.students
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
);

NOTIFY pgrst, 'reload schema';
