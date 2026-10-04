-- ====================================================================
-- FINAL SECURITY HARDENING — P2 MODULES
-- ====================================================================
-- Scope: Restricts INSERT, UPDATE, DELETE permissions on P2 tables to
-- school administrators ('owner', 'super_admin', 'school_admin') while
-- preserving SELECT read access for authenticated school users.
-- Tables: parents, parent_students, library_books, transport_routes
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. PARENTS TABLE SECURITY HARDENING
-- --------------------------------------------------------------------
ALTER TABLE public.parents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School isolation for parents" ON public.parents;
DROP POLICY IF EXISTS "School access parents" ON public.parents;
DROP POLICY IF EXISTS "School users can view parents" ON public.parents;
DROP POLICY IF EXISTS "School admins can manage parents" ON public.parents;

-- SELECT: Authenticated users within the same school can view parent directory
CREATE POLICY "School users can view parents" ON public.parents 
FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

-- WRITE (INSERT, UPDATE, DELETE): Strictly restricted to school admins
CREATE POLICY "School admins can manage parents" ON public.parents 
FOR ALL TO authenticated
USING (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- --------------------------------------------------------------------
-- 2. PARENT_STUDENTS LINK TABLE SECURITY HARDENING
-- --------------------------------------------------------------------
ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view parent_students" ON public.parent_students;
DROP POLICY IF EXISTS "School admins can manage parent_students" ON public.parent_students;

-- SELECT: Authenticated users within the same school can view parent-student links
CREATE POLICY "School users can view parent_students" ON public.parent_students 
FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

-- WRITE (INSERT, UPDATE, DELETE): Strictly restricted to school admins
CREATE POLICY "School admins can manage parent_students" ON public.parent_students 
FOR ALL TO authenticated
USING (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- --------------------------------------------------------------------
-- 3. LIBRARY BOOKS TABLE SECURITY HARDENING
-- --------------------------------------------------------------------
ALTER TABLE public.library_books ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view library_books" ON public.library_books;
DROP POLICY IF EXISTS "School admins can manage library_books" ON public.library_books;

-- SELECT: Authenticated users within the same school can view library catalog
CREATE POLICY "School users can view library_books" ON public.library_books 
FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

-- WRITE (INSERT, UPDATE, DELETE): Strictly restricted to school admins
CREATE POLICY "School admins can manage library_books" ON public.library_books 
FOR ALL TO authenticated
USING (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- --------------------------------------------------------------------
-- 4. TRANSPORT ROUTES TABLE SECURITY HARDENING
-- --------------------------------------------------------------------
ALTER TABLE public.transport_routes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view transport_routes" ON public.transport_routes;
DROP POLICY IF EXISTS "School admins can manage transport_routes" ON public.transport_routes;

-- SELECT: Authenticated users within the same school can view transport routes & fleet
CREATE POLICY "School users can view transport_routes" ON public.transport_routes 
FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

-- WRITE (INSERT, UPDATE, DELETE): Strictly restricted to school admins
CREATE POLICY "School admins can manage transport_routes" ON public.transport_routes 
FOR ALL TO authenticated
USING (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id() 
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- --------------------------------------------------------------------
-- 5. RELOAD POSTGREST CACHE
-- --------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
