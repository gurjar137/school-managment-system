-- ====================================================================
-- SUPABASE TEACHER PERSISTENCE, RECOVERY & MULTI-TENANT RLS MIGRATION
-- ====================================================================
-- Description:
-- 1. Idempotently ensures schema alignment on public.profiles and public.schools.
-- 2. Restores and hardens get_user_school_id() and get_user_role() with JWT fallback.
-- 3. Implements comprehensive, multi-tenant Row Level Security policies on public.profiles
--    allowing school administrators to view, insert, update, and manage staff/teachers in their school.
-- 4. Creates atomic SECURITY DEFINER RPC public.create_staff_profile for reliable account creation.
-- 5. Reconciles authoritative school identity and restores recoverable teacher records (including Ram).
-- ====================================================================

-- --------------------------------------------------------------------
-- STEP 1: SCHEMA ALIGNMENT ON PUBLIC.PROFILES & PUBLIC.SCHOOLS
-- --------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS employee_id text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subject text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS designation text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS assigned_class text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS assigned_section text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS must_change_password boolean DEFAULT false;

-- Create indexes for performance and multi-tenant queries
CREATE INDEX IF NOT EXISTS idx_profiles_school_id ON public.profiles (school_id);
CREATE INDEX IF NOT EXISTS idx_profiles_auth_user_id ON public.profiles (auth_user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles (role);
CREATE INDEX IF NOT EXISTS idx_profiles_school_role ON public.profiles (school_id, role);

-- --------------------------------------------------------------------
-- STEP 2: RESILIENT TENANT RESOLUTION HELPER FUNCTIONS
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_school_id uuid;
  v_jwt_school text;
BEGIN
  -- 1. Check public.profiles first
  SELECT school_id INTO v_school_id
  FROM public.profiles
  WHERE auth_user_id = auth.uid()
  LIMIT 1;

  IF v_school_id IS NOT NULL THEN
    RETURN v_school_id;
  END IF;

  -- 2. Fallback to JWT user_metadata
  BEGIN
    v_jwt_school := auth.jwt() -> 'user_metadata' ->> 'school_id';
    IF v_jwt_school IS NOT NULL AND v_jwt_school ~ '^[0-9a-fA-F-]{36}$' THEN
      RETURN v_jwt_school::uuid;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
  v_jwt_role text;
BEGIN
  -- 1. Check public.profiles first
  SELECT role INTO v_role
  FROM public.profiles
  WHERE auth_user_id = auth.uid()
  LIMIT 1;

  IF v_role IS NOT NULL AND v_role <> '' THEN
    RETURN LOWER(v_role);
  END IF;

  -- 2. Fallback to JWT user_metadata
  BEGIN
    v_jwt_role := auth.jwt() -> 'user_metadata' ->> 'role';
    IF v_jwt_role IS NOT NULL AND v_jwt_role <> '' THEN
      RETURN LOWER(v_jwt_role);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN 'user';
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated;

-- --------------------------------------------------------------------
-- STEP 3: SECURITY DEFINER RPC FOR ATOMIC STAFF PROVISIONING
-- --------------------------------------------------------------------
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
  -- Validate caller authorization
  v_caller_role := public.get_user_role();
  v_caller_school := public.get_user_school_id();

  IF v_caller_role NOT IN ('owner', 'super_admin', 'school_admin', 'principal') AND auth.uid() <> p_auth_user_id THEN
    RAISE EXCEPTION 'Unauthorized: only school administrators can provision staff profiles';
  END IF;

  IF v_caller_school IS NOT NULL AND v_caller_school <> p_school_id AND v_caller_role <> 'super_admin' THEN
    RAISE EXCEPTION 'Cross-school violation: cannot provision staff for a different school';
  END IF;

  -- Upsert profile row safely
  INSERT INTO public.profiles (
    id,
    auth_user_id,
    school_id,
    full_name,
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
    COALESCE((SELECT id FROM public.profiles WHERE auth_user_id = p_auth_user_id LIMIT 1), gen_random_uuid()),
    p_auth_user_id,
    p_school_id,
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
  ON CONFLICT (auth_user_id) DO UPDATE SET
    school_id = EXCLUDED.school_id,
    full_name = EXCLUDED.full_name,
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

GRANT EXECUTE ON FUNCTION public.create_staff_profile TO authenticated;

-- --------------------------------------------------------------------
-- STEP 4: SECURITY DEFINER RPC FOR SAFE SCHOOL LOOKUP
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

GRANT EXECUTE ON FUNCTION public.lookup_school_by_id(uuid) TO authenticated;

-- --------------------------------------------------------------------
-- STEP 5: ROW LEVEL SECURITY POLICIES ON PUBLIC.PROFILES
-- --------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Clean existing policies
DROP POLICY IF EXISTS "Public read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "School members read school profiles" ON public.profiles;
DROP POLICY IF EXISTS "School Admins view school profiles" ON public.profiles;
DROP POLICY IF EXISTS "School Admins insert staff profiles" ON public.profiles;
DROP POLICY IF EXISTS "School Admins update staff profiles" ON public.profiles;
DROP POLICY IF EXISTS "School Admins delete staff profiles" ON public.profiles;

-- 1. SELECT: Users can view their own profile, OR profiles belonging to their own school
CREATE POLICY "School members read school profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    auth_user_id = auth.uid()
    OR
    school_id = public.get_user_school_id()
    OR
    school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
);

-- 2. INSERT: Users can insert their own profile, OR School Admins can insert staff in their school
CREATE POLICY "School Admins insert staff profiles"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
    auth_user_id = auth.uid()
    OR
    (
      public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
      AND (school_id = public.get_user_school_id() OR school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid)
    )
    OR
    (
      (auth.jwt() -> 'user_metadata' ->> 'role') IN ('owner', 'super_admin', 'school_admin', 'principal')
      AND (school_id = public.get_user_school_id() OR school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid)
    )
);

-- 3. UPDATE: Users can update their own profile, OR School Admins can update staff in their school
CREATE POLICY "School Admins update staff profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
    auth_user_id = auth.uid()
    OR
    (
      public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
      AND (school_id = public.get_user_school_id() OR school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid)
    )
    OR
    (
      (auth.jwt() -> 'user_metadata' ->> 'role') IN ('owner', 'super_admin', 'school_admin', 'principal')
      AND (school_id = public.get_user_school_id() OR school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid)
    )
)
WITH CHECK (
    auth_user_id = auth.uid()
    OR
    (
      public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
      AND (school_id = public.get_user_school_id() OR school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid)
    )
    OR
    (
      (auth.jwt() -> 'user_metadata' ->> 'role') IN ('owner', 'super_admin', 'school_admin', 'principal')
      AND (school_id = public.get_user_school_id() OR school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid)
    )
);

-- 4. DELETE: School Admins can delete staff within their own school
CREATE POLICY "School Admins delete staff profiles"
ON public.profiles
FOR DELETE
TO authenticated
USING (
    public.get_user_role() IN ('owner', 'super_admin', 'school_admin', 'principal')
    AND (school_id = public.get_user_school_id() OR school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid)
);

-- --------------------------------------------------------------------
-- STEP 6: ROW LEVEL SECURITY POLICIES ON PUBLIC.SCHOOLS
-- --------------------------------------------------------------------
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read active schools" ON public.schools;
DROP POLICY IF EXISTS "Users can read own school" ON public.schools;

CREATE POLICY "Users can read own school"
ON public.schools
FOR SELECT
TO authenticated
USING (
    id = public.get_user_school_id()
    OR
    id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
    OR
    public.get_user_role() = 'super_admin'
);

-- --------------------------------------------------------------------
-- STEP 7: AUTHORITATIVE DATA RECONCILIATION & RECOVERY
-- --------------------------------------------------------------------

-- 1. Ensure Kamal Public School authoritative record exists
INSERT INTO public.schools (
  id,
  name,
  code,
  status,
  created_at,
  updated_at
) VALUES (
  '6254bee9-151d-4332-8a1c-3994af7d2153',
  'Kamal Public School',
  'KPS',
  'active',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  name = 'Kamal Public School',
  code = 'KPS',
  status = 'active';

-- 2. Ensure Admin profile exists
INSERT INTO public.profiles (
  id,
  auth_user_id,
  school_id,
  full_name,
  role,
  status,
  email,
  created_at,
  updated_at
) VALUES (
  'b773c510-a0b4-47c7-af58-145adc883ca7',
  'b773c510-a0b4-47c7-af58-145adc883ca7',
  '6254bee9-151d-4332-8a1c-3994af7d2153',
  'School Administrator',
  'school_admin',
  'active',
  'admin@school.com',
  NOW(),
  NOW()
)
ON CONFLICT (auth_user_id) DO UPDATE SET
  school_id = EXCLUDED.school_id,
  full_name = 'School Administrator',
  role = 'school_admin',
  status = 'active';

-- 3. Reconcile teacher Ram
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
  phone,
  email,
  subject,
  created_at,
  updated_at
) VALUES (
  '0c4f9640-c110-49d6-be93-4ea69cba78aa',
  '0c4f9640-c110-49d6-be93-4ea69cba78aa',
  '6254bee9-151d-4332-8a1c-3994af7d2153',
  'Ram',
  'teacher',
  'active',
  'Senior Math Faculty',
  'Class 5',
  'A',
  '9876543211',
  'ram@school.com',
  'Mathematics',
  NOW(),
  NOW()
)
ON CONFLICT (auth_user_id) DO UPDATE SET
  school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
  full_name = 'Ram',
  role = 'teacher',
  status = 'active',
  designation = 'Senior Math Faculty',
  assigned_class = 'Class 5',
  assigned_section = 'A',
  subject = 'Mathematics';

-- 4. Reconcile teacher Ramesh
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
  phone,
  email,
  subject,
  created_at,
  updated_at
) VALUES (
  '98948ef3-d3f3-4cf3-8f25-7a384e565af3',
  '98948ef3-d3f3-4cf3-8f25-7a384e565af3',
  '6254bee9-151d-4332-8a1c-3994af7d2153',
  'Ramesh',
  'teacher',
  'active',
  'Senior Physics Faculty',
  'Class 12',
  'A',
  '9876543210',
  'ramesh@school.com',
  'Physics',
  NOW(),
  NOW()
)
ON CONFLICT (auth_user_id) DO UPDATE SET
  school_id = '6254bee9-151d-4332-8a1c-3994af7d2153',
  full_name = 'Ramesh',
  role = 'teacher',
  status = 'active',
  designation = 'Senior Physics Faculty',
  assigned_class = 'Class 12',
  assigned_section = 'A',
  subject = 'Physics';
