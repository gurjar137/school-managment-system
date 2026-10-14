-- ====================================================================
-- MASTER MIGRATION: SEED CANONICAL CLASSES, SECTIONS & HARDEN TIMETABLE RLS
-- Target School: Kamal Public School (KPS)
-- School UUID: 6254bee9-151d-4332-8a1c-3994af7d2153
-- Academic Year UUID: 47d1569b-e032-44a7-891f-b21f5458f55b (2026-2027)
-- ====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. ENSURE KPS SCHOOL AND ACADEMIC YEAR EXIST
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

-- 3. SEED 12 CANONICAL CLASSES WITH DETERMINISTIC RFC-4122 UUIDs
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

-- 4. SEED CANONICAL SECTIONS (A, B) FOR EACH CLASS
INSERT INTO public.sections (id, class_id, name, status, created_at)
VALUES 
    -- Class 1 (65='A', 66='B')
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

-- 5. REPAIR ADMIN & TEACHER PROFILES
DO $$
DECLARE
    v_admin_auth_id UUID;
BEGIN
    SELECT id INTO v_admin_auth_id 
    FROM auth.users 
    WHERE email = 'admin@school.com' 
    LIMIT 1;

    IF v_admin_auth_id IS NOT NULL THEN
        INSERT INTO public.profiles (
            id,
            auth_user_id,
            school_id,
            full_name,
            email,
            role,
            status,
            created_at,
            updated_at
        ) VALUES (
            v_admin_auth_id,
            v_admin_auth_id,
            '6254bee9-151d-4332-8a1c-3994af7d2153',
            'School Administrator',
            'admin@school.com',
            'school_admin',
            'active',
            NOW(),
            NOW()
        )
        ON CONFLICT (auth_user_id) DO UPDATE 
        SET school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
            role = 'school_admin',
            status = 'active',
            updated_at = NOW();
    END IF;
END $$;

-- 6. HARDEN ROW LEVEL SECURITY ON CLASSES & SECTIONS
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own classes" ON public.classes;
DROP POLICY IF EXISTS "School admins can manage classes" ON public.classes;

CREATE POLICY "School users can view own classes"
ON public.classes FOR SELECT TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR public.get_user_role() IN ('owner', 'super_admin')
);

CREATE POLICY "School admins can manage classes"
ON public.classes FOR ALL TO authenticated
USING (
    (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'))
)
WITH CHECK (
    (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'))
);

DROP POLICY IF EXISTS "School users can view own sections" ON public.sections;
DROP POLICY IF EXISTS "School admins can manage sections" ON public.sections;

CREATE POLICY "School users can view own sections"
ON public.sections FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.classes c
        WHERE c.id = sections.class_id
        AND (c.school_id = public.get_user_school_id() OR public.get_user_role() IN ('owner', 'super_admin'))
    )
);

CREATE POLICY "School admins can manage sections"
ON public.sections FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.classes c
        WHERE c.id = sections.class_id
        AND c.school_id = public.get_user_school_id()
        AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.classes c
        WHERE c.id = sections.class_id
        AND c.school_id = public.get_user_school_id()
        AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
    )
);

-- 7. HARDEN TIMETABLE ENTRIES RLS
ALTER TABLE public.timetable_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own timetable entries" ON public.timetable_entries;
DROP POLICY IF EXISTS "School admins can insert timetable entries" ON public.timetable_entries;
DROP POLICY IF EXISTS "School admins can update timetable entries" ON public.timetable_entries;
DROP POLICY IF EXISTS "School admins can delete timetable entries" ON public.timetable_entries;

CREATE POLICY "School users can view own timetable entries"
ON public.timetable_entries FOR SELECT TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND (
        public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
        OR status = 'PUBLISHED'
    )
);

CREATE POLICY "School admins can insert timetable entries"
ON public.timetable_entries FOR INSERT TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

CREATE POLICY "School admins can update timetable entries"
ON public.timetable_entries FOR UPDATE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

CREATE POLICY "School admins can delete timetable entries"
ON public.timetable_entries FOR DELETE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- 8. HELPER RPC: resolve_or_create_class_section
CREATE OR REPLACE FUNCTION public.resolve_or_create_class_section(
    p_school_id UUID,
    p_academic_year_id UUID,
    p_class_name TEXT,
    p_section_name TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_class_id UUID;
    v_section_id UUID;
BEGIN
    -- Resolve or insert class
    SELECT id INTO v_class_id
    FROM public.classes
    WHERE school_id = p_school_id
      AND LOWER(TRIM(name)) = LOWER(TRIM(p_class_name))
    LIMIT 1;

    IF v_class_id IS NULL THEN
        INSERT INTO public.classes (school_id, academic_year_id, name, display_order, status)
        VALUES (p_school_id, p_academic_year_id, TRIM(p_class_name), 1, 'ACTIVE')
        RETURNING id INTO v_class_id;
    END IF;

    -- Resolve or insert section
    SELECT id INTO v_section_id
    FROM public.sections
    WHERE class_id = v_class_id
      AND LOWER(TRIM(name)) = LOWER(TRIM(p_section_name))
    LIMIT 1;

    IF v_section_id IS NULL THEN
        INSERT INTO public.sections (class_id, name, status)
        VALUES (v_class_id, TRIM(p_section_name), 'ACTIVE')
        RETURNING id INTO v_section_id;
    END IF;

    RETURN jsonb_build_object(
        'class_id', v_class_id,
        'section_id', v_section_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

NOTIFY pgrst, 'reload schema';
