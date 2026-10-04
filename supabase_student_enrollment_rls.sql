-- ====================================================================
-- MIGRATION: STUDENT ENROLLMENT & ACADEMIC YEAR LINKING RLS POLICIES
-- ====================================================================
-- Multi-Tenant Security Rules:
-- 1. Every student record must belong strictly to a valid school_id.
-- 2. Users may ONLY read, insert, update, or delete students for their
--    authenticated school_id (via get_user_school_id() / public.profiles).
-- 3. Admission numbers must be strictly unique WITHIN the school, while
--    allowing identical admission numbers across different schools.
-- ====================================================================

-- 1. Enable Row Level Security
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- 2. RLS Policy: SELECT (School-Scoped Isolation)
DROP POLICY IF EXISTS "students_select_school_isolated" ON public.students;
CREATE POLICY "students_select_school_isolated"
ON public.students
FOR SELECT
TO authenticated
USING (
    school_id = (
        SELECT school_id FROM public.profiles 
        WHERE auth_user_id = auth.uid() 
        LIMIT 1
    )
);

-- 3. RLS Policy: INSERT (School-Scoped Mutation)
DROP POLICY IF EXISTS "students_insert_school_isolated" ON public.students;
CREATE POLICY "students_insert_school_isolated"
ON public.students
FOR INSERT
TO authenticated
WITH CHECK (
    school_id = (
        SELECT school_id FROM public.profiles 
        WHERE auth_user_id = auth.uid() 
        LIMIT 1
    )
);

-- 4. RLS Policy: UPDATE (School-Scoped Mutation)
DROP POLICY IF EXISTS "students_update_school_isolated" ON public.students;
CREATE POLICY "students_update_school_isolated"
ON public.students
FOR UPDATE
TO authenticated
USING (
    school_id = (
        SELECT school_id FROM public.profiles 
        WHERE auth_user_id = auth.uid() 
        LIMIT 1
    )
)
WITH CHECK (
    school_id = (
        SELECT school_id FROM public.profiles 
        WHERE auth_user_id = auth.uid() 
        LIMIT 1
    )
);

-- 5. RLS Policy: DELETE (School-Scoped Deletion)
DROP POLICY IF EXISTS "students_delete_school_isolated" ON public.students;
CREATE POLICY "students_delete_school_isolated"
ON public.students
FOR DELETE
TO authenticated
USING (
    school_id = (
        SELECT school_id FROM public.profiles 
        WHERE auth_user_id = auth.uid() 
        LIMIT 1
    )
);

-- ====================================================================
-- PERFORMANCE INDEXES & INTEGRITY CONSTRAINTS
-- ====================================================================

-- 6. Strict School-Scoped Unique Admission Number
CREATE UNIQUE INDEX IF NOT EXISTS idx_students_school_admission_unique
ON public.students (school_id, LOWER(admission_number));

-- 7. High-Performance Lookups for Active Academic Year & Billing
CREATE INDEX IF NOT EXISTS idx_students_school_academic_year
ON public.students (school_id, academic_year_id, status);

-- 8. High-Performance Lookups for Class & Section Roster
CREATE INDEX IF NOT EXISTS idx_students_school_class_section
ON public.students (school_id, class_name, section_name);

-- 9. Index on parent_access_code for Quick PTM Verification
CREATE INDEX IF NOT EXISTS idx_students_parent_access_code
ON public.students (parent_access_code);
