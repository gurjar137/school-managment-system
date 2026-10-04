-- ====================================================================
-- MIGRATION: REMAINING 19 TABLES & SECURE RLS POLICIES
-- ====================================================================
-- Description: Creates all 19 remaining database tables, foreign keys,
-- unique constraints, performance indexes, helper functions, and RLS policies.
-- 
-- IMPORTANT:
-- The following 8 tables ALREADY EXIST in the database and ARE NOT RECREATED:
-- 1. schools
-- 2. profiles
-- 3. academic_years
-- 4. classes
-- 5. sections
-- 6. subjects
-- 7. students
-- 8. parents
-- ====================================================================

-- SECTION 1: HELPER FUNCTIONS FOR RECURSION-FREE RLS POLICIES
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
    SELECT school_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
    SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;


-- SECTION 2: REMAINING 19 CORE & OPERATIONAL TABLES

-- 1. PARENT_STUDENTS LINK TABLE
CREATE TABLE IF NOT EXISTS public.parent_students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    parent_id UUID NOT NULL REFERENCES public.parents(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    relationship TEXT NOT NULL DEFAULT 'FATHER' CHECK (relationship IN ('FATHER', 'MOTHER', 'GUARDIAN', 'OTHER')),
    is_primary BOOLEAN DEFAULT FALSE,
    student_name TEXT,
    student_class TEXT,
    admission_number TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_parent_student_link UNIQUE (parent_id, student_id)
);

-- 2. TEACHERS TABLE
CREATE TABLE IF NOT EXISTS public.teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    employee_code TEXT NOT NULL,
    employee_id TEXT,
    name TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    qualification TEXT,
    designation TEXT DEFAULT 'Teacher',
    profile_photo_url TEXT,
    joining_date DATE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_teacher_employee UNIQUE (school_id, employee_code)
);

-- 3. TEACHER_ASSIGNMENTS TABLE
CREATE TABLE IF NOT EXISTS public.teacher_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    section_id UUID REFERENCES public.sections(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    class_name TEXT,
    section TEXT,
    subject_name TEXT,
    is_class_teacher BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_teacher_class_subject UNIQUE (school_id, teacher_id, class_id, section_id, subject_id)
);

-- 4. STAFF TABLE
CREATE TABLE IF NOT EXISTS public.staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    employee_code TEXT,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    designation TEXT DEFAULT 'Administrative Staff',
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. ATTENDANCE TABLE
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'PRESENT' CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'HALF_DAY', 'HOLIDAY', 'EXCUSED')),
    remarks TEXT,
    marked_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_student_daily_attendance UNIQUE (school_id, student_id, date)
);

-- 6. FEE STRUCTURES TABLE
CREATE TABLE IF NOT EXISTS public.fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    class_name TEXT,
    total_amount NUMERIC NOT NULL CHECK (total_amount >= 0),
    frequency TEXT DEFAULT 'ANNUAL',
    due_date DATE,
    status TEXT DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. FEE COMPONENTS TABLE
CREATE TABLE IF NOT EXISTS public.fee_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    fee_structure_id UUID NOT NULL REFERENCES public.fee_structures(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount >= 0),
    frequency TEXT DEFAULT 'MONTHLY',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. STUDENT FEE ASSIGNMENTS TABLE
CREATE TABLE IF NOT EXISTS public.student_fee_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    fee_structure_id UUID NOT NULL REFERENCES public.fee_structures(id) ON DELETE CASCADE,
    total_assigned NUMERIC NOT NULL CHECK (total_assigned >= 0),
    discount_amount NUMERIC DEFAULT 0 CHECK (discount_amount >= 0),
    net_payable NUMERIC NOT NULL CHECK (net_payable >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_student_fee_structure UNIQUE (student_id, fee_structure_id)
);

-- 9. STUDENT FEE LEDGER TABLE
CREATE TABLE IF NOT EXISTS public.student_fee_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT NOT NULL,
    debit NUMERIC DEFAULT 0 CHECK (debit >= 0),
    credit NUMERIC DEFAULT 0 CHECK (credit >= 0),
    balance NUMERIC NOT NULL,
    reference_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    receipt_no TEXT NOT NULL,
    amount_paid NUMERIC NOT NULL CHECK (amount_paid > 0),
    payment_method TEXT NOT NULL,
    transaction_ref TEXT,
    payment_date TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'COMPLETED',
    collected_by UUID,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_payment_receipt UNIQUE (school_id, receipt_no)
);

-- 11. EXAMS TABLE
CREATE TABLE IF NOT EXISTS public.exams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT,
    start_date DATE,
    end_date DATE,
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED', 'SUBMITTED', 'APPROVED')),
    result_status TEXT NOT NULL DEFAULT 'NOT_PUBLISHED' CHECK (result_status IN ('NOT_PUBLISHED', 'PUBLISHED')),
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    locked_at TIMESTAMPTZ,
    locked_by UUID,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. EXAM CLASSES TABLE
CREATE TABLE IF NOT EXISTS public.exam_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    class_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_exam_class_link UNIQUE (exam_id, class_id)
);

-- 13. EXAM SECTIONS TABLE
CREATE TABLE IF NOT EXISTS public.exam_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    section_id UUID REFERENCES public.sections(id) ON DELETE CASCADE,
    section_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 14. EXAM SUBJECTS TABLE
CREATE TABLE IF NOT EXISTS public.exam_subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    subject_name TEXT,
    max_marks NUMERIC NOT NULL CHECK (max_marks > 0),
    passing_marks NUMERIC CHECK (passing_marks >= 0 AND passing_marks <= max_marks),
    weightage NUMERIC DEFAULT 100 CHECK (weightage >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_exam_class_subject_link UNIQUE (exam_id, class_id, subject_id)
);

-- 15. MARKS TABLE
CREATE TABLE IF NOT EXISTS public.marks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    exam_subject_id UUID REFERENCES public.exam_subjects(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    marks_obtained NUMERIC CHECK (marks_obtained >= 0),
    status TEXT NOT NULL DEFAULT 'NOT_ENTERED' CHECK (status IN ('NOT_ENTERED', 'ENTERED', 'MARKED', 'ABSENT', 'EXEMPTED')),
    remarks TEXT,
    entered_by UUID,
    entered_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_exam_subject_student_mark UNIQUE (exam_id, exam_subject_id, student_id)
);

-- 16. GRADE SETTINGS TABLE
CREATE TABLE IF NOT EXISTS public.grade_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    grade TEXT NOT NULL,
    min_percentage NUMERIC NOT NULL CHECK (min_percentage >= 0 AND min_percentage <= 100),
    max_percentage NUMERIC NOT NULL CHECK (max_percentage >= 0 AND max_percentage <= 100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_grade_rule UNIQUE (school_id, grade)
);

-- 17. NOTICES TABLE
CREATE TABLE IF NOT EXISTS public.notices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    target_audience TEXT NOT NULL DEFAULT 'all' CHECK (target_audience IN ('all', 'parents', 'teachers', 'staff')),
    publish_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    status TEXT DEFAULT 'PUBLISHED',
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 18. EVENTS TABLE
CREATE TABLE IF NOT EXISTS public.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    start_datetime TIMESTAMPTZ NOT NULL,
    end_datetime TIMESTAMPTZ NOT NULL,
    location TEXT,
    status TEXT DEFAULT 'SCHEDULED',
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 19. SCHOOL HOLIDAYS TABLE
CREATE TABLE IF NOT EXISTS public.school_holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    holiday_date DATE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- SECTION 3: INDEXES FOR OPTIMIZED QUERYING
CREATE INDEX IF NOT EXISTS idx_parent_students_school ON public.parent_students(school_id, parent_id, student_id);
CREATE INDEX IF NOT EXISTS idx_teachers_school ON public.teachers(school_id, email, employee_code);
CREATE INDEX IF NOT EXISTS idx_teacher_assignments_lookup ON public.teacher_assignments(school_id, teacher_id, class_id, section_id, subject_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student_date ON public.attendance(school_id, student_id, date);
CREATE INDEX IF NOT EXISTS idx_fee_ledger_student ON public.student_fee_ledger(school_id, student_id, date);
CREATE INDEX IF NOT EXISTS idx_payments_student ON public.payments(school_id, student_id, receipt_no);
CREATE INDEX IF NOT EXISTS idx_exams_school_year ON public.exams(school_id, academic_year_id, status);
CREATE INDEX IF NOT EXISTS idx_marks_exam_student ON public.marks(school_id, exam_id, exam_subject_id, student_id);
CREATE INDEX IF NOT EXISTS idx_notices_school ON public.notices(school_id, target_audience, publish_at);


-- SECTION 4: ROW LEVEL SECURITY (RLS) ENABLEMENT & STRICT POLICIES
ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_structures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_fee_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_fee_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grade_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_holidays ENABLE ROW LEVEL SECURITY;

-- 1. ADMIN FULL ACCESS (OWN SCHOOL)
CREATE POLICY "Admins full CRUD remaining tables" ON public.parent_students FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD teachers" ON public.teachers FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD teacher_assignments" ON public.teacher_assignments FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD staff" ON public.staff FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD attendance" ON public.attendance FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD fee_structures" ON public.fee_structures FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD fee_components" ON public.fee_components FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD student_fee_assignments" ON public.student_fee_assignments FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD student_fee_ledger" ON public.student_fee_ledger FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD payments" ON public.payments FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD exams" ON public.exams FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD exam_classes" ON public.exam_classes FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD exam_sections" ON public.exam_sections FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD exam_subjects" ON public.exam_subjects FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD marks" ON public.marks FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD grade_settings" ON public.grade_settings FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD notices" ON public.notices FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD events" ON public.events FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));
CREATE POLICY "Admins full CRUD school_holidays" ON public.school_holidays FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));

-- 2. TEACHER ACCESS POLICIES (ASSIGNED SCHOOL & CLASSES)
CREATE POLICY "Teachers view school exams" ON public.exams FOR SELECT USING (school_id = public.get_user_school_id() AND public.get_user_role() = 'teacher');
CREATE POLICY "Teachers view school exam_subjects" ON public.exam_subjects FOR SELECT USING (school_id = public.get_user_school_id() AND public.get_user_role() = 'teacher');
CREATE POLICY "Teachers manage marks for school" ON public.marks FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() = 'teacher');
CREATE POLICY "Teachers manage attendance for school" ON public.attendance FOR ALL USING (school_id = public.get_user_school_id() AND public.get_user_role() = 'teacher');
CREATE POLICY "Teachers view school notices" ON public.notices FOR SELECT USING (school_id = public.get_user_school_id() AND target_audience IN ('all', 'teachers'));
CREATE POLICY "Teachers view school events" ON public.events FOR SELECT USING (school_id = public.get_user_school_id());
CREATE POLICY "Teachers view school holidays" ON public.school_holidays FOR SELECT USING (school_id = public.get_user_school_id());

-- 3. PARENT ACCESS POLICIES (LINKED CHILDREN & PUBLISHED RESULTS ONLY)
CREATE POLICY "Parents view parent_students links" ON public.parent_students FOR SELECT USING (
    school_id = public.get_user_school_id() AND
    parent_id IN (SELECT id FROM public.parents WHERE email = (SELECT email FROM public.profiles WHERE auth_user_id = auth.uid()))
);

CREATE POLICY "Parents view linked child attendance" ON public.attendance FOR SELECT USING (
    school_id = public.get_user_school_id() AND
    student_id IN (
        SELECT ps.student_id FROM public.parent_students ps
        JOIN public.parents p ON p.id = ps.parent_id
        JOIN public.profiles prof ON prof.email = p.email
        WHERE prof.auth_user_id = auth.uid()
    )
);

CREATE POLICY "Parents view published child marks" ON public.marks FOR SELECT USING (
    school_id = public.get_user_school_id() AND
    exam_id IN (SELECT id FROM public.exams WHERE result_status = 'PUBLISHED') AND
    student_id IN (
        SELECT ps.student_id FROM public.parent_students ps
        JOIN public.parents p ON p.id = ps.parent_id
        JOIN public.profiles prof ON prof.email = p.email
        WHERE prof.auth_user_id = auth.uid()
    )
);

CREATE POLICY "Parents view linked child fee ledger" ON public.student_fee_ledger FOR SELECT USING (
    school_id = public.get_user_school_id() AND
    student_id IN (
        SELECT ps.student_id FROM public.parent_students ps
        JOIN public.parents p ON p.id = ps.parent_id
        JOIN public.profiles prof ON prof.email = p.email
        WHERE prof.auth_user_id = auth.uid()
    )
);

CREATE POLICY "Parents view linked child payments" ON public.payments FOR SELECT USING (
    school_id = public.get_user_school_id() AND
    student_id IN (
        SELECT ps.student_id FROM public.parent_students ps
        JOIN public.parents p ON p.id = ps.parent_id
        JOIN public.profiles prof ON prof.email = p.email
        WHERE prof.auth_user_id = auth.uid()
    )
);

CREATE POLICY "Parents view school notices" ON public.notices FOR SELECT USING (
    school_id = public.get_user_school_id() AND target_audience IN ('all', 'parents')
);

CREATE POLICY "Parents view school events" ON public.events FOR SELECT USING (
    school_id = public.get_user_school_id()
);

CREATE POLICY "Parents view school holidays" ON public.school_holidays FOR SELECT USING (
    school_id = public.get_user_school_id()
);
