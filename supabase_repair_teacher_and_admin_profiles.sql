-- ====================================================================
-- MASTER MIGRATION: REPAIR TEACHER & ADMIN AUTH PROFILES & RLS HARDENING
-- ====================================================================
-- Description:
-- 1. Hardens get_user_school_id() and get_user_role() to check public.profiles
--    and safely fall back to verified JWT user_metadata claims.
-- 2. Backfills all existing auth.users (including admin@school.com) into public.profiles.
-- 3. Implements handle_new_user() trigger on auth.users for atomic profile creation.
-- 4. Creates create_staff_profile() SECURITY DEFINER RPC.
-- 5. Hardens Row Level Security on public.profiles for multi-tenant isolation.
-- ====================================================================

-- 1. HARDENED get_user_school_id() WITH JWT CLAIM FALLBACK
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
DECLARE
    v_school_id UUID;
    v_auth_uid UUID;
BEGIN
    v_auth_uid := auth.uid();
    IF v_auth_uid IS NULL THEN
        RETURN NULL;
    END IF;

    -- Step 1: Read from public.profiles
    SELECT school_id INTO v_school_id 
    FROM public.profiles 
    WHERE auth_user_id = v_auth_uid 
    LIMIT 1;

    IF v_school_id IS NOT NULL THEN
        RETURN v_school_id;
    END IF;

    -- Step 2: Fallback to request JWT user_metadata claims
    BEGIN
        v_school_id := (NULLIF(current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'school_id', ''))::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_school_id := NULL;
    END;

    IF v_school_id IS NOT NULL THEN
        RETURN v_school_id;
    END IF;

    -- Step 3: Fallback to auth.users raw_user_meta_data
    BEGIN
        SELECT (raw_user_meta_data->>'school_id')::UUID INTO v_school_id
        FROM auth.users
        WHERE id = v_auth_uid;
    EXCEPTION WHEN OTHERS THEN
        v_school_id := NULL;
    END;

    RETURN v_school_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 2. HARDENED get_user_role() WITH JWT CLAIM FALLBACK
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
DECLARE
    v_role TEXT;
    v_auth_uid UUID;
BEGIN
    v_auth_uid := auth.uid();
    IF v_auth_uid IS NULL THEN
        RETURN NULL;
    END IF;

    -- Step 1: Read from public.profiles
    SELECT role INTO v_role 
    FROM public.profiles 
    WHERE auth_user_id = v_auth_uid 
    LIMIT 1;

    IF v_role IS NOT NULL THEN
        RETURN LOWER(TRIM(v_role));
    END IF;

    -- Step 2: Fallback to request JWT user_metadata claims
    BEGIN
        v_role := LOWER(TRIM(NULLIF(current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'role', '')));
    EXCEPTION WHEN OTHERS THEN
        v_role := NULL;
    END;

    IF v_role IS NOT NULL THEN
        RETURN v_role;
    END IF;

    -- Step 3: Fallback to auth.users raw_user_meta_data
    BEGIN
        SELECT LOWER(TRIM(raw_user_meta_data->>'role')) INTO v_role
        FROM auth.users
        WHERE id = v_auth_uid;
    EXCEPTION WHEN OTHERS THEN
        v_role := NULL;
    END;

    RETURN v_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 3. BACKFILL ALL EXISTING AUTH USERS WITH SCHOOL METADATA INTO PROFILES
INSERT INTO public.profiles (
    auth_user_id,
    school_id,
    full_name,
    email,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    u.id, 
    (u.raw_user_meta_data->>'school_id')::UUID, 
    COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', split_part(u.email, '@', 1)), 
    u.email,
    LOWER(COALESCE(u.raw_user_meta_data->>'role', 'teacher')), 
    'active',
    NOW(),
    NOW()
FROM auth.users u
WHERE u.raw_user_meta_data->>'school_id' IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.auth_user_id = u.id
  )
ON CONFLICT (auth_user_id) DO NOTHING;

-- 4. ENSURE KPS ADMIN (admin@school.com) PROFILE ROW EXISTS
INSERT INTO public.profiles (
    auth_user_id,
    school_id,
    full_name,
    email,
    role,
    status,
    designation,
    created_at,
    updated_at
)
SELECT
    u.id,
    '6254bee9-151d-4332-8a1c-3994af7d2153'::UUID,
    COALESCE(u.raw_user_meta_data->>'full_name', 'School Administrator'),
    u.email,
    'school_admin',
    'active',
    'School Administrator',
    NOW(),
    NOW()
FROM auth.users u
WHERE u.email = 'admin@school.com'
  AND NOT EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.auth_user_id = u.id
  )
ON CONFLICT (auth_user_id) DO NOTHING;

-- 5. ATOMIC AUTH TRIGGER ON NEW USER CREATION
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.raw_user_meta_data->>'school_id' IS NOT NULL THEN
        INSERT INTO public.profiles (
            auth_user_id,
            school_id,
            full_name,
            email,
            role,
            status,
            designation,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,
            (NEW.raw_user_meta_data->>'school_id')::UUID,
            COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
            NEW.email,
            LOWER(COALESCE(NEW.raw_user_meta_data->>'role', 'teacher')),
            'active',
            COALESCE(NEW.raw_user_meta_data->>'designation', 'Faculty Member'),
            NOW(),
            NOW()
        )
        ON CONFLICT (auth_user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. SECURE RPC TO CREATE STAFF PROFILES (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.create_staff_profile(
    p_auth_user_id UUID,
    p_school_id UUID,
    p_full_name TEXT,
    p_role TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role TEXT;
    v_caller_school UUID;
    v_new_profile_id UUID;
BEGIN
    v_caller_role := public.get_user_role();
    v_caller_school := public.get_user_school_id();

    IF v_caller_role NOT IN ('owner', 'super_admin', 'school_admin') THEN
        RAISE EXCEPTION 'Only administrators can create staff profiles.';
    END IF;

    IF v_caller_role = 'school_admin' AND v_caller_school != p_school_id THEN
        RAISE EXCEPTION 'Cannot create staff for another school.';
    END IF;

    INSERT INTO public.profiles (
        auth_user_id,
        school_id,
        full_name,
        role,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_auth_user_id,
        p_school_id,
        TRIM(p_full_name),
        LOWER(TRIM(p_role)),
        'active',
        NOW(),
        NOW()
    )
    ON CONFLICT (auth_user_id)
    DO UPDATE SET
        school_id = EXCLUDED.school_id,
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        updated_at = NOW()
    RETURNING id INTO v_new_profile_id;

    RETURN jsonb_build_object('success', true, 'profile_id', v_new_profile_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_staff_profile(UUID, UUID, TEXT, TEXT) TO authenticated, service_role;

-- 7. REPAIR ROW LEVEL SECURITY ON PUBLIC.PROFILES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "School Admins view school profiles" ON public.profiles;
DROP POLICY IF EXISTS "Staff view school profiles" ON public.profiles;

-- Authenticated users can read their own profile
CREATE POLICY "Users can read own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth_user_id = auth.uid());

-- Authenticated users can insert their own profile
CREATE POLICY "Users can insert own profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth_user_id = auth.uid());

-- Authenticated users can update their own profile
CREATE POLICY "Users can update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (auth_user_id = auth.uid());

-- School Admins can view all profiles in their own school
CREATE POLICY "School Admins view school profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- School Admins can insert staff profiles in their own school
DROP POLICY IF EXISTS "School Admins insert staff profiles" ON public.profiles;
CREATE POLICY "School Admins insert staff profiles"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- School Admins can update staff profiles in their own school
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

-- Staff and Teachers can view faculty in their own school
CREATE POLICY "Staff view school profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
);

-- 8. SEED TEST TEACHERS FOR KPS (School ID: 6254bee9-151d-4332-8a1c-3994af7d2153)
INSERT INTO public.profiles (
    id,
    school_id,
    full_name,
    role,
    status,
    assigned_class,
    assigned_section,
    designation,
    email,
    phone
) VALUES
('b0000001-0000-0000-0000-000000000001', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 1A', 'teacher', 'active', 'Class 1', 'A', 'Primary Educator', 'test.teacher.1a@school-test.local', '999990101A'),
('b0000001-0000-0000-0000-000000000002', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 1B', 'teacher', 'active', 'Class 1', 'B', 'Primary Educator', 'test.teacher.1b@school-test.local', '999990101B'),
('b0000001-0000-0000-0000-000000000003', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 2A', 'teacher', 'active', 'Class 2', 'A', 'Primary Educator', 'test.teacher.2a@school-test.local', '999990201A'),
('b0000001-0000-0000-0000-000000000004', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 2B', 'teacher', 'active', 'Class 2', 'B', 'Primary Educator', 'test.teacher.2b@school-test.local', '999990201B'),
('b0000001-0000-0000-0000-000000000005', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 3A', 'teacher', 'active', 'Class 3', 'A', 'Primary Educator', 'test.teacher.3a@school-test.local', '999990301A'),
('b0000001-0000-0000-0000-000000000006', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 3B', 'teacher', 'active', 'Class 3', 'B', 'Primary Educator', 'test.teacher.3b@school-test.local', '999990301B'),
('b0000001-0000-0000-0000-000000000007', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 4A', 'teacher', 'active', 'Class 4', 'A', 'Primary Educator', 'test.teacher.4a@school-test.local', '999990401A'),
('b0000001-0000-0000-0000-000000000008', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 4B', 'teacher', 'active', 'Class 4', 'B', 'Primary Educator', 'test.teacher.4b@school-test.local', '999990401B'),
('b0000001-0000-0000-0000-000000000009', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 5A', 'teacher', 'active', 'Class 5', 'A', 'Middle School Faculty', 'test.teacher.5a@school-test.local', '999990501A'),
('b0000001-0000-0000-0000-000000000010', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 5B', 'teacher', 'active', 'Class 5', 'B', 'Middle School Faculty', 'test.teacher.5b@school-test.local', '999990501B'),
('b0000001-0000-0000-0000-000000000011', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 6A', 'teacher', 'active', 'Class 6', 'A', 'Middle School Faculty', 'test.teacher.6a@school-test.local', '999990601A'),
('b0000001-0000-0000-0000-000000000012', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 6B', 'teacher', 'active', 'Class 6', 'B', 'Middle School Faculty', 'test.teacher.6b@school-test.local', '999990601B'),
('b0000001-0000-0000-0000-000000000013', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 7A', 'teacher', 'active', 'Class 7', 'A', 'Middle School Faculty', 'test.teacher.7a@school-test.local', '999990701A'),
('b0000001-0000-0000-0000-000000000014', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 7B', 'teacher', 'active', 'Class 7', 'B', 'Middle School Faculty', 'test.teacher.7b@school-test.local', '999990701B'),
('b0000001-0000-0000-0000-000000000015', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 8A', 'teacher', 'active', 'Class 8', 'A', 'Middle School Faculty', 'test.teacher.8a@school-test.local', '999990801A'),
('b0000001-0000-0000-0000-000000000016', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 8B', 'teacher', 'active', 'Class 8', 'B', 'Middle School Faculty', 'test.teacher.8b@school-test.local', '999990801B'),
('b0000001-0000-0000-0000-000000000017', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 9A', 'teacher', 'active', 'Class 9', 'A', 'Secondary Faculty', 'test.teacher.9a@school-test.local', '999990901A'),
('b0000001-0000-0000-0000-000000000018', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 9B', 'teacher', 'active', 'Class 9', 'B', 'Secondary Faculty', 'test.teacher.9b@school-test.local', '999990901B'),
('b0000001-0000-0000-0000-000000000019', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 10A', 'teacher', 'active', 'Class 10', 'A', 'Secondary Faculty', 'test.teacher.10a@school-test.local', '999991001A'),
('b0000001-0000-0000-0000-000000000020', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 10B', 'teacher', 'active', 'Class 10', 'B', 'Secondary Faculty', 'test.teacher.10b@school-test.local', '999991001B'),
('b0000001-0000-0000-0000-000000000021', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 11A', 'teacher', 'active', 'Class 11', 'A', 'Senior Secondary Faculty', 'test.teacher.11a@school-test.local', '999991101A'),
('b0000001-0000-0000-0000-000000000022', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 11B', 'teacher', 'active', 'Class 11', 'B', 'Senior Secondary Faculty', 'test.teacher.11b@school-test.local', '999991101B'),
('b0000001-0000-0000-0000-000000000023', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 12A', 'teacher', 'active', 'Class 12', 'A', 'Senior Secondary Faculty', 'test.teacher.12a@school-test.local', '999991201A'),
('b0000001-0000-0000-0000-000000000024', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 12B', 'teacher', 'active', 'Class 12', 'B', 'Senior Secondary Faculty', 'test.teacher.12b@school-test.local', '999991201B')
ON CONFLICT (id) DO UPDATE SET
    assigned_class = EXCLUDED.assigned_class,
    assigned_section = EXCLUDED.assigned_section,
    role = EXCLUDED.role,
    status = EXCLUDED.status,
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email;

-- 9. SECURE RPC TO UPDATE TEACHER ASSIGNMENT
CREATE OR REPLACE FUNCTION public.update_teacher_assignment(
    p_teacher_id UUID,
    p_class TEXT,
    p_section TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_school_id UUID;
    v_caller_role TEXT;
    v_updated_id UUID;
BEGIN
    v_caller_role := public.get_user_role();
    v_school_id := public.get_user_school_id();

    IF v_caller_role NOT IN ('owner', 'super_admin', 'school_admin') THEN
        RAISE EXCEPTION 'Only school administrators can update teacher class assignments.';
    END IF;

    UPDATE public.profiles
    SET
        assigned_class = NULLIF(TRIM(p_class), ''),
        assigned_section = NULLIF(TRIM(p_section), ''),
        updated_at = NOW()
    WHERE (id = p_teacher_id OR auth_user_id = p_teacher_id)
      AND school_id = v_school_id
    RETURNING id INTO v_updated_id;

    IF v_updated_id IS NULL THEN
        RAISE EXCEPTION 'Teacher record not found in your school.';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'profile_id', v_updated_id,
        'assigned_class', NULLIF(TRIM(p_class), ''),
        'assigned_section', NULLIF(TRIM(p_section), '')
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_teacher_assignment(UUID, TEXT, TEXT) TO authenticated, service_role;

-- 10. REPAIR REGISTER_PRIMARY_SCHOOL_ADMIN RPC (FIX COLUMN "school_name" BUG)
CREATE OR REPLACE FUNCTION public.register_primary_school_admin(
    p_school_name TEXT,
    p_address TEXT,
    p_admin_name TEXT,
    p_admin_email TEXT,
    p_school_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
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
            'message', 'Existing administrator profile retrieved.'
        );
    END IF;

    -- Check if a school with this code or name already exists
    IF p_school_code IS NOT NULL AND p_school_code <> '' THEN
        SELECT id INTO v_school_id FROM public.schools WHERE UPPER(code) = UPPER(TRIM(p_school_code)) LIMIT 1;
    END IF;

    IF v_school_id IS NULL THEN
        SELECT id INTO v_school_id FROM public.schools WHERE LOWER(name) = LOWER(TRIM(p_school_name)) LIMIT 1;
    END IF;

    IF v_school_id IS NULL THEN
        v_school_code := COALESCE(NULLIF(TRIM(p_school_code), ''), 'SCH-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6)));
        INSERT INTO public.schools (
            name,
            code,
            address,
            status,
            created_at,
            updated_at
        ) VALUES (
            TRIM(p_school_name),
            v_school_code,
            TRIM(p_address),
            'ACTIVE',
            NOW(),
            NOW()
        ) RETURNING id INTO v_school_id;
    END IF;

    INSERT INTO public.profiles (
        auth_user_id,
        school_id,
        full_name,
        email,
        role,
        status,
        designation,
        created_at,
        updated_at
    ) VALUES (
        v_auth_uid,
        v_school_id,
        TRIM(p_admin_name),
        TRIM(LOWER(v_auth_email)),
        'school_admin',
        'active',
        'School Administrator',
        NOW(),
        NOW()
    )
    ON CONFLICT (auth_user_id) DO UPDATE SET
        school_id = EXCLUDED.school_id,
        role = 'school_admin',
        updated_at = NOW()
    RETURNING id INTO v_profile_id;

    RETURN jsonb_build_object(
        'success', true,
        'school_id', v_school_id,
        'profile_id', v_profile_id,
        'role', 'school_admin'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_primary_school_admin(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
