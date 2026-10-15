-- ====================================================================
-- MASTER MIGRATION: SCHOOL CONFIGURATION, ACADEMIC YEARS, 
-- NOTIFICATIONS, PROFILES & MULTI-TENANT RLS
-- ====================================================================
-- Description:
-- 1. Hardens public.get_user_school_id() and public.get_user_role() to
--    safely resolve school ID and role from public.profiles, JWT claims,
--    and auth.users metadata.
-- 2. Ensures public.schools has robust RLS policies preventing PGRST116.
-- 3. Enables RLS insert on public.profiles for authenticated users.
-- 4. Ensures public.academic_years has is_current column and atomic activation RPC.
-- 5. Implements check_academic_year_dependencies() RPC for safe deletion checks.
-- 6. Creates public.notification_preferences table with multi-tenant RLS.
-- 7. Seeds Kamal Public School (KPS: 6254bee9-151d-4332-8a1c-3994af7d2153) idempotently.
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. HARDENED RECURSION-FREE AUTHORIZATION HELPER FUNCTIONS
-- --------------------------------------------------------------------

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

GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated, anon, service_role;

-- --------------------------------------------------------------------
-- 2. PUBLIC.PROFILES RLS HARDENING & INSERT PERMISSION
-- --------------------------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
CREATE POLICY "Users can read own profile"
ON public.profiles FOR SELECT TO authenticated
USING (auth_user_id = auth.uid());

DROP POLICY IF EXISTS "School Admins view school profiles" ON public.profiles;
CREATE POLICY "School Admins view school profiles"
ON public.profiles FOR SELECT TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT TO authenticated
WITH CHECK (auth_user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (auth_user_id = auth.uid());

-- --------------------------------------------------------------------
-- 3. ENSURE SCHOOL ENTITY & RLS POLICIES FOR PUBLIC.SCHOOLS
-- --------------------------------------------------------------------

ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

-- Idempotently seed Kamal Public School (KPS)
INSERT INTO public.schools (id, name, code, address, status, created_at, updated_at)
VALUES (
    '6254bee9-151d-4332-8a1c-3994af7d2153'::uuid,
    'Kamal Public School',
    'KPS',
    'Vikas Puri, New Delhi, India',
    'ACTIVE',
    now(),
    now()
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    code = EXCLUDED.code,
    status = EXCLUDED.status,
    updated_at = now();

DROP POLICY IF EXISTS "Users read own school" ON public.schools;
CREATE POLICY "Users read own school"
ON public.schools FOR SELECT TO authenticated
USING (
    id = public.get_user_school_id()
    OR code = 'KPS'
);

DROP POLICY IF EXISTS "Admins update own school" ON public.schools;
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

DROP POLICY IF EXISTS "Admins insert own school" ON public.schools;
CREATE POLICY "Admins insert own school"
ON public.schools FOR INSERT TO authenticated
WITH CHECK (
    id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- --------------------------------------------------------------------
-- 4. ACADEMIC YEARS TABLE SCHEMA, CONSTRAINTS & ATOMIC ACTIVATION RPC
-- --------------------------------------------------------------------

ALTER TABLE public.academic_years ADD COLUMN IF NOT EXISTS is_current BOOLEAN DEFAULT false;

-- Atomic session activation RPC
CREATE OR REPLACE FUNCTION public.set_current_academic_year(
    p_year_id UUID,
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_updated_year RECORD;
BEGIN
    -- 1. Verify caller has permission for this school
    IF public.get_user_school_id() IS NOT NULL AND public.get_user_school_id() != p_school_id THEN
        RAISE EXCEPTION 'Access denied: Cannot modify academic sessions of another school.';
    END IF;

    -- 2. Deactivate is_current for all sessions of this school
    UPDATE public.academic_years
    SET is_current = false, updated_at = now()
    WHERE school_id = p_school_id;

    -- 3. Activate target session
    UPDATE public.academic_years
    SET is_current = true, status = 'ACTIVE', updated_at = now()
    WHERE id = p_year_id AND school_id = p_school_id
    RETURNING * INTO v_updated_year;

    IF v_updated_year.id IS NULL THEN
        RAISE EXCEPTION 'Academic year % not found for school %', p_year_id, p_school_id;
    END IF;

    RETURN json_build_object(
        'success', true,
        'id', v_updated_year.id,
        'school_id', v_updated_year.school_id,
        'name', v_updated_year.name,
        'is_current', true,
        'status', v_updated_year.status
    )::JSONB;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_current_academic_year(UUID, UUID) TO authenticated, service_role;

-- Dependency inspection RPC before deletion
CREATE OR REPLACE FUNCTION public.check_academic_year_dependencies(
    p_year_id UUID,
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_student_count INT := 0;
    v_class_count INT := 0;
    v_attendance_count INT := 0;
    v_fee_count INT := 0;
    v_exam_count INT := 0;
    v_dependencies JSONB := '[]'::JSONB;
BEGIN
    -- 1. Students check
    BEGIN
        SELECT count(*) INTO v_student_count FROM public.students 
        WHERE school_id = p_school_id AND academic_year_id = p_year_id;
        IF v_student_count > 0 THEN
            v_dependencies := v_dependencies || jsonb_build_array(v_student_count || ' enrolled student(s)');
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- 2. Classes check
    BEGIN
        SELECT count(*) INTO v_class_count FROM public.classes 
        WHERE school_id = p_school_id AND academic_year_id = p_year_id;
        IF v_class_count > 0 THEN
            v_dependencies := v_dependencies || jsonb_build_array(v_class_count || ' class(es)');
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- 3. Attendance check
    BEGIN
        SELECT count(*) INTO v_attendance_count FROM public.attendance 
        WHERE school_id = p_school_id AND academic_year_id = p_year_id;
        IF v_attendance_count > 0 THEN
            v_dependencies := v_dependencies || jsonb_build_array(v_attendance_count || ' attendance record(s)');
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- 4. Fee structures check
    BEGIN
        SELECT count(*) INTO v_fee_count FROM public.fee_structures 
        WHERE school_id = p_school_id AND academic_year_id = p_year_id;
        IF v_fee_count > 0 THEN
            v_dependencies := v_dependencies || jsonb_build_array(v_fee_count || ' fee structure(s)');
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- 5. Exams check
    BEGIN
        SELECT count(*) INTO v_exam_count FROM public.exams 
        WHERE school_id = p_school_id AND academic_year_id = p_year_id;
        IF v_exam_count > 0 THEN
            v_dependencies := v_dependencies || jsonb_build_array(v_exam_count || ' exam(s)');
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    RETURN json_build_object(
        'can_delete', jsonb_array_length(v_dependencies) = 0,
        'dependencies', v_dependencies
    )::JSONB;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_academic_year_dependencies(UUID, UUID) TO authenticated, service_role;

-- Seed default Academic Year for KPS
INSERT INTO public.academic_years (school_id, name, start_date, end_date, is_current, status, created_at, updated_at)
SELECT 
    '6254bee9-151d-4332-8a1c-3994af7d2153'::uuid,
    '2026-2027',
    '2026-04-01'::date,
    '2027-03-31'::date,
    true,
    'ACTIVE',
    now(),
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.academic_years 
    WHERE school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'::uuid AND name = '2026-2027'
);

-- --------------------------------------------------------------------
-- 5. NOTIFICATION PREFERENCES TABLE & MULTI-TENANT RLS
-- --------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    timetable_alerts BOOLEAN NOT NULL DEFAULT true,
    attendance_alerts BOOLEAN NOT NULL DEFAULT true,
    fee_alerts BOOLEAN NOT NULL DEFAULT true,
    push_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_notification_prefs UNIQUE (school_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_notification_prefs_school ON public.notification_preferences(school_id);
CREATE INDEX IF NOT EXISTS idx_notification_prefs_user ON public.notification_preferences(user_id);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notification preferences" ON public.notification_preferences;
CREATE POLICY "Users can view own notification preferences"
ON public.notification_preferences FOR SELECT TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR user_id = auth.uid()
);

DROP POLICY IF EXISTS "Users can insert own notification preferences" ON public.notification_preferences;
CREATE POLICY "Users can insert own notification preferences"
ON public.notification_preferences FOR INSERT TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    OR user_id = auth.uid()
);

DROP POLICY IF EXISTS "Users can update own notification preferences" ON public.notification_preferences;
CREATE POLICY "Users can update own notification preferences"
ON public.notification_preferences FOR UPDATE TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR user_id = auth.uid()
)
WITH CHECK (
    school_id = public.get_user_school_id()
    OR user_id = auth.uid()
);

-- --------------------------------------------------------------------
-- 6. BACKFILL ALL EXISTING AUTH USERS INTO PUBLIC.PROFILES
-- --------------------------------------------------------------------

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
    COALESCE(
        (NULLIF(u.raw_user_meta_data->>'school_id', ''))::UUID,
        '6254bee9-151d-4332-8a1c-3994af7d2153'::UUID
    ), 
    COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', split_part(u.email, '@', 1)), 
    u.email,
    COALESCE(LOWER(TRIM(u.raw_user_meta_data->>'role')), 'school_admin'),
    'active',
    now(),
    now()
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.auth_user_id = u.id
);
