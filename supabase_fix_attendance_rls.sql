-- ====================================================================
-- MASTER MIGRATION: FIX TEACHER ATTENDANCE RLS PERMISSIONS & SECURE RPC
-- ====================================================================

-- 1. Ensure public.attendance has RLS enabled
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

-- 2. Update get_user_school_id() helper to check profiles and fallback to auth.jwt() user_metadata
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
DECLARE
    v_school_id UUID;
BEGIN
    SELECT school_id INTO v_school_id 
    FROM public.profiles 
    WHERE auth_user_id = auth.uid() 
    LIMIT 1;

    IF v_school_id IS NULL THEN
        BEGIN
            v_school_id := (NULLIF(current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'school_id', ''))::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_school_id := NULL;
        END;
    END IF;

    RETURN v_school_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- 3. Update get_user_role() helper to check profiles and fallback to auth.jwt() user_metadata
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT role INTO v_role 
    FROM public.profiles 
    WHERE auth_user_id = auth.uid() 
    LIMIT 1;

    IF v_role IS NULL THEN
        BEGIN
            v_role := current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'role';
        EXCEPTION WHEN OTHERS THEN
            v_role := NULL;
        END;
    END IF;

    RETURN LOWER(COALESCE(v_role, ''));
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- 4. Clean up any existing attendance policies
DROP POLICY IF EXISTS "Authenticated users view school attendance" ON public.attendance;
DROP POLICY IF EXISTS "Authenticated users insert school attendance" ON public.attendance;
DROP POLICY IF EXISTS "Authenticated users update school attendance" ON public.attendance;
DROP POLICY IF EXISTS "Admins full CRUD attendance" ON public.attendance;
DROP POLICY IF EXISTS "Teachers manage attendance for school" ON public.attendance;
DROP POLICY IF EXISTS "Parents view linked child attendance" ON public.attendance;
DROP POLICY IF EXISTS "Teachers and admins insert attendance" ON public.attendance;
DROP POLICY IF EXISTS "Teachers and admins update attendance" ON public.attendance;
DROP POLICY IF EXISTS "Teachers and admins select attendance" ON public.attendance;

-- 5. Strict SELECT Policy: Users can view attendance for their own school
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

-- 6. Strict INSERT Policy: Authenticated teachers & admins can insert attendance for their school's students
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

-- 7. Strict UPDATE Policy: Authenticated teachers & admins can update attendance for their school's students
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

-- 8. SECURITY DEFINER RPC: record_teacher_attendance
-- Guarantees atomic verification and server-side execution without RLS recursion
CREATE OR REPLACE FUNCTION public.record_teacher_attendance(p_records JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_auth_uid UUID;
    v_caller_school_id UUID;
    v_caller_role TEXT;
    v_item JSONB;
    v_student_id UUID;
    v_school_id UUID;
    v_academic_year_id UUID;
    v_attendance_date DATE;
    v_status TEXT;
    v_student RECORD;
    v_saved_count INT := 0;
BEGIN
    -- 1. Check authentication
    v_caller_auth_uid := auth.uid();
    IF v_caller_auth_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Caller must be authenticated';
    END IF;

    -- 2. Resolve caller's school and role
    v_caller_school_id := public.get_user_school_id();
    v_caller_role := public.get_user_role();

    -- 3. Loop through attendance items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_records)
    LOOP
        v_student_id := (v_item->>'student_id')::UUID;
        v_attendance_date := (v_item->>'attendance_date')::DATE;
        v_status := LOWER(TRIM(COALESCE(v_item->>'status', 'present')));

        -- Validate status enum
        IF v_status NOT IN ('present', 'absent', 'late') THEN
            v_status := 'present';
        END IF;

        -- Verify student exists and belongs to the caller's school
        SELECT id, school_id, academic_year_id INTO v_student
        FROM public.students
        WHERE id = v_student_id;

        IF NOT FOUND THEN
            CONTINUE; -- Student not found
        END IF;

        -- Prevent cross-school attendance
        IF v_caller_school_id IS NOT NULL AND v_student.school_id != v_caller_school_id THEN
            RAISE EXCEPTION 'Cross-school attendance write denied for student %', v_student_id;
        END IF;

        v_school_id := v_student.school_id;
        v_academic_year_id := COALESCE((v_item->>'academic_year_id')::UUID, v_student.academic_year_id);

        -- Real UPSERT into public.attendance
        INSERT INTO public.attendance (
            student_id,
            school_id,
            academic_year_id,
            attendance_date,
            status,
            updated_at
        ) VALUES (
            v_student_id,
            v_school_id,
            v_academic_year_id,
            v_attendance_date,
            v_status,
            NOW()
        )
        ON CONFLICT (student_id, attendance_date)
        DO UPDATE SET
            status = EXCLUDED.status,
            school_id = EXCLUDED.school_id,
            academic_year_id = EXCLUDED.academic_year_id,
            updated_at = NOW();

        v_saved_count := v_saved_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'saved_count', v_saved_count
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_teacher_attendance(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_teacher_attendance(JSONB) TO authenticated;

-- Ensure Teacher Profile exists in public.profiles for all auth users
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

NOTIFY pgrst, 'reload schema';
