-- ====================================================================
-- FIX TEACHER AUTH IDENTITY & ATTENDANCE RLS
-- ====================================================================
-- Description:
-- 1. Fixes `get_user_school_id()` and `get_user_role()` so they read
--    auth.jwt() / auth.users metadata when public.profiles is missing,
--    and automatically self-heal public.profiles.
-- 2. Populates missing profile records from auth.users.
-- 3. Sets up strict school-isolated RLS policies on public.attendance.
-- ====================================================================

-- 1. Hardened get_user_school_id()
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
DECLARE
    v_school_id UUID;
    v_auth_uid UUID;
    v_role TEXT;
    v_name TEXT;
BEGIN
    v_auth_uid := auth.uid();
    IF v_auth_uid IS NULL THEN
        RETURN NULL;
    END IF;

    -- Try public.profiles first
    SELECT school_id INTO v_school_id 
    FROM public.profiles 
    WHERE auth_user_id = v_auth_uid 
    LIMIT 1;

    IF v_school_id IS NOT NULL THEN
        RETURN v_school_id;
    END IF;

    -- Fallback to request JWT claims
    BEGIN
        v_school_id := (NULLIF(current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'school_id', ''))::UUID;
        v_role := current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'role';
        v_name := current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'full_name';
    EXCEPTION WHEN OTHERS THEN
        v_school_id := NULL;
    END;

    -- Fallback to auth.users table
    IF v_school_id IS NULL THEN
        SELECT 
            (raw_user_meta_data->>'school_id')::UUID,
            raw_user_meta_data->>'role',
            raw_user_meta_data->>'full_name'
        INTO v_school_id, v_role, v_name
        FROM auth.users
        WHERE id = v_auth_uid;
    END IF;

    -- Self-heal missing profile row
    IF v_school_id IS NOT NULL THEN
        INSERT INTO public.profiles (auth_user_id, school_id, full_name, role, status)
        VALUES (
            v_auth_uid,
            v_school_id,
            COALESCE(v_name, 'Teacher User'),
            COALESCE(v_role, 'teacher'),
            'active'
        )
        ON CONFLICT (auth_user_id) DO NOTHING;
    END IF;

    RETURN v_school_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 2. Hardened get_user_role()
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

    -- Try public.profiles first
    SELECT role INTO v_role 
    FROM public.profiles 
    WHERE auth_user_id = v_auth_uid 
    LIMIT 1;

    IF v_role IS NOT NULL THEN
        RETURN LOWER(v_role);
    END IF;

    -- Fallback to request JWT claims
    BEGIN
        v_role := current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'role';
    EXCEPTION WHEN OTHERS THEN
        v_role := NULL;
    END;

    -- Fallback to auth.users table
    IF v_role IS NULL THEN
        SELECT raw_user_meta_data->>'role' INTO v_role
        FROM auth.users
        WHERE id = v_auth_uid;
    END IF;

    RETURN LOWER(COALESCE(v_role, ''));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 3. Sync all existing auth users into public.profiles
INSERT INTO public.profiles (auth_user_id, school_id, full_name, role, status)
SELECT 
    u.id, 
    (u.raw_user_meta_data->>'school_id')::UUID, 
    COALESCE(u.raw_user_meta_data->>'full_name', 'Faculty Member'), 
    COALESCE(u.raw_user_meta_data->>'role', 'teacher'), 
    'active'
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.auth_user_id = u.id
)
AND u.raw_user_meta_data->>'school_id' IS NOT NULL;

-- 4. Clean up legacy attendance policies
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users view school attendance" ON public.attendance;
DROP POLICY IF EXISTS "Authenticated users insert school attendance" ON public.attendance;
DROP POLICY IF EXISTS "Authenticated users update school attendance" ON public.attendance;
DROP POLICY IF EXISTS "Teachers and admins insert attendance" ON public.attendance;
DROP POLICY IF EXISTS "Teachers and admins update attendance" ON public.attendance;
DROP POLICY IF EXISTS "Teachers and admins select attendance" ON public.attendance;

-- 5. SELECT Policy: Teachers and admins view school attendance
CREATE POLICY "Teachers and admins select attendance"
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

-- 6. INSERT Policy: Teachers and admins insert attendance
CREATE POLICY "Teachers and admins insert attendance"
ON public.attendance
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IS NOT NULL
    AND (
        school_id = public.get_user_school_id()
        OR EXISTS (
            SELECT 1 FROM public.students s 
            WHERE s.id = student_id 
            AND s.school_id = public.get_user_school_id()
        )
    )
);

-- 7. UPDATE Policy: Teachers and admins update attendance
CREATE POLICY "Teachers and admins update attendance"
ON public.attendance
FOR UPDATE
TO authenticated
USING (
    auth.uid() IS NOT NULL
    AND (
        school_id = public.get_user_school_id()
        OR EXISTS (
            SELECT 1 FROM public.students s 
            WHERE s.id = student_id 
            AND s.school_id = public.get_user_school_id()
        )
    )
)
WITH CHECK (
    auth.uid() IS NOT NULL
    AND (
        school_id = public.get_user_school_id()
        OR EXISTS (
            SELECT 1 FROM public.students s 
            WHERE s.id = student_id 
            AND s.school_id = public.get_user_school_id()
        )
    )
);

NOTIFY pgrst, 'reload schema';
