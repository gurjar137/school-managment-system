-- ====================================================================
-- STEP 10: EXAMINATION, MARKS ENTRY & RESULT CALCULATION SCHEMA
-- ====================================================================
-- Description: Sets up tables, indexes, constraints, and RLS policies
-- for Exams, Exam Classes, Exam Subjects, Marks, and Grade Settings.
-- Multi-tenant school isolation and parent published-only access enforced.
-- ====================================================================

-- 1. EXAMS TABLE
CREATE TABLE IF NOT EXISTS public.exams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    start_date DATE,
    end_date DATE,
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED')),
    result_status TEXT NOT NULL DEFAULT 'NOT_PUBLISHED' CHECK (result_status IN ('NOT_PUBLISHED', 'PUBLISHED')),
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    locked_at TIMESTAMPTZ,
    locked_by UUID,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. EXAM CLASSES TABLE
CREATE TABLE IF NOT EXISTS public.exam_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID NOT NULL,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_exam_class UNIQUE (exam_id, class_id)
);

-- 3. EXAM SUBJECTS TABLE
CREATE TABLE IF NOT EXISTS public.exam_subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    max_marks NUMERIC NOT NULL CHECK (max_marks > 0),
    passing_marks NUMERIC CHECK (passing_marks >= 0 AND passing_marks <= max_marks),
    weightage NUMERIC DEFAULT 100 CHECK (weightage >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_exam_class_subject UNIQUE (exam_id, class_id, subject_id)
);

-- 4. MARKS TABLE
CREATE TABLE IF NOT EXISTS public.marks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID NOT NULL,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    exam_subject_id UUID NOT NULL REFERENCES public.exam_subjects(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    marks_obtained NUMERIC CHECK (marks_obtained >= 0),
    status TEXT NOT NULL DEFAULT 'NOT_ENTERED' CHECK (status IN ('NOT_ENTERED', 'ENTERED', 'ABSENT', 'EXEMPTED')),
    remarks TEXT,
    entered_by UUID,
    entered_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_student_exam_subject UNIQUE (exam_id, exam_subject_id, student_id)
);

-- 5. GRADE SETTINGS TABLE
CREATE TABLE IF NOT EXISTS public.grade_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID,
    grade TEXT NOT NULL,
    min_percentage NUMERIC NOT NULL CHECK (min_percentage >= 0),
    max_percentage NUMERIC NOT NULL CHECK (max_percentage <= 100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_grade UNIQUE (school_id, grade)
);

-- ====================================================================
-- INDEXES FOR OPTIMIZED QUERYING
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_exams_school_year ON public.exams(school_id, academic_year_id);
CREATE INDEX IF NOT EXISTS idx_exams_status ON public.exams(status, result_status);
CREATE INDEX IF NOT EXISTS idx_exam_classes_exam ON public.exam_classes(exam_id, class_id);
CREATE INDEX IF NOT EXISTS idx_exam_subjects_exam ON public.exam_subjects(exam_id, class_id, subject_id);
CREATE INDEX IF NOT EXISTS idx_marks_student_exam ON public.marks(school_id, exam_id, exam_subject_id, student_id);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grade_settings ENABLE ROW LEVEL SECURITY;

-- EXAMS POLICIES
CREATE POLICY "Admins full access to exams" ON public.exams
    FOR ALL USING (
        auth.uid() IN (
            SELECT p.auth_user_id FROM public.profiles p
            WHERE p.school_id = exams.school_id AND p.role IN ('owner', 'superadmin', 'school_admin')
        )
    );

CREATE POLICY "Teachers view school exams" ON public.exams
    FOR SELECT USING (
        auth.uid() IN (
            SELECT p.auth_user_id FROM public.profiles p
            WHERE p.school_id = exams.school_id AND p.role IN ('teacher', 'staff')
        )
    );

CREATE POLICY "Parents view published exams for linked children" ON public.exams
    FOR SELECT USING (
        exams.result_status = 'PUBLISHED' AND
        auth.uid() IN (
            SELECT p.auth_user_id FROM public.profiles p
            JOIN public.parents par ON par.email = p.email
            JOIN public.parent_students ps ON ps.parent_id = par.id
            JOIN public.students s ON s.id = ps.student_id
            WHERE s.school_id = exams.school_id
        )
    );

-- MARKS POLICIES
CREATE POLICY "Admins full access to marks" ON public.marks
    FOR ALL USING (
        auth.uid() IN (
            SELECT p.auth_user_id FROM public.profiles p
            WHERE p.school_id = marks.school_id AND p.role IN ('owner', 'superadmin', 'school_admin')
        )
    );

CREATE POLICY "Teachers manage marks for authorized school" ON public.marks
    FOR ALL USING (
        auth.uid() IN (
            SELECT p.auth_user_id FROM public.profiles p
            WHERE p.school_id = marks.school_id AND p.role = 'teacher'
        )
    );

CREATE POLICY "Parents read published marks for linked children" ON public.marks
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.exams e WHERE e.id = marks.exam_id AND e.result_status = 'PUBLISHED'
        ) AND
        auth.uid() IN (
            SELECT p.auth_user_id FROM public.profiles p
            JOIN public.parents par ON par.email = p.email
            JOIN public.parent_students ps ON ps.parent_id = par.id
            WHERE ps.student_id = marks.student_id
        )
    );

-- GRADE SETTINGS POLICIES
CREATE POLICY "Admins manage grade settings" ON public.grade_settings
    FOR ALL USING (
        auth.uid() IN (
            SELECT p.auth_user_id FROM public.profiles p
            WHERE p.school_id = grade_settings.school_id AND p.role IN ('owner', 'superadmin', 'school_admin')
        )
    );

CREATE POLICY "All authenticated users view grade settings" ON public.grade_settings
    FOR SELECT USING (
        auth.uid() IN (
            SELECT p.auth_user_id FROM public.profiles p
            WHERE p.school_id = grade_settings.school_id
        )
    );
