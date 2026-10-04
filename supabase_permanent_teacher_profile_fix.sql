-- ====================================================================
-- PERMANENT FIX: AUTOMATIC & GUARANTEED TEACHER/STAFF PROFILE CREATION
-- ====================================================================

-- 1. SECURE RPC TO CREATE / LINK STAFF PROFILE (SECURITY DEFINER)
-- Allows school admins to guarantee profile creation without RLS friction
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
    -- Authorization check: caller must be an admin of the school, or matching the auth user
    v_caller_role := public.get_user_role();
    v_caller_school_id := public.get_user_school_id();

    IF auth.uid() IS NOT NULL AND auth.uid() <> p_auth_user_id THEN
        IF v_caller_role NOT IN ('owner', 'super_admin', 'school_admin') OR v_caller_school_id <> p_school_id THEN
            RAISE EXCEPTION 'Access denied: caller cannot create profiles for this school.';
        END IF;
    END IF;

    -- Idempotent upsert on auth_user_id
    INSERT INTO public.profiles (
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
        'auth_user_id', p_auth_user_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_staff_profile(UUID, UUID, TEXT, TEXT) TO authenticated, service_role;

-- 2. AUTOMATIC POSTGRESQL TRIGGER ON AUTH.USERS
-- Whenever any user is created in auth.users with school metadata, automatically ensure profile exists
CREATE OR REPLACE FUNCTION public.handle_new_staff_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_school_id UUID;
    v_role TEXT;
    v_name TEXT;
BEGIN
    -- Extract metadata if available
    IF NEW.raw_user_meta_data IS NOT NULL THEN
        IF NEW.raw_user_meta_data->>'school_id' IS NOT NULL THEN
            BEGIN
                v_school_id := (NEW.raw_user_meta_data->>'school_id')::uuid;
            EXCEPTION WHEN OTHERS THEN
                v_school_id := NULL;
            END;
        END IF;

        v_role := LOWER(COALESCE(NEW.raw_user_meta_data->>'role', 'teacher'));
        v_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1));

        IF v_school_id IS NOT NULL THEN
            INSERT INTO public.profiles (
                auth_user_id,
                school_id,
                full_name,
                role,
                status,
                created_at,
                updated_at
            )
            VALUES (
                NEW.id,
                v_school_id,
                TRIM(v_name),
                v_role,
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
                updated_at = NOW();
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_create_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_create_profile
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_staff_user();

-- 3. PERMIT SCHOOL ADMINS TO DIRECTLY INSERT/UPDATE PROFILES FOR THEIR SCHOOL
DROP POLICY IF EXISTS "School Admins insert staff profiles" ON public.profiles;
CREATE POLICY "School Admins insert staff profiles"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

DROP POLICY IF EXISTS "School Admins update staff profiles" ON public.profiles;
CREATE POLICY "School Admins update staff profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- 4. IMMEDIATE BACKFILL: Repair any existing teachers currently missing from public.profiles
INSERT INTO public.profiles (
    auth_user_id,
    school_id,
    full_name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    u.id AS auth_user_id,
    (u.raw_user_meta_data->>'school_id')::uuid AS school_id,
    COALESCE(u.raw_user_meta_data->>'full_name', 'Teacher') AS full_name,
    LOWER(COALESCE(u.raw_user_meta_data->>'role', 'teacher')) AS role,
    'active' AS status,
    NOW(),
    NOW()
FROM auth.users u
WHERE u.raw_user_meta_data->>'school_id' IS NOT NULL
ON CONFLICT (auth_user_id) DO UPDATE
SET 
    school_id = EXCLUDED.school_id,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    status = 'active',
    updated_at = NOW();

NOTIFY pgrst, 'reload schema';
