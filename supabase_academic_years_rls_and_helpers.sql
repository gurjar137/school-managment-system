-- ====================================================================
-- ACADEMIC YEARS: FULL CRUD RLS POLICIES & CONSTRAINTS
-- Ensures strict multi-tenant isolation by authenticated user's school_id
-- ====================================================================

ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;

-- 1. SELECT: Users can view academic years of their own school only
DROP POLICY IF EXISTS "School users can view own academic years" ON public.academic_years;
CREATE POLICY "School users can view own academic years"
ON public.academic_years FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

-- 2. INSERT: School admins can insert academic years for their own school only
DROP POLICY IF EXISTS "School admins can insert academic years" ON public.academic_years;
CREATE POLICY "School admins can insert academic years"
ON public.academic_years FOR INSERT TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- 3. UPDATE: School admins can update academic years of their own school only
DROP POLICY IF EXISTS "School admins can update academic years" ON public.academic_years;
CREATE POLICY "School admins can update academic years"
ON public.academic_years FOR UPDATE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- 4. DELETE: School admins can delete academic years of their own school only
DROP POLICY IF EXISTS "School admins can delete academic years" ON public.academic_years;
CREATE POLICY "School admins can delete academic years"
ON public.academic_years FOR DELETE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- 5. Indexes for fast date-range and tenant lookups
CREATE INDEX IF NOT EXISTS idx_academic_years_school_id ON public.academic_years(school_id);
CREATE INDEX IF NOT EXISTS idx_academic_years_dates ON public.academic_years(school_id, start_date, end_date);

-- 6. Greenwood Test School (a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11) Academic Year 2026-2027 Seed
INSERT INTO public.academic_years (school_id, name, start_date, end_date, status)
SELECT 
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid,
    '2026-2027',
    '2026-04-01'::date,
    '2027-03-31'::date,
    'ACTIVE'
WHERE NOT EXISTS (
    SELECT 1 FROM public.academic_years 
    WHERE school_id = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid AND name = '2026-2027'
);
