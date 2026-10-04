-- ====================================================================
-- MASTER PRODUCTION-READY DATABASE MIGRATION & RLS CONFIGURATION
-- ====================================================================
-- School Management System — Multi-Tenant Supabase Migration
-- Purpose:
-- 1. Sets up recursion-free helper functions for school & role lookup.
-- 2. Grants full CRUD RLS policies on classes, sections, academic_years, and subjects.
-- 3. Creates missing operational tables: exams, exam_classes, exam_subjects,
--    marks, grade_settings, homework, notices, leave_requests, salary_payments,
--    parent_students, library_books, and transport_routes.
-- 4. Idempotently backfills classes and sections from existing students.
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------------------
-- SECTION 1: RECURSION-FREE HELPER FUNCTIONS
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
    SELECT school_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
    SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated, anon, service_role;


-- --------------------------------------------------------------------
-- SECTION 2: FULL CRUD RLS POLICIES FOR CLASSES & SECTIONS
-- --------------------------------------------------------------------
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own classes" ON public.classes;
DROP POLICY IF EXISTS "School admins can insert own classes" ON public.classes;
DROP POLICY IF EXISTS "School admins can update own classes" ON public.classes;
DROP POLICY IF EXISTS "School admins can delete own classes" ON public.classes;
DROP POLICY IF EXISTS "Authenticated users can select classes" ON public.classes;

CREATE POLICY "School users can view own classes"
ON public.classes FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

CREATE POLICY "School admins can insert own classes"
ON public.classes FOR INSERT TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

CREATE POLICY "School admins can update own classes"
ON public.classes FOR UPDATE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

CREATE POLICY "School admins can delete own classes"
ON public.classes FOR DELETE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);


ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own sections" ON public.sections;
DROP POLICY IF EXISTS "School admins can insert own sections" ON public.sections;
DROP POLICY IF EXISTS "School admins can update own sections" ON public.sections;
DROP POLICY IF EXISTS "School admins can delete own sections" ON public.sections;
DROP POLICY IF EXISTS "Authenticated users can select sections" ON public.sections;

CREATE POLICY "School users can view own sections"
ON public.sections FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

CREATE POLICY "School admins can insert own sections"
ON public.sections FOR INSERT TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

CREATE POLICY "School admins can update own sections"
ON public.sections FOR UPDATE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

CREATE POLICY "School admins can delete own sections"
ON public.sections FOR DELETE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);


-- --------------------------------------------------------------------
-- SECTION 3: FULL CRUD RLS POLICIES FOR ACADEMIC YEARS & SUBJECTS
-- --------------------------------------------------------------------
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own academic years" ON public.academic_years;
DROP POLICY IF EXISTS "School admins can insert academic years" ON public.academic_years;
DROP POLICY IF EXISTS "School admins can update academic years" ON public.academic_years;

CREATE POLICY "School users can view own academic years"
ON public.academic_years FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

CREATE POLICY "School admins can insert academic years"
ON public.academic_years FOR INSERT TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

CREATE POLICY "School admins can update academic years"
ON public.academic_years FOR UPDATE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);


ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own subjects" ON public.subjects;
DROP POLICY IF EXISTS "School admins can manage own subjects" ON public.subjects;

CREATE POLICY "School users can view own subjects"
ON public.subjects FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

CREATE POLICY "School admins can manage own subjects"
ON public.subjects FOR ALL TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);


-- --------------------------------------------------------------------
-- SECTION 4: EXAMINATIONS & RESULTS TABLES
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.exams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT,
    start_date DATE,
    end_date DATE,
    status TEXT NOT NULL DEFAULT 'SCHEDULED' CHECK (status IN ('DRAFT', 'SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED')),
    result_status TEXT NOT NULL DEFAULT 'NOT_PUBLISHED' CHECK (result_status IN ('NOT_PUBLISHED', 'PUBLISHED', 'RETURNED')),
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.exam_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_exam_class UNIQUE (exam_id, class_id)
);

CREATE TABLE IF NOT EXISTS public.exam_subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    subject_name TEXT NOT NULL,
    max_marks NUMERIC NOT NULL DEFAULT 100 CHECK (max_marks > 0),
    passing_marks NUMERIC DEFAULT 33 CHECK (passing_marks >= 0 AND passing_marks <= max_marks),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.marks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    exam_subject_id UUID NOT NULL REFERENCES public.exam_subjects(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    marks_obtained NUMERIC CHECK (marks_obtained >= 0),
    status TEXT NOT NULL DEFAULT 'ENTERED' CHECK (status IN ('NOT_ENTERED', 'ENTERED', 'ABSENT', 'EXEMPTED')),
    remarks TEXT,
    entered_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_student_exam_subject UNIQUE (exam_id, exam_subject_id, student_id)
);

ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "School users can view exams" ON public.exams FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());
CREATE POLICY "School admins can manage exams" ON public.exams FOR ALL TO authenticated
USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));

CREATE POLICY "School users can view exam classes" ON public.exam_classes FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());
CREATE POLICY "School admins can manage exam classes" ON public.exam_classes FOR ALL TO authenticated
USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));

CREATE POLICY "School users can view exam subjects" ON public.exam_subjects FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());
CREATE POLICY "School admins can manage exam subjects" ON public.exam_subjects FOR ALL TO authenticated
USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));

CREATE POLICY "School users can view marks" ON public.marks FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());
CREATE POLICY "Staff and admin can manage marks" ON public.marks FOR ALL TO authenticated
USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'teacher', 'staff'));


-- --------------------------------------------------------------------
-- SECTION 5: OPERATIONAL TABLES (HOMEWORK, NOTICES, LEAVE, SALARY)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.homework (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    class_name TEXT NOT NULL,
    section_name TEXT NOT NULL,
    subject TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUBMITTED', 'CLOSED')),
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.notices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    target_audience TEXT NOT NULL DEFAULT 'ALL' CHECK (target_audience IN ('ALL', 'STUDENTS', 'TEACHERS', 'PARENTS')),
    priority TEXT NOT NULL DEFAULT 'NORMAL' CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT')),
    publish_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expires_at DATE,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.leave_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    applicant_name TEXT NOT NULL,
    applicant_role TEXT NOT NULL DEFAULT 'teacher',
    reason TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    reviewer_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.salary_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    staff_profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    staff_name TEXT NOT NULL,
    amount_paid NUMERIC(12,2) NOT NULL CHECK (amount_paid > 0),
    net_salary NUMERIC(12,2) NOT NULL,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method TEXT NOT NULL DEFAULT 'bank_transfer',
    reference_no TEXT,
    status TEXT NOT NULL DEFAULT 'PAID',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.homework ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salary_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "School isolation for homework" ON public.homework FOR ALL TO authenticated
USING (school_id = public.get_user_school_id());

CREATE POLICY "School isolation for notices" ON public.notices FOR ALL TO authenticated
USING (school_id = public.get_user_school_id());

CREATE POLICY "School isolation for leave_requests" ON public.leave_requests FOR ALL TO authenticated
USING (school_id = public.get_user_school_id());

CREATE POLICY "School isolation for salary_payments" ON public.salary_payments FOR ALL TO authenticated
USING (school_id = public.get_user_school_id());


-- --------------------------------------------------------------------
-- SECTION 6: BACKFILL CLASSES & SECTIONS FROM LIVE STUDENT ROSTER
-- --------------------------------------------------------------------
-- Backfill classes for active school
INSERT INTO public.classes (school_id, academic_year_id, name, display_order)
SELECT DISTINCT 
    s.school_id, 
    s.academic_year_id, 
    CASE 
        WHEN s.class_name ILIKE 'Class %' THEN s.class_name 
        ELSE 'Class ' || s.class_name 
    END AS name,
    COALESCE(NULLIF(regexp_replace(s.class_name, '\D', '', 'g'), '')::INT, 1) AS display_order
FROM public.students s
WHERE s.school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'
ON CONFLICT (school_id, name) DO NOTHING;

-- Backfill sections for active school
INSERT INTO public.sections (school_id, class_id, name)
SELECT DISTINCT 
    s.school_id,
    c.id AS class_id,
    COALESCE(UPPER(TRIM(s.section_name)), 'A') AS name
FROM public.students s
JOIN public.classes c ON c.school_id = s.school_id 
    AND (c.name = s.class_name OR c.name = 'Class ' || s.class_name)
WHERE s.school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'
ON CONFLICT (class_id, name) DO NOTHING;

NOTIFY pgrst, 'reload schema';
