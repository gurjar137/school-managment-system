-- ====================================================================
-- MASTER MIGRATION: CLASSES, SECTIONS & ACADEMIC YEARS RLS SELECT POLICY FIX
-- ====================================================================
-- Description:
-- Ensures authenticated users can query `classes`, `sections`, and `academic_years`
-- belonging to their active school.
-- ====================================================================

-- SECTION 1: NON-RECURSIVE HELPER FUNCTIONS
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID AS $$
    SELECT school_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

-- SECTION 2: CLASSES RLS SELECT POLICY
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own classes" ON public.classes;
DROP POLICY IF EXISTS "Authenticated users can select classes" ON public.classes;

CREATE POLICY "School users can view own classes"
ON public.classes
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
);

-- SECTION 3: SECTIONS RLS SELECT POLICY
ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own sections" ON public.sections;
DROP POLICY IF EXISTS "Authenticated users can select sections" ON public.sections;

CREATE POLICY "School users can view own sections"
ON public.sections
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
);

-- SECTION 4: ACADEMIC YEARS RLS SELECT POLICY
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own academic years" ON public.academic_years;
DROP POLICY IF EXISTS "Authenticated users can select academic years" ON public.academic_years;

CREATE POLICY "School users can view own academic years"
ON public.academic_years
FOR SELECT
TO authenticated
USING (
    school_id = public.get_user_school_id()
);

NOTIFY pgrst, 'reload schema';
