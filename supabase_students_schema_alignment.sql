-- ====================================================================
-- MASTER MIGRATION: PUBLIC.STUDENTS SCHEMA ALIGNMENT & EXTENDED FIELDS
-- ====================================================================
-- Description:
-- Safely adds missing optional columns to `public.students` table without
-- breaking existing student records or RLS policies.
-- ====================================================================

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS blood_group TEXT,
  ADD COLUMN IF NOT EXISTS father_name TEXT,
  ADD COLUMN IF NOT EXISTS father_mobile TEXT,
  ADD COLUMN IF NOT EXISTS mother_name TEXT,
  ADD COLUMN IF NOT EXISTS mother_mobile TEXT,
  ADD COLUMN IF NOT EXISTS guardian_name TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact TEXT,
  ADD COLUMN IF NOT EXISTS parent_email TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS postal_code TEXT,
  ADD COLUMN IF NOT EXISTS medical_notes TEXT,
  ADD COLUMN IF NOT EXISTS important_notes TEXT,
  ADD COLUMN IF NOT EXISTS student_code TEXT;

-- Notify PostgREST to refresh schema cache
NOTIFY pgrst, 'reload schema';
