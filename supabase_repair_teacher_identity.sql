-- ====================================================================
-- MASTER MIGRATION: REPAIR TEACHER AUTH PROFILE & AUTOMATIC PROFILE SYNC
-- ====================================================================
-- Description:
-- 1. Immediately repairs current teacher profile for `c63c1cdd-3262-4e4c-be5c-094bb2691777`
-- 2. Hardens `get_user_school_id()` and `get_user_role()` to never return NULL for authenticated staff
-- 3. Implements automatic trigger on auth.users so EVERY newly created teacher atomically gets a profile
-- 4. Provides `create_staff_profile` SECURITY DEFINER RPC for admin staff creation
-- ====================================================================

-- 1. Repair CURRENT Teacher Ramesh in public.profiles
INSERT INTO public.profiles (
    auth_user_id,
    school_id,
    full_name,
    role,
    status
) VALUES (
    'c63c1cdd-3262-4e4c-be5c-094bb2691777'::UUID,
    '6254bee9-151d-4332-8a1c-3994af7d2153'::UUID,
    'ramesh',
    'teacher',
    'active'
)
ON CONFLICT (auth_user_id) 
DO UPDATE SET 
    school_id = EXCLUDED.school_id,
    role = EXCLUDED.role,
    status = 'active',
    updated_at = NOW();

-- 2. Backfill all existing auth.users who have school_id metadata
INSERT INTO public.profiles (
    auth_user_id,
    school_id,
    full_name,
    role,
    status
)
SELECT 
    u.id, 
    (u.raw_user_meta_data->>'school_id')::UUID, 
    COALESCE(u.raw_user_meta_data->>'full_name', 'Faculty Member'), 
    LOWER(COALESCE(u.raw_user_meta_data->>'role', 'teacher')), 
    'active'
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.auth_user_id = u.id
)
AND u.raw_user_meta_data->>'school_id' IS NOT NULL;

-- 3. Automatic Auth Trigger: Guarantees NEW teachers get profiles automatically
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
            role,
            status
        ) VALUES (
            NEW.id,
            (NEW.raw_user_meta_data->>'school_id')::UUID,
            COALESCE(NEW.raw_user_meta_data->>'full_name', 'Faculty Member'),
            LOWER(COALESCE(NEW.raw_user_meta_data->>'role', 'teacher')),
            'active'
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

-- 4. Hardened get_user_school_id()
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

    -- 1. Read from public.profiles
    SELECT school_id INTO v_school_id 
    FROM public.profiles 
    WHERE auth_user_id = v_auth_uid 
    LIMIT 1;

    IF v_school_id IS NOT NULL THEN
        RETURN v_school_id;
    END IF;

    -- 2. Fallback to request JWT user_metadata
    BEGIN
        v_school_id := (NULLIF(current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'school_id', ''))::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_school_id := NULL;
    END;

    -- 3. Fallback to auth.users raw_user_meta_data
    IF v_school_id IS NULL THEN
        SELECT (raw_user_meta_data->>'school_id')::UUID INTO v_school_id
        FROM auth.users
        WHERE id = v_auth_uid;
    END IF;

    -- 4. Self-heal profile
    IF v_school_id IS NOT NULL THEN
        INSERT INTO public.profiles (auth_user_id, school_id, full_name, role, status)
        VALUES (v_auth_uid, v_school_id, 'Faculty Member', 'teacher', 'active')
        ON CONFLICT (auth_user_id) DO NOTHING;
    END IF;

    RETURN v_school_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 5. Hardened get_user_role()
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

    -- 1. Read from public.profiles
    SELECT role INTO v_role 
    FROM public.profiles 
    WHERE auth_user_id = v_auth_uid 
    LIMIT 1;

    IF v_role IS NOT NULL THEN
        RETURN LOWER(v_role);
    END IF;

    -- 2. Fallback to request JWT user_metadata
    BEGIN
        v_role := current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'role';
    EXCEPTION WHEN OTHERS THEN
        v_role := NULL;
    END;

    -- 3. Fallback to auth.users
    IF v_role IS NULL THEN
        SELECT raw_user_meta_data->>'role' INTO v_role
        FROM auth.users
        WHERE id = v_auth_uid;
    END IF;

    RETURN LOWER(COALESCE(v_role, ''));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 6. RPC: create_staff_profile (SECURITY DEFINER for admin teacher creation)
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
BEGIN
    INSERT INTO public.profiles (
        auth_user_id,
        school_id,
        full_name,
        role,
        status
    ) VALUES (
        p_auth_user_id,
        p_school_id,
        p_full_name,
        LOWER(p_role),
        'active'
    )
    ON CONFLICT (auth_user_id)
    DO UPDATE SET
        school_id = EXCLUDED.school_id,
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        status = 'active',
        updated_at = NOW();

    RETURN jsonb_build_object('success', true, 'auth_user_id', p_auth_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.create_staff_profile(UUID, UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_staff_profile(UUID, UUID, TEXT, TEXT) TO authenticated;

-- 7. Policy ensuring school isolation on public.attendance
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendance_insert_own_school" ON public.attendance;
CREATE POLICY "attendance_insert_own_school"
ON public.attendance
FOR INSERT
TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND EXISTS (
        SELECT 1 FROM public.students s
        WHERE s.id = attendance.student_id
        AND s.school_id = public.get_user_school_id()
    )
);

DROP POLICY IF EXISTS "attendance_update_own_school" ON public.attendance;
CREATE POLICY "attendance_update_own_school"
ON public.attendance
FOR UPDATE
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND EXISTS (
        SELECT 1 FROM public.students s
        WHERE s.id = attendance.student_id
        AND s.school_id = public.get_user_school_id()
    )
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND EXISTS (
        SELECT 1 FROM public.students s
        WHERE s.id = attendance.student_id
        AND s.school_id = public.get_user_school_id()
    )
);

DROP POLICY IF EXISTS "attendance_select_own_school" ON public.attendance;
CREATE POLICY "attendance_select_own_school"
ON public.attendance
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR EXISTS (
        SELECT 1 FROM public.students s
        WHERE s.id = attendance.student_id
        AND s.school_id = public.get_user_school_id()
    )
);

NOTIFY pgrst, 'reload schema';
