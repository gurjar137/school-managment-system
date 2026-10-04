-- ====================================================================
-- SEED SCRIPT: 24 TEST TEACHERS ACROSS 12 CLASSES (SECTIONS A & B)
-- ====================================================================
-- School ID: 6254bee9-151d-4332-8a1c-3994af7d2153
-- 24 deterministic test teachers (Class 1A to Class 12B)
-- ====================================================================

-- 1. Ensure School Admins can manage staff profiles under RLS
DROP POLICY IF EXISTS "School Admins insert staff profiles" ON public.profiles;
CREATE POLICY "School Admins insert staff profiles"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

DROP POLICY IF EXISTS "School Admins update staff profiles" ON public.profiles;
CREATE POLICY "School Admins update staff profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- 2. Insert 24 test teachers with deterministic UUIDs and required assignments
INSERT INTO public.profiles (
    id,
    school_id,
    full_name,
    role,
    status,
    assigned_class,
    assigned_section,
    designation,
    email,
    phone
) VALUES
('b0000001-0000-0000-0000-000000000001', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 1A', 'teacher', 'active', 'Class 1', 'A', 'Primary Educator', 'test.teacher.1a@school-test.local', '999990101A'),
('b0000001-0000-0000-0000-000000000002', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 1B', 'teacher', 'active', 'Class 1', 'B', 'Primary Educator', 'test.teacher.1b@school-test.local', '999990101B'),
('b0000001-0000-0000-0000-000000000003', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 2A', 'teacher', 'active', 'Class 2', 'A', 'Primary Educator', 'test.teacher.2a@school-test.local', '999990201A'),
('b0000001-0000-0000-0000-000000000004', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 2B', 'teacher', 'active', 'Class 2', 'B', 'Primary Educator', 'test.teacher.2b@school-test.local', '999990201B'),
('b0000001-0000-0000-0000-000000000005', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 3A', 'teacher', 'active', 'Class 3', 'A', 'Primary Educator', 'test.teacher.3a@school-test.local', '999990301A'),
('b0000001-0000-0000-0000-000000000006', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 3B', 'teacher', 'active', 'Class 3', 'B', 'Primary Educator', 'test.teacher.3b@school-test.local', '999990301B'),
('b0000001-0000-0000-0000-000000000007', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 4A', 'teacher', 'active', 'Class 4', 'A', 'Primary Educator', 'test.teacher.4a@school-test.local', '999990401A'),
('b0000001-0000-0000-0000-000000000008', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 4B', 'teacher', 'active', 'Class 4', 'B', 'Primary Educator', 'test.teacher.4b@school-test.local', '999990401B'),
('b0000001-0000-0000-0000-000000000009', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 5A', 'teacher', 'active', 'Class 5', 'A', 'Middle School Faculty', 'test.teacher.5a@school-test.local', '999990501A'),
('b0000001-0000-0000-0000-000000000010', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 5B', 'teacher', 'active', 'Class 5', 'B', 'Middle School Faculty', 'test.teacher.5b@school-test.local', '999990501B'),
('b0000001-0000-0000-0000-000000000011', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 6A', 'teacher', 'active', 'Class 6', 'A', 'Middle School Faculty', 'test.teacher.6a@school-test.local', '999990601A'),
('b0000001-0000-0000-0000-000000000012', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 6B', 'teacher', 'active', 'Class 6', 'B', 'Middle School Faculty', 'test.teacher.6b@school-test.local', '999990601B'),
('b0000001-0000-0000-0000-000000000013', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 7A', 'teacher', 'active', 'Class 7', 'A', 'Middle School Faculty', 'test.teacher.7a@school-test.local', '999990701A'),
('b0000001-0000-0000-0000-000000000014', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 7B', 'teacher', 'active', 'Class 7', 'B', 'Middle School Faculty', 'test.teacher.7b@school-test.local', '999990701B'),
('b0000001-0000-0000-0000-000000000015', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 8A', 'teacher', 'active', 'Class 8', 'A', 'Middle School Faculty', 'test.teacher.8a@school-test.local', '999990801A'),
('b0000001-0000-0000-0000-000000000016', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 8B', 'teacher', 'active', 'Class 8', 'B', 'Middle School Faculty', 'test.teacher.8b@school-test.local', '999990801B'),
('b0000001-0000-0000-0000-000000000017', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 9A', 'teacher', 'active', 'Class 9', 'A', 'Secondary Faculty', 'test.teacher.9a@school-test.local', '999990901A'),
('b0000001-0000-0000-0000-000000000018', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 9B', 'teacher', 'active', 'Class 9', 'B', 'Secondary Faculty', 'test.teacher.9b@school-test.local', '999990901B'),
('b0000001-0000-0000-0000-000000000019', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 10A', 'teacher', 'active', 'Class 10', 'A', 'Secondary Faculty', 'test.teacher.10a@school-test.local', '999991001A'),
('b0000001-0000-0000-0000-000000000020', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 10B', 'teacher', 'active', 'Class 10', 'B', 'Secondary Faculty', 'test.teacher.10b@school-test.local', '999991001B'),
('b0000001-0000-0000-0000-000000000021', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 11A', 'teacher', 'active', 'Class 11', 'A', 'Senior Secondary Faculty', 'test.teacher.11a@school-test.local', '999991101A'),
('b0000001-0000-0000-0000-000000000022', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 11B', 'teacher', 'active', 'Class 11', 'B', 'Senior Secondary Faculty', 'test.teacher.11b@school-test.local', '999991101B'),
('b0000001-0000-0000-0000-000000000023', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 12A', 'teacher', 'active', 'Class 12', 'A', 'Senior Secondary Faculty', 'test.teacher.12a@school-test.local', '999991201A'),
('b0000001-0000-0000-0000-000000000024', '6254bee9-151d-4332-8a1c-3994af7d2153', 'Test Teacher Class 12B', 'teacher', 'active', 'Class 12', 'B', 'Senior Secondary Faculty', 'test.teacher.12b@school-test.local', '999991201B')
ON CONFLICT (id) DO UPDATE SET
    assigned_class = EXCLUDED.assigned_class,
    assigned_section = EXCLUDED.assigned_section,
    role = EXCLUDED.role,
    status = EXCLUDED.status,
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email;
