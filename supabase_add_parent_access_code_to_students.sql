-- ====================================================================
-- MIGRATION: ADD PARENT ACCESS CODE TO STUDENTS TABLE
-- ====================================================================

ALTER TABLE public.students
ADD COLUMN IF NOT EXISTS parent_access_code TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS students_parent_access_code_unique
ON public.students(parent_access_code)
WHERE parent_access_code IS NOT NULL;
