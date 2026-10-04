-- ====================================================================
-- SECURE PARENT ATTENDANCE ACCESS (RPC + SCOPED RLS POLICY)
-- ====================================================================

-- 1. Ensure RLS remains ENABLED
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

-- 2. Scoped SELECT policy for parent app
DROP POLICY IF EXISTS "Parent view student attendance" ON public.attendance;
CREATE POLICY "Parent view student attendance"
ON public.attendance
FOR SELECT
TO anon, authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.students s 
        WHERE s.id = attendance.student_id
    )
);

-- 3. High-integrity SECURITY DEFINER RPC
CREATE OR REPLACE FUNCTION public.get_student_attendance_for_parent(
    p_student_id UUID,
    p_date DATE DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    student_id UUID,
    school_id UUID,
    academic_year_id UUID,
    attendance_date DATE,
    status TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.students s WHERE s.id = p_student_id) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        a.id,
        a.student_id,
        a.school_id,
        a.academic_year_id,
        a.attendance_date,
        a.status,
        a.created_at,
        a.updated_at
    FROM public.attendance a
    WHERE a.student_id = p_student_id
      AND (p_date IS NULL OR a.attendance_date = p_date)
      AND (p_start_date IS NULL OR a.attendance_date >= p_start_date)
      AND (p_end_date IS NULL OR a.attendance_date <= p_end_date)
    ORDER BY a.attendance_date ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_attendance_for_parent(UUID, DATE, DATE, DATE) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
