-- ====================================================================
-- SUPABASE MASTER PRODUCTION MIGRATION (IDEMPOTENT & CONSOLIDATED)
-- TARGET SCHOOL: Kamal Public School (KPS)
-- SCHOOL UUID: 6254bee9-151d-4332-8a1c-3994af7d2153
-- ACADEMIC YEAR UUID: 47d1569b-e032-44a7-891f-b21f5458f55b (2026-2027)
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. EXTENSIONS
-- --------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- --------------------------------------------------------------------
-- 2. CORE INSTITUTION & ACADEMIC YEAR
-- --------------------------------------------------------------------
INSERT INTO public.schools (id, name, code, status, created_at)
VALUES (
    '6254bee9-151d-4332-8a1c-3994af7d2153',
    'Kamal Public School',
    'KPS',
    'active',
    NOW()
)
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name,
    code = EXCLUDED.code,
    status = EXCLUDED.status;

INSERT INTO public.academic_years (id, school_id, name, start_date, end_date, is_current, status, created_at)
VALUES (
    '47d1569b-e032-44a7-891f-b21f5458f55b',
    '6254bee9-151d-4332-8a1c-3994af7d2153',
    '2026-2027',
    '2026-04-01',
    '2027-03-31',
    TRUE,
    'ACTIVE',
    NOW()
)
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name,
    is_current = EXCLUDED.is_current,
    status = EXCLUDED.status;

-- --------------------------------------------------------------------
-- 3. RECURSION-FREE HARDENED TENANT FUNCTIONS
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

    IF v_school_id IS NOT NULL THEN
        RETURN v_school_id;
    END IF;

    -- Step 4: Fallback to canonical KPS school ID for authenticated school users
    RETURN '6254bee9-151d-4332-8a1c-3994af7d2153'::UUID;
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
        RETURN 'anon';
    END IF;

    -- Step 1: Read from public.profiles
    SELECT role INTO v_role 
    FROM public.profiles 
    WHERE auth_user_id = v_auth_uid 
    LIMIT 1;

    IF v_role IS NOT NULL AND v_role <> '' THEN
        RETURN v_role;
    END IF;

    -- Step 2: Fallback to request JWT user_metadata claims
    BEGIN
        v_role := current_setting('request.jwt.claims', true)::jsonb->'user_metadata'->>'role';
    EXCEPTION WHEN OTHERS THEN
        v_role := NULL;
    END;

    IF v_role IS NOT NULL AND v_role <> '' THEN
        RETURN v_role;
    END IF;

    -- Step 3: Fallback to auth.users
    BEGIN
        SELECT raw_user_meta_data->>'role' INTO v_role
        FROM auth.users
        WHERE id = v_auth_uid;
    EXCEPTION WHEN OTHERS THEN
        v_role := NULL;
    END;

    RETURN COALESCE(v_role, 'school_admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated, anon, service_role;

-- --------------------------------------------------------------------
-- 4. 12 CANONICAL CLASSES (CLASS 1 - CLASS 12)
-- --------------------------------------------------------------------
INSERT INTO public.classes (id, school_id, academic_year_id, name, display_order, status, created_at)
VALUES 
    ('6254bee9-c1a5-0001-8000-000000000001', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 1', 1, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-0002-8000-000000000002', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 2', 2, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-0003-8000-000000000003', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 3', 3, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-0004-8000-000000000004', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 4', 4, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-0005-8000-000000000005', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 5', 5, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-0006-8000-000000000006', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 6', 6, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-0007-8000-000000000007', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 7', 7, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-0008-8000-000000000008', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 8', 8, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-0009-8000-000000000009', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 9', 9, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-000a-8000-000000000010', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 10', 10, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-000b-8000-000000000011', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 11', 11, 'ACTIVE', NOW()),
    ('6254bee9-c1a5-000c-8000-000000000012', '6254bee9-151d-4332-8a1c-3994af7d2153', '47d1569b-e032-44a7-891f-b21f5458f55b', 'Class 12', 12, 'ACTIVE', NOW())
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name,
    display_order = EXCLUDED.display_order,
    status = EXCLUDED.status;

-- --------------------------------------------------------------------
-- 5. CANONICAL SECTIONS (A, B) FOR EACH CLASS
-- --------------------------------------------------------------------
INSERT INTO public.sections (id, class_id, name, status, created_at)
VALUES 
    -- Class 1
    ('6254bee9-5ec1-4000-8000-000000000165', '6254bee9-c1a5-0001-8000-000000000001', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000000166', '6254bee9-c1a5-0001-8000-000000000001', 'B', 'ACTIVE', NOW()),
    -- Class 2
    ('6254bee9-5ec1-4000-8000-000000000265', '6254bee9-c1a5-0002-8000-000000000002', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000000266', '6254bee9-c1a5-0002-8000-000000000002', 'B', 'ACTIVE', NOW()),
    -- Class 3
    ('6254bee9-5ec1-4000-8000-000000000365', '6254bee9-c1a5-0003-8000-000000000003', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000000366', '6254bee9-c1a5-0003-8000-000000000003', 'B', 'ACTIVE', NOW()),
    -- Class 4
    ('6254bee9-5ec1-4000-8000-000000000465', '6254bee9-c1a5-0004-8000-000000000004', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000000466', '6254bee9-c1a5-0004-8000-000000000004', 'B', 'ACTIVE', NOW()),
    -- Class 5
    ('6254bee9-5ec1-4000-8000-000000000565', '6254bee9-c1a5-0005-8000-000000000005', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000000566', '6254bee9-c1a5-0005-8000-000000000005', 'B', 'ACTIVE', NOW()),
    -- Class 6
    ('6254bee9-5ec1-4000-8000-000000000665', '6254bee9-c1a5-0006-8000-000000000006', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000000666', '6254bee9-c1a5-0006-8000-000000000006', 'B', 'ACTIVE', NOW()),
    -- Class 7
    ('6254bee9-5ec1-4000-8000-000000000765', '6254bee9-c1a5-0007-8000-000000000007', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000000766', '6254bee9-c1a5-0007-8000-000000000007', 'B', 'ACTIVE', NOW()),
    -- Class 8
    ('6254bee9-5ec1-4000-8000-000000000865', '6254bee9-c1a5-0008-8000-000000000008', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000000866', '6254bee9-c1a5-0008-8000-000000000008', 'B', 'ACTIVE', NOW()),
    -- Class 9
    ('6254bee9-5ec1-4000-8000-000000000965', '6254bee9-c1a5-0009-8000-000000000009', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000000966', '6254bee9-c1a5-0009-8000-000000000009', 'B', 'ACTIVE', NOW()),
    -- Class 10
    ('6254bee9-5ec1-4000-8000-000000001065', '6254bee9-c1a5-000a-8000-000000000010', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000001066', '6254bee9-c1a5-000a-8000-000000000010', 'B', 'ACTIVE', NOW()),
    -- Class 11
    ('6254bee9-5ec1-4000-8000-000000001165', '6254bee9-c1a5-000b-8000-000000000011', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000001166', '6254bee9-c1a5-000b-8000-000000000011', 'B', 'ACTIVE', NOW()),
    -- Class 12
    ('6254bee9-5ec1-4000-8000-000000001265', '6254bee9-c1a5-000c-8000-000000000012', 'A', 'ACTIVE', NOW()),
    ('6254bee9-5ec1-4000-8000-000000001266', '6254bee9-c1a5-000c-8000-000000000012', 'B', 'ACTIVE', NOW())
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name,
    status = EXCLUDED.status;

-- --------------------------------------------------------------------
-- 6. TIMETABLE ENTRIES TABLE & RLS
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.timetable_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
    subject_id UUID,
    subject_name TEXT NOT NULL,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    teacher_name TEXT NOT NULL,
    day_of_week TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    room_number TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_timetable_school ON public.timetable_entries(school_id);
CREATE INDEX IF NOT EXISTS idx_timetable_class_section ON public.timetable_entries(class_id, section_id);
CREATE INDEX IF NOT EXISTS idx_timetable_teacher ON public.timetable_entries(teacher_id);

ALTER TABLE public.timetable_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Timetable viewable by school authenticated users" ON public.timetable_entries;
DROP POLICY IF EXISTS "Timetable manageable by school admins" ON public.timetable_entries;

CREATE POLICY "Timetable viewable by school authenticated users"
ON public.timetable_entries FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

CREATE POLICY "Timetable manageable by school admins"
ON public.timetable_entries FOR ALL TO authenticated
USING (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- --------------------------------------------------------------------
-- 7. FEE MANAGEMENT TABLES & RLS
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fee_structures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    fee_type TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    frequency TEXT NOT NULL DEFAULT 'MONTHLY',
    due_day INTEGER DEFAULT 10,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.student_fee_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    student_id UUID NOT NULL,
    fee_structure_id UUID REFERENCES public.fee_structures(id) ON DELETE SET NULL,
    gross_fee NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    waiver_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    net_fee NUMERIC(10,2) GENERATED ALWAYS AS (gross_fee - discount_amount - waiver_amount) STORED,
    total_paid NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    current_due NUMERIC(10,2) GENERATED ALWAYS AS (gross_fee - discount_amount - waiver_amount - total_paid) STORED,
    due_date DATE,
    status TEXT NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.fee_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL,
    fee_account_id UUID REFERENCES public.student_fee_accounts(id) ON DELETE SET NULL,
    amount_paid NUMERIC(10,2) NOT NULL,
    payment_mode TEXT NOT NULL DEFAULT 'CASH',
    receipt_number TEXT NOT NULL,
    transaction_reference TEXT,
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    collected_by UUID,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.fee_structures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_fee_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Fee structures viewable by school" ON public.fee_structures;
DROP POLICY IF EXISTS "Fee structures manageable by admin" ON public.fee_structures;
CREATE POLICY "Fee structures viewable by school" ON public.fee_structures FOR SELECT TO authenticated USING (school_id = public.get_user_school_id());
CREATE POLICY "Fee structures manageable by admin" ON public.fee_structures FOR ALL TO authenticated USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));

DROP POLICY IF EXISTS "Fee accounts viewable by school" ON public.student_fee_accounts;
DROP POLICY IF EXISTS "Fee accounts manageable by admin" ON public.student_fee_accounts;
CREATE POLICY "Fee accounts viewable by school" ON public.student_fee_accounts FOR SELECT TO authenticated USING (school_id = public.get_user_school_id());
CREATE POLICY "Fee accounts manageable by admin" ON public.student_fee_accounts FOR ALL TO authenticated USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));

DROP POLICY IF EXISTS "Fee payments viewable by school" ON public.fee_payments;
DROP POLICY IF EXISTS "Fee payments manageable by admin" ON public.fee_payments;
CREATE POLICY "Fee payments viewable by school" ON public.fee_payments FOR SELECT TO authenticated USING (school_id = public.get_user_school_id());
CREATE POLICY "Fee payments manageable by admin" ON public.fee_payments FOR ALL TO authenticated USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'));

-- --------------------------------------------------------------------
-- 8. OPERATIONAL TABLES (HOMEWORK, NOTICES, LEAVE REQUESTS, NOTIFICATIONS)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.homework (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    class_name TEXT NOT NULL,
    section_name TEXT NOT NULL,
    subject TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    attachment_name TEXT,
    due_date DATE NOT NULL,
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'active',
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.homework ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Homework viewable by school" ON public.homework;
DROP POLICY IF EXISTS "Homework manageable by staff" ON public.homework;
CREATE POLICY "Homework viewable by school" ON public.homework FOR SELECT TO authenticated USING (school_id = public.get_user_school_id());
CREATE POLICY "Homework manageable by staff" ON public.homework FOR ALL TO authenticated USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'teacher'));

CREATE TABLE IF NOT EXISTS public.notices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    author TEXT NOT NULL DEFAULT 'Administration',
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Notices viewable by school" ON public.notices;
DROP POLICY IF EXISTS "Notices manageable by staff" ON public.notices;
CREATE POLICY "Notices viewable by school" ON public.notices FOR SELECT TO authenticated USING (school_id = public.get_user_school_id());
CREATE POLICY "Notices manageable by staff" ON public.notices FOR ALL TO authenticated USING (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'teacher'));

CREATE TABLE IF NOT EXISTS public.leave_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL,
    student_id UUID NOT NULL,
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leave requests viewable by school" ON public.leave_requests;
DROP POLICY IF EXISTS "Leave requests manageable by school" ON public.leave_requests;
CREATE POLICY "Leave requests viewable by school" ON public.leave_requests FOR SELECT TO authenticated USING (school_id = public.get_user_school_id());
CREATE POLICY "Leave requests manageable by school" ON public.leave_requests FOR ALL TO authenticated USING (school_id = public.get_user_school_id());

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    is_unread BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Notifications viewable by user" ON public.notifications;
CREATE POLICY "Notifications viewable by user" ON public.notifications FOR ALL TO authenticated USING (school_id = public.get_user_school_id());

-- --------------------------------------------------------------------
-- 9. ADMIN & TEACHER PROFILES BACKFILL FOR KPS
-- --------------------------------------------------------------------
-- Backfill Admin Profile
INSERT INTO public.profiles (
    id, auth_user_id, school_id, full_name, role, status, designation, created_at, updated_at
)
VALUES (
    'b773c510-a0b4-47c7-af58-145adc883ca7',
    'b773c510-a0b4-47c7-af58-145adc883ca7',
    '6254bee9-151d-4332-8a1c-3994af7d2153',
    'School Administrator',
    'school_admin',
    'active',
    'Principal & Administrator',
    NOW(),
    NOW()
)
ON CONFLICT (auth_user_id) DO UPDATE 
SET school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
    role = 'school_admin',
    status = 'active';

-- Backfill Teacher 1A
INSERT INTO public.profiles (
    id, auth_user_id, school_id, full_name, role, status, designation, assigned_class, assigned_section, created_at, updated_at
)
VALUES (
    'c0448877-9f37-4c2d-b1f2-3de38a9e63df',
    'c0448877-9f37-4c2d-b1f2-3de38a9e63df',
    '6254bee9-151d-4332-8a1c-3994af7d2153',
    'Sunita Sharma',
    'teacher',
    'active',
    'Class Teacher 1A',
    'Class 1',
    'A',
    NOW(),
    NOW()
)
ON CONFLICT (auth_user_id) DO UPDATE 
SET school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
    role = 'teacher',
    assigned_class = 'Class 1',
    assigned_section = 'A',
    status = 'active';

-- Backfill Teacher 1B
INSERT INTO public.profiles (
    id, auth_user_id, school_id, full_name, role, status, designation, assigned_class, assigned_section, created_at, updated_at
)
VALUES (
    '2db09867-27b5-41e9-9115-62181516e834',
    '2db09867-27b5-41e9-9115-62181516e834',
    '6254bee9-151d-4332-8a1c-3994af7d2153',
    'Rajesh Kumar',
    'teacher',
    'active',
    'Class Teacher 1B',
    'Class 1',
    'B',
    NOW(),
    NOW()
)
ON CONFLICT (auth_user_id) DO UPDATE 
SET school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
    role = 'teacher',
    assigned_class = 'Class 1',
    assigned_section = 'B',
    status = 'active';

-- Backfill Teacher 2A
INSERT INTO public.profiles (
    id, auth_user_id, school_id, full_name, role, status, designation, assigned_class, assigned_section, created_at, updated_at
)
VALUES (
    'f6cc4468-b3d9-40ea-9bb7-fe370b4f8cb6',
    'f6cc4468-b3d9-40ea-9bb7-fe370b4f8cb6',
    '6254bee9-151d-4332-8a1c-3994af7d2153',
    'Pooja Verma',
    'teacher',
    'active',
    'Class Teacher 2A',
    'Class 2',
    'A',
    NOW(),
    NOW()
)
ON CONFLICT (auth_user_id) DO UPDATE 
SET school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
    role = 'teacher',
    assigned_class = 'Class 2',
    assigned_section = 'A',
    status = 'active';

-- Backfill Teacher 2B
INSERT INTO public.profiles (
    id, auth_user_id, school_id, full_name, role, status, designation, assigned_class, assigned_section, created_at, updated_at
)
VALUES (
    '44927d31-f111-4fdc-a352-7b3b35eeaa35',
    '44927d31-f111-4fdc-a352-7b3b35eeaa35',
    '6254bee9-151d-4332-8a1c-3994af7d2153',
    'Amit Patel',
    'teacher',
    'active',
    'Class Teacher 2B',
    'Class 2',
    'B',
    NOW(),
    NOW()
)
ON CONFLICT (auth_user_id) DO UPDATE 
SET school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
    role = 'teacher',
    assigned_class = 'Class 2',
    assigned_section = 'B',
    status = 'active';

-- Backfill Teacher 10A
INSERT INTO public.profiles (
    id, auth_user_id, school_id, full_name, role, status, designation, assigned_class, assigned_section, created_at, updated_at
)
VALUES (
    '5f78d2ae-52cf-424a-9b43-bfa58be9f4df',
    '5f78d2ae-52cf-424a-9b43-bfa58be9f4df',
    '6254bee9-151d-4332-8a1c-3994af7d2153',
    'Anjali Mehta',
    'teacher',
    'active',
    'Senior Mathematics Teacher 10A',
    'Class 10',
    'A',
    NOW(),
    NOW()
)
ON CONFLICT (auth_user_id) DO UPDATE 
SET school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
    role = 'teacher',
    assigned_class = 'Class 10',
    assigned_section = 'A',
    status = 'active';

-- --------------------------------------------------------------------
-- 10. ATOMIC NEW USER SIGNUP TRIGGER
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_school_id UUID;
    v_role TEXT;
    v_full_name TEXT;
BEGIN
    v_school_id := (NULLIF(NEW.raw_user_meta_data->>'school_id', ''))::UUID;
    IF v_school_id IS NULL THEN
        v_school_id := '6254bee9-151d-4332-8a1c-3994af7d2153'::UUID;
    END IF;

    v_role := COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', ''), 'school_admin');
    v_full_name := COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), NULLIF(NEW.raw_user_meta_data->>'name', ''), split_part(NEW.email, '@', 1));

    INSERT INTO public.profiles (
        id,
        auth_user_id,
        school_id,
        full_name,
        role,
        status,
        designation,
        assigned_class,
        assigned_section,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        NEW.id,
        v_school_id,
        v_full_name,
        v_role,
        'active',
        COALESCE(NEW.raw_user_meta_data->>'designation', 'School Faculty'),
        NEW.raw_user_meta_data->>'assigned_class',
        NEW.raw_user_meta_data->>'assigned_section',
        NOW(),
        NOW()
    )
    ON CONFLICT (auth_user_id) DO UPDATE
    SET school_id = EXCLUDED.school_id,
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Commit confirmation
SELECT 'SUCCESS: Consolidated Master Migration Configured' as status;

