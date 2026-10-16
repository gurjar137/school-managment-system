-- ====================================================================
-- SUPABASE CRITICAL MASTER REPAIR & SECURITY HARDENING MIGRATION
-- ====================================================================
-- Target Project: hnvjenkeimzkdgkuwbeb.supabase.co
-- Canonical School: 6254bee9-151d-4332-8a1c-3994af7d2153 (Kamal Public School / KPS)
-- Primary Administrator: b773c510-a0b4-47c7-af58-145adc883ca7 (admin@school.com)
--
-- Security Guarantees:
-- 1. Strictly database-verified school membership via public.profiles.
--    Zero reliance on client-editable JWT user_metadata for authorization.
-- 2. Fail-closed tenant isolation. Missing profile = NULL school_id = 0 access.
-- 3. Privilege escalation prevention trigger on public.profiles.
-- 4. Pinned search_path = public on all SECURITY DEFINER functions.
-- 5. Zero synthetic ID seeding. Preserves authentic existing records.
-- ====================================================================

-- --------------------------------------------------------------------
-- STEP 1: EXTENSIONS & COLUMN PREREQUISITES
-- --------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Ensure public.schools has required columns
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS code text;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS status text DEFAULT 'ACTIVE';
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS logo_url text;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS address text;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS email text;

-- Ensure public.profiles has required schema columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS auth_user_id uuid;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS name text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role text DEFAULT 'user';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS status text DEFAULT 'active';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS designation text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS employee_id text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subject text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS assigned_class text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS assigned_section text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS must_change_password boolean DEFAULT false;

-- Ensure public.academic_years has status and is_current
ALTER TABLE public.academic_years ADD COLUMN IF NOT EXISTS status text DEFAULT 'active';
ALTER TABLE public.academic_years ADD COLUMN IF NOT EXISTS is_current boolean DEFAULT true;
ALTER TABLE public.academic_years ADD COLUMN IF NOT EXISTS start_date date;
ALTER TABLE public.academic_years ADD COLUMN IF NOT EXISTS end_date date;

-- --------------------------------------------------------------------
-- STEP 2: RESILIENT & SECURE IDENTITY RESOLUTION FUNCTIONS
-- --------------------------------------------------------------------
-- Resolve authoritative school ID strictly from verified database profile.
-- Fails closed (returns NULL) if caller is unauthenticated or has no profile.
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_school_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT school_id INTO v_school_id
  FROM public.profiles
  WHERE auth_user_id = auth.uid() OR id = auth.uid()
  LIMIT 1;

  RETURN v_school_id;
END;
$$;

-- Resolve caller role strictly from verified database profile.
-- Defaults to 'user' (lowest privilege) if caller has no profile.
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN 'anon';
  END IF;

  SELECT role INTO v_role
  FROM public.profiles
  WHERE auth_user_id = auth.uid() OR id = auth.uid()
  LIMIT 1;

  IF v_role IS NOT NULL AND v_role <> '' THEN
    RETURN LOWER(TRIM(v_role));
  END IF;

  RETURN 'user';
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_school_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_user_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated, service_role;

-- --------------------------------------------------------------------
-- STEP 3: PRIVILEGE ESCALATION PREVENTION TRIGGER
-- --------------------------------------------------------------------
-- Ensures non-admin users cannot alter their own role, school_id, or auth_user_id.
CREATE OR REPLACE FUNCTION public.prevent_profile_privilege_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
BEGIN
  v_caller_role := public.get_user_role();

  -- If caller is not an administrator, forbid tampering with security-critical fields
  IF v_caller_role NOT IN ('owner', 'super_admin', 'school_admin', 'principal') THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Privilege escalation denied: only school administrators can modify user roles';
    END IF;
    IF NEW.school_id IS DISTINCT FROM OLD.school_id THEN
      RAISE EXCEPTION 'Tenant security violation: users cannot alter their school institution binding';
    END IF;
    IF NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id THEN
      RAISE EXCEPTION 'Identity security violation: cannot rebind authentication user identifier';
    END IF;
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_profile_privilege_escalation ON public.profiles;
CREATE TRIGGER trg_prevent_profile_privilege_escalation
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.prevent_profile_privilege_escalation();

-- --------------------------------------------------------------------
-- STEP 4: RECONCILE CANONICAL SCHOOL & ADMIN PROFILE
-- --------------------------------------------------------------------
-- Update existing Kamal Public School record safely (preserves existing data)
UPDATE public.schools
SET code = COALESCE(NULLIF(code, ''), 'KPS'),
    name = CASE WHEN name = 'KPS' OR name IS NULL THEN 'Kamal Public School' ELSE name END,
    status = 'ACTIVE'
WHERE id = '6254bee9-151d-4332-8a1c-3994af7d2153';

-- Reconcile verified administrator profile for existing Auth user admin@school.com
INSERT INTO public.profiles (
  id,
  auth_user_id,
  school_id,
  full_name,
  name,
  role,
  status,
  designation,
  email,
  created_at,
  updated_at
) VALUES (
  'b773c510-a0b4-47c7-af58-145adc883ca7',
  'b773c510-a0b4-47c7-af58-145adc883ca7',
  '6254bee9-151d-4332-8a1c-3994af7d2153',
  'School Administrator',
  'School Administrator',
  'school_admin',
  'active',
  'Principal & Lead Administrator',
  'admin@school.com',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  auth_user_id = 'b773c510-a0b4-47c7-af58-145adc883ca7',
  school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
  role = 'school_admin',
  status = 'active',
  email = 'admin@school.com',
  updated_at = NOW();

-- --------------------------------------------------------------------
-- STEP 5: AUTHORITATIVE RPCs (SCHOOL LOOKUP & STAFF PROVISIONING)
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lookup_school_by_id(target_school_id uuid)
RETURNS SETOF public.schools
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT * FROM public.schools WHERE id = target_school_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.lookup_school_by_code(p_code text)
RETURNS TABLE (
    id uuid,
    name text,
    school_code text,
    logo_url text,
    status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT s.id, s.name, s.code AS school_code, s.logo_url, s.status
    FROM public.schools s
    WHERE UPPER(TRIM(COALESCE(s.code, ''))) = UPPER(TRIM(p_code))
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.lookup_school_by_id(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_school_by_id(uuid) TO authenticated, anon;

REVOKE ALL ON FUNCTION public.lookup_school_by_code(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_school_by_code(text) TO authenticated, anon;

-- Staff provisioning RPC with strict authorization check
CREATE OR REPLACE FUNCTION public.create_staff_profile(
    p_auth_user_id uuid,
    p_school_id uuid,
    p_full_name text,
    p_role text,
    p_employee_id text DEFAULT NULL,
    p_designation text DEFAULT NULL,
    p_assigned_class text DEFAULT NULL,
    p_assigned_section text DEFAULT NULL,
    p_phone text DEFAULT NULL,
    p_email text DEFAULT NULL,
    p_subject text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
  v_caller_school uuid;
  v_profile_id uuid;
BEGIN
  v_caller_role := public.get_user_role();
  v_caller_school := public.get_user_school_id();

  -- Verify administrative authority
  IF v_caller_role NOT IN ('owner', 'super_admin', 'school_admin', 'principal') THEN
    RAISE EXCEPTION 'Unauthorized: only verified school administrators can provision staff profiles';
  END IF;

  -- Verify tenant boundary: caller can only provision staff for their own school
  IF v_caller_role <> 'super_admin' AND (v_caller_school IS NULL OR v_caller_school <> p_school_id) THEN
    RAISE EXCEPTION 'Cross-school tenant violation: cannot provision staff for an unassigned school institution';
  END IF;

  INSERT INTO public.profiles (
    id,
    auth_user_id,
    school_id,
    full_name,
    name,
    role,
    status,
    employee_id,
    designation,
    assigned_class,
    assigned_section,
    phone,
    email,
    subject,
    must_change_password,
    created_at,
    updated_at
  ) VALUES (
    COALESCE(p_auth_user_id, gen_random_uuid()),
    p_auth_user_id,
    p_school_id,
    p_full_name,
    p_full_name,
    LOWER(p_role),
    'active',
    p_employee_id,
    COALESCE(p_designation, 'Faculty Member'),
    p_assigned_class,
    p_assigned_section,
    p_phone,
    p_email,
    p_subject,
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    auth_user_id = COALESCE(EXCLUDED.auth_user_id, public.profiles.auth_user_id),
    school_id = EXCLUDED.school_id,
    full_name = EXCLUDED.full_name,
    name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    status = 'active',
    employee_id = COALESCE(EXCLUDED.employee_id, public.profiles.employee_id),
    designation = COALESCE(EXCLUDED.designation, public.profiles.designation),
    assigned_class = COALESCE(EXCLUDED.assigned_class, public.profiles.assigned_class),
    assigned_section = COALESCE(EXCLUDED.assigned_section, public.profiles.assigned_section),
    phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
    email = COALESCE(EXCLUDED.email, public.profiles.email),
    subject = COALESCE(EXCLUDED.subject, public.profiles.subject),
    updated_at = NOW()
  RETURNING id INTO v_profile_id;

  RETURN jsonb_build_object(
    'success', true,
    'profile_id', v_profile_id,
    'auth_user_id', p_auth_user_id,
    'school_id', p_school_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_staff_profile FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_staff_profile TO authenticated, service_role;

-- --------------------------------------------------------------------
-- STEP 6: HARDENED RLS POLICIES ACROSS ALL CORE TABLES
-- --------------------------------------------------------------------

-- 1. PUBLIC.SCHOOLS
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own school" ON public.schools;
DROP POLICY IF EXISTS "Admins update own school" ON public.schools;
DROP POLICY IF EXISTS "Public read schools" ON public.schools;
DROP POLICY IF EXISTS "Public insert schools" ON public.schools;
DROP POLICY IF EXISTS "Public update schools" ON public.schools;
DROP POLICY IF EXISTS "Users can read own school" ON public.schools;

CREATE POLICY "Users read own school"
ON public.schools
FOR SELECT
TO authenticated
USING (
    id = public.get_user_school_id()
    OR
    public.get_user_role() = 'super_admin'
);

CREATE POLICY "Admins update own school"
ON public.schools
FOR UPDATE
TO authenticated
USING (
    id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
)
WITH CHECK (
    id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
);

-- 2. PUBLIC.PROFILES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School members read school profiles" ON public.profiles;
DROP POLICY IF EXISTS "School Admins insert staff profiles" ON public.profiles;
DROP POLICY IF EXISTS "School Admins update staff profiles" ON public.profiles;
DROP POLICY IF EXISTS "School Admins delete staff profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

CREATE POLICY "School members read school profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    auth_user_id = auth.uid()
    OR
    id = auth.uid()
    OR
    school_id = public.get_user_school_id()
    OR
    public.get_user_role() = 'super_admin'
);

CREATE POLICY "School Admins insert staff profiles"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
    auth_user_id = auth.uid()
    OR
    (
      public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
      AND
      school_id = public.get_user_school_id()
    )
);

CREATE POLICY "School Admins update staff profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
    auth_user_id = auth.uid()
    OR
    (
      public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
      AND
      school_id = public.get_user_school_id()
    )
)
WITH CHECK (
    auth_user_id = auth.uid()
    OR
    (
      public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
      AND
      school_id = public.get_user_school_id()
    )
);

CREATE POLICY "School Admins delete staff profiles"
ON public.profiles
FOR DELETE
TO authenticated
USING (
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
    AND
    school_id = public.get_user_school_id()
);

-- 3. PUBLIC.CLASSES
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own classes" ON public.classes;
DROP POLICY IF EXISTS "School Admins insert classes" ON public.classes;
DROP POLICY IF EXISTS "School Admins update classes" ON public.classes;
DROP POLICY IF EXISTS "School Admins delete classes" ON public.classes;
DROP POLICY IF EXISTS "Authenticated users can select classes" ON public.classes;

CREATE POLICY "School users can view own classes"
ON public.classes
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR
    public.get_user_role() = 'super_admin'
);

CREATE POLICY "School Admins insert classes"
ON public.classes
FOR INSERT
TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
);

CREATE POLICY "School Admins update classes"
ON public.classes
FOR UPDATE
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
);

CREATE POLICY "School Admins delete classes"
ON public.classes
FOR DELETE
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
);

-- 4. PUBLIC.SECTIONS
ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own sections" ON public.sections;
DROP POLICY IF EXISTS "School Admins insert sections" ON public.sections;
DROP POLICY IF EXISTS "School Admins update sections" ON public.sections;
DROP POLICY IF EXISTS "School Admins delete sections" ON public.sections;
DROP POLICY IF EXISTS "Authenticated users can select sections" ON public.sections;

CREATE POLICY "School users can view own sections"
ON public.sections
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR
    public.get_user_role() = 'super_admin'
);

CREATE POLICY "School Admins insert sections"
ON public.sections
FOR INSERT
TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
);

CREATE POLICY "School Admins update sections"
ON public.sections
FOR UPDATE
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
);

CREATE POLICY "School Admins delete sections"
ON public.sections
FOR DELETE
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
);

-- 5. PUBLIC.STUDENTS
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "students_select_school_isolated" ON public.students;
DROP POLICY IF EXISTS "students_insert_school_isolated" ON public.students;
DROP POLICY IF EXISTS "students_update_school_isolated" ON public.students;
DROP POLICY IF EXISTS "students_delete_school_isolated" ON public.students;

CREATE POLICY "students_select_school_isolated"
ON public.students
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR
    public.get_user_role() = 'super_admin'
);

CREATE POLICY "students_insert_school_isolated"
ON public.students
FOR INSERT
TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal', 'teacher')
);

CREATE POLICY "students_update_school_isolated"
ON public.students
FOR UPDATE
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal', 'teacher')
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal', 'teacher')
);

CREATE POLICY "students_delete_school_isolated"
ON public.students
FOR DELETE
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
);

-- 6. PUBLIC.ACADEMIC_YEARS
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own academic years" ON public.academic_years;
DROP POLICY IF EXISTS "School admins can manage academic years" ON public.academic_years;
DROP POLICY IF EXISTS "Authenticated users can select academic years" ON public.academic_years;

CREATE POLICY "School users can view own academic years"
ON public.academic_years
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR
    public.get_user_role() = 'super_admin'
);

CREATE POLICY "School admins can manage academic years"
ON public.academic_years
FOR ALL
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
);

-- 7. PUBLIC.HOMEWORK
CREATE TABLE IF NOT EXISTS public.homework (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

CREATE POLICY "Homework viewable by school"
ON public.homework
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR
    public.get_user_role() = 'super_admin'
);

CREATE POLICY "Homework manageable by staff"
ON public.homework
FOR ALL
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal', 'teacher')
);

-- 8. PUBLIC.LIBRARY_BOOKS
CREATE TABLE IF NOT EXISTS public.library_books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    isbn TEXT,
    issued_to_student TEXT,
    issue_date DATE,
    due_date DATE,
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'issued', 'overdue')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.library_books ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view library_books" ON public.library_books;
DROP POLICY IF EXISTS "School admins can manage library_books" ON public.library_books;

CREATE POLICY "School users can view library_books"
ON public.library_books
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR
    public.get_user_role() = 'super_admin'
);

CREATE POLICY "School admins can manage library_books"
ON public.library_books
FOR ALL
TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal', 'librarian', 'teacher')
);

NOTIFY pgrst, 'reload schema';
