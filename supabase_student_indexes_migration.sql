-- ====================================================================
-- MIGRATION: CRITICAL PERFORMANCE INDEXES FOR 10,000+ STUDENT SCALE
-- ====================================================================
-- Description:
-- Adds high-performance composite indexes on public.students to optimize:
-- 1. Class & Section queries/filtering scoped to a school.
-- 2. Fast single-row and prefix lookups on admission numbers per school.
-- ====================================================================

-- 1. Composite index for class & section filtering per school
CREATE INDEX IF NOT EXISTS idx_students_school_class_section
ON public.students (school_id, class_name, section_name);

-- 2. Composite index for instant admission number lookups per school
CREATE INDEX IF NOT EXISTS idx_students_school_admission_number
ON public.students (school_id, admission_number);
