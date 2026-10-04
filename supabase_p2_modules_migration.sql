-- ====================================================================
-- P2 MODULES PERSISTENCE MIGRATION (PARENTS, LIBRARY, TRANSPORT)
-- ====================================================================
-- School Management System — Multi-Tenant Supabase Migration
-- Module Scope:
-- 1. PARENT MANAGEMENT: Align parents schema (parent_code, linked_students_count)
--    and create parent_students link table with RLS.
-- 2. LIBRARY PERSISTENCE: Create library_books table with RLS.
-- 3. TRANSPORT PERSISTENCE: Create transport_routes table with RLS.
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------------------
-- 1. PARENTS TABLE SCHEMA ALIGNMENT
-- --------------------------------------------------------------------
ALTER TABLE public.parents ADD COLUMN IF NOT EXISTS parent_code TEXT;
ALTER TABLE public.parents ADD COLUMN IF NOT EXISTS linked_students_count INT DEFAULT 0;

-- Optional backfill of parent_code for existing parents missing a code
UPDATE public.parents
SET parent_code = 'SCH001-PAR-' || LPAD(SUBSTRING(id::text, 1, 4), 4, '0')
WHERE parent_code IS NULL OR parent_code = '';

CREATE UNIQUE INDEX IF NOT EXISTS unique_parents_school_parent_code 
ON public.parents (school_id, parent_code);

ALTER TABLE public.parents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School isolation for parents" ON public.parents;
CREATE POLICY "School isolation for parents" ON public.parents 
FOR ALL TO authenticated
USING (school_id = public.get_user_school_id());

-- --------------------------------------------------------------------
-- 2. PARENT_STUDENTS LINK TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.parent_students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    parent_id UUID NOT NULL REFERENCES public.parents(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    relationship TEXT NOT NULL DEFAULT 'FATHER',
    is_primary BOOLEAN DEFAULT FALSE,
    student_name TEXT,
    student_class TEXT,
    admission_number TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_parent_student_link UNIQUE (parent_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_parent_students_school_id ON public.parent_students(school_id);
CREATE INDEX IF NOT EXISTS idx_parent_students_parent_id ON public.parent_students(parent_id);
CREATE INDEX IF NOT EXISTS idx_parent_students_student_id ON public.parent_students(student_id);

ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view parent_students" ON public.parent_students;
CREATE POLICY "School users can view parent_students" ON public.parent_students 
FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

DROP POLICY IF EXISTS "School admins can manage parent_students" ON public.parent_students;
CREATE POLICY "School admins can manage parent_students" ON public.parent_students 
FOR ALL TO authenticated
USING (school_id = public.get_user_school_id());

-- --------------------------------------------------------------------
-- 3. LIBRARY BOOKS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.library_books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    isbn TEXT NOT NULL,
    issued_to_student TEXT,
    issue_date DATE,
    due_date DATE,
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'issued', 'overdue')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_library_books_school_id ON public.library_books(school_id);

ALTER TABLE public.library_books ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view library_books" ON public.library_books;
CREATE POLICY "School users can view library_books" ON public.library_books 
FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

DROP POLICY IF EXISTS "School admins can manage library_books" ON public.library_books;
CREATE POLICY "School admins can manage library_books" ON public.library_books 
FOR ALL TO authenticated
USING (school_id = public.get_user_school_id());

-- --------------------------------------------------------------------
-- 4. TRANSPORT ROUTES TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transport_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    route_name TEXT NOT NULL,
    bus_number TEXT NOT NULL,
    driver_name TEXT NOT NULL,
    driver_phone TEXT NOT NULL,
    student_count INT DEFAULT 0,
    stops JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transport_routes_school_id ON public.transport_routes(school_id);

ALTER TABLE public.transport_routes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view transport_routes" ON public.transport_routes;
CREATE POLICY "School users can view transport_routes" ON public.transport_routes 
FOR SELECT TO authenticated
USING (school_id = public.get_user_school_id());

DROP POLICY IF EXISTS "School admins can manage transport_routes" ON public.transport_routes;
CREATE POLICY "School admins can manage transport_routes" ON public.transport_routes 
FOR ALL TO authenticated
USING (school_id = public.get_user_school_id());

-- --------------------------------------------------------------------
-- 5. RELOAD POSTGREST CACHE
-- --------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
