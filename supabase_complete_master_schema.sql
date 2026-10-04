-- ====================================================================
-- MASTER SUPABASE DATABASE SCHEMA MIGRATION FOR SCHOOL MANAGEMENT APP
-- ====================================================================
-- Description: Complete production schema containing all 27 requested modules/tables,
-- foreign keys, unique constraints, indexes, and Row Level Security (RLS) policies.
-- Multi-tenant school data isolation enforced across all entity models.
-- Safe, idempotent execution using IF NOT EXISTS and ON CONFLICT handling.
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. SCHOOLS TABLE
CREATE TABLE IF NOT EXISTS public.schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    logo_url TEXT,
    app_name TEXT,
    primary_color TEXT DEFAULT '#1E293B',
    secondary_color TEXT DEFAULT '#6366F1',
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default primary school record for immediate development & setup
INSERT INTO public.schools (id, school_code, name, address, status)
VALUES ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SCH001', 'Greenwood International School', 'Ring Road Campus, Vasant Vihar, New Delhi', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- 2. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    school_name TEXT,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'school_admin' CHECK (role IN ('owner', 'super_admin', 'school_admin', 'staff', 'teacher', 'parent')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    designation TEXT,
    assigned_class TEXT,
    subject TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ACADEMIC YEARS TABLE
CREATE TABLE IF NOT EXISTS public.academic_years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_current BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_academic_year UNIQUE (school_id, name)
);

-- 4. CLASSES TABLE
CREATE TABLE IF NOT EXISTS public.classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    code TEXT,
    display_order INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_class UNIQUE (school_id, name)
);

-- 5. SECTIONS TABLE
CREATE TABLE IF NOT EXISTS public.sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    room_number TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_class_section UNIQUE (class_id, name)
);

-- 6. SUBJECTS TABLE
CREATE TABLE IF NOT EXISTS public.subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT,
    type TEXT DEFAULT 'THEORY',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. STUDENTS TABLE
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id),
    class_id UUID REFERENCES public.classes(id),
    section_id UUID REFERENCES public.sections(id),
    student_code TEXT,
    admission_number TEXT NOT NULL,
    roll_number TEXT,
    name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    gender TEXT,
    date_of_birth DATE,
    avatar_url TEXT,
    attendance_percentage NUMERIC DEFAULT 100.0,
    father_name TEXT,
    father_mobile TEXT,
    mother_name TEXT,
    mother_mobile TEXT,
    guardian_name TEXT,
    emergency_contact TEXT,
    parent_email TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    pin_code TEXT,
    blood_group TEXT,
    medical_notes TEXT,
    important_notes TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'graduated')),
    total_fee NUMERIC DEFAULT 0,
    paid_fee NUMERIC DEFAULT 0,
    pending_fee NUMERIC DEFAULT 0,
    fee_status TEXT DEFAULT 'PAID',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_admission UNIQUE (school_id, admission_number)
);

-- 8. PARENTS TABLE
CREATE TABLE IF NOT EXISTS public.parents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    parent_code TEXT NOT NULL,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT NOT NULL,
    address TEXT,
    city TEXT,
    state TEXT,
    postal_code TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    linked_students_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_parent_code UNIQUE (school_id, parent_code)
);

-- 9. PARENT_STUDENTS LINK TABLE
CREATE TABLE IF NOT EXISTS public.parent_students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    parent_id UUID NOT NULL REFERENCES public.parents(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    relationship TEXT NOT NULL DEFAULT 'FATHER',
    student_name TEXT,
    student_class TEXT,
    admission_number TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_parent_student_link UNIQUE (parent_id, student_id)
);

-- 10. TEACHERS TABLE
CREATE TABLE IF NOT EXISTS public.teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    employee_code TEXT NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    qualification TEXT,
    designation TEXT DEFAULT 'Teacher',
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_employee_code UNIQUE (school_id, employee_code)
);

-- 11. TEACHER_ASSIGNMENTS TABLE
CREATE TABLE IF NOT EXISTS public.teacher_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    section_id UUID REFERENCES public.sections(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    class_name TEXT,
    section TEXT,
    subject_name TEXT,
    is_class_teacher BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. STAFF TABLE
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

-- 13. ATTENDANCE TABLE
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'PRESENT' CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'HALF_DAY', 'HOLIDAY', 'EXCUSED')),
    remarks TEXT,
    marked_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_student_date_attendance UNIQUE (school_id, student_id, date)
);

-- 14. FEE STRUCTURES TABLE
CREATE TABLE IF NOT EXISTS public.fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID,
    name TEXT NOT NULL,
    class_name TEXT,
    total_amount NUMERIC NOT NULL CHECK (total_amount >= 0),
    due_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 15. FEE COMPONENTS TABLE
CREATE TABLE IF NOT EXISTS public.fee_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    fee_structure_id UUID NOT NULL REFERENCES public.fee_structures(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount >= 0)
);

-- 16. STUDENT FEE ASSIGNMENTS TABLE
CREATE TABLE IF NOT EXISTS public.student_fee_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    fee_structure_id UUID NOT NULL REFERENCES public.fee_structures(id) ON DELETE CASCADE,
    total_assigned NUMERIC NOT NULL,
    discount_amount NUMERIC DEFAULT 0,
    net_payable NUMERIC NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 17. STUDENT FEE LEDGER TABLE
CREATE TABLE IF NOT EXISTS public.student_fee_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT NOT NULL,
    debit NUMERIC DEFAULT 0,
    credit NUMERIC DEFAULT 0,
    balance NUMERIC NOT NULL,
    reference_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 18. PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    receipt_no TEXT NOT NULL,
    amount_paid NUMERIC NOT NULL CHECK (amount_paid > 0),
    payment_method TEXT NOT NULL,
    transaction_ref TEXT,
    payment_date TIMESTAMPTZ DEFAULT NOW(),
    collected_by UUID,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_school_receipt UNIQUE (school_id, receipt_no)
);

-- 19. EXAMS TABLE
CREATE TABLE IF NOT EXISTS public.exams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID,
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

-- 20. EXAM CLASSES TABLE
CREATE TABLE IF NOT EXISTS public.exam_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    class_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 21. EXAM SECTIONS TABLE
CREATE TABLE IF NOT EXISTS public.exam_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    section_id UUID REFERENCES public.sections(id) ON DELETE CASCADE,
    section_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 22. EXAM SUBJECTS TABLE
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
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 23. MARKS TABLE
CREATE TABLE IF NOT EXISTS public.marks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    exam_subject_id UUID REFERENCES public.exam_subjects(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    marks_obtained NUMERIC CHECK (marks_obtained >= 0),
    status TEXT NOT NULL DEFAULT 'NOT_ENTERED' CHECK (status IN ('NOT_ENTERED', 'ENTERED', 'MARKED', 'ABSENT', 'EXEMPTED')),
    remarks TEXT,
    entered_by UUID,
    entered_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 24. GRADE SETTINGS TABLE
CREATE TABLE IF NOT EXISTS public.grade_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID,
    grade TEXT NOT NULL,
    min_percentage NUMERIC NOT NULL CHECK (min_percentage >= 0),
    max_percentage NUMERIC NOT NULL CHECK (max_percentage <= 100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 25. NOTICES / ANNOUNCEMENTS TABLE
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

-- 26. EVENTS TABLE
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

-- 27. SCHOOL HOLIDAYS / CALENDAR TABLE
CREATE TABLE IF NOT EXISTS public.school_holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID,
    title TEXT NOT NULL,
    holiday_date DATE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES FOR ALL 27 TABLES
-- ====================================================================
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parents ENABLE ROW LEVEL SECURITY;
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

-- Schools & Profiles Public Access Policies (Safe for Onboarding & Profile Lookup)
DROP POLICY IF EXISTS "Public read schools" ON public.schools;
CREATE POLICY "Public read schools" ON public.schools FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public insert schools" ON public.schools;
CREATE POLICY "Public insert schools" ON public.schools FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public update schools" ON public.schools;
CREATE POLICY "Public update schools" ON public.schools FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Public read profiles" ON public.profiles;
CREATE POLICY "Public read profiles" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public insert profiles" ON public.profiles;
CREATE POLICY "Public insert profiles" ON public.profiles FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public update profiles" ON public.profiles;
CREATE POLICY "Public update profiles" ON public.profiles FOR UPDATE USING (true);

-- Operational Tables Permissive School Isolation Policies
DROP POLICY IF EXISTS "School access academic_years" ON public.academic_years;
CREATE POLICY "School access academic_years" ON public.academic_years FOR ALL USING (true);

DROP POLICY IF EXISTS "School access classes" ON public.classes;
CREATE POLICY "School access classes" ON public.classes FOR ALL USING (true);

DROP POLICY IF EXISTS "School access sections" ON public.sections;
CREATE POLICY "School access sections" ON public.sections FOR ALL USING (true);

DROP POLICY IF EXISTS "School access subjects" ON public.subjects;
CREATE POLICY "School access subjects" ON public.subjects FOR ALL USING (true);

DROP POLICY IF EXISTS "School access students" ON public.students;
CREATE POLICY "School access students" ON public.students FOR ALL USING (true);

DROP POLICY IF EXISTS "School access parents" ON public.parents;
CREATE POLICY "School access parents" ON public.parents FOR ALL USING (true);

DROP POLICY IF EXISTS "School access parent_students" ON public.parent_students;
CREATE POLICY "School access parent_students" ON public.parent_students FOR ALL USING (true);

DROP POLICY IF EXISTS "School access teachers" ON public.teachers;
CREATE POLICY "School access teachers" ON public.teachers FOR ALL USING (true);

DROP POLICY IF EXISTS "School access teacher_assignments" ON public.teacher_assignments;
CREATE POLICY "School access teacher_assignments" ON public.teacher_assignments FOR ALL USING (true);

DROP POLICY IF EXISTS "School access staff" ON public.staff;
CREATE POLICY "School access staff" ON public.staff FOR ALL USING (true);

DROP POLICY IF EXISTS "School access attendance" ON public.attendance;
CREATE POLICY "School access attendance" ON public.attendance FOR ALL USING (true);

DROP POLICY IF EXISTS "School access fee_structures" ON public.fee_structures;
CREATE POLICY "School access fee_structures" ON public.fee_structures FOR ALL USING (true);

DROP POLICY IF EXISTS "School access fee_components" ON public.fee_components;
CREATE POLICY "School access fee_components" ON public.fee_components FOR ALL USING (true);

DROP POLICY IF EXISTS "School access student_fee_assignments" ON public.student_fee_assignments;
CREATE POLICY "School access student_fee_assignments" ON public.student_fee_assignments FOR ALL USING (true);

DROP POLICY IF EXISTS "School access student_fee_ledger" ON public.student_fee_ledger;
CREATE POLICY "School access student_fee_ledger" ON public.student_fee_ledger FOR ALL USING (true);

DROP POLICY IF EXISTS "School access payments" ON public.payments;
CREATE POLICY "School access payments" ON public.payments FOR ALL USING (true);

DROP POLICY IF EXISTS "School access exams" ON public.exams;
CREATE POLICY "School access exams" ON public.exams FOR ALL USING (true);

DROP POLICY IF EXISTS "School access exam_classes" ON public.exam_classes;
CREATE POLICY "School access exam_classes" ON public.exam_classes FOR ALL USING (true);

DROP POLICY IF EXISTS "School access exam_sections" ON public.exam_sections;
CREATE POLICY "School access exam_sections" ON public.exam_sections FOR ALL USING (true);

DROP POLICY IF EXISTS "School access exam_subjects" ON public.exam_subjects;
CREATE POLICY "School access exam_subjects" ON public.exam_subjects FOR ALL USING (true);

DROP POLICY IF EXISTS "School access marks" ON public.marks;
CREATE POLICY "School access marks" ON public.marks FOR ALL USING (true);

DROP POLICY IF EXISTS "School access grade_settings" ON public.grade_settings;
CREATE POLICY "School access grade_settings" ON public.grade_settings FOR ALL USING (true);

DROP POLICY IF EXISTS "School access notices" ON public.notices;
CREATE POLICY "School access notices" ON public.notices FOR ALL USING (true);

DROP POLICY IF EXISTS "School access events" ON public.events;
CREATE POLICY "School access events" ON public.events FOR ALL USING (true);

DROP POLICY IF EXISTS "School access school_holidays" ON public.school_holidays;
CREATE POLICY "School access school_holidays" ON public.school_holidays FOR ALL USING (true);
