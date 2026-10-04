-- ====================================================================
-- TIMETABLE MANAGEMENT MODULE: MIGRATION & RLS POLICIES
-- Table: public.timetable_entries
-- Description: Central Supabase table for school timetable scheduling,
-- period assignments, room allocations, conflict enforcement, and RLS.
-- Multi-tenant school isolation strictly enforced by school_id.
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. CREATE TABLE public.timetable_entries
CREATE TABLE IF NOT EXISTS public.timetable_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    academic_year_id UUID NOT NULL REFERENCES public.academic_years(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    section_id UUID REFERENCES public.sections(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday
    period_number INTEGER,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
    subject_name TEXT,
    teacher_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    teacher_name TEXT,
    room TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'PUBLISHED', 'CANCELLED')),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_timetable_time_range CHECK (end_time > start_time)
);

-- 2. CREATE INDEXES FOR FAST MULTI-TENANT QUERYING & CONFLICT DETECTION
CREATE INDEX IF NOT EXISTS idx_timetable_school_ay_class_sec_day 
    ON public.timetable_entries(school_id, academic_year_id, class_id, section_id, day_of_week);

CREATE INDEX IF NOT EXISTS idx_timetable_teacher_day 
    ON public.timetable_entries(school_id, teacher_profile_id, day_of_week) 
    WHERE teacher_profile_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_timetable_room_day 
    ON public.timetable_entries(school_id, room, day_of_week) 
    WHERE room IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_timetable_status 
    ON public.timetable_entries(school_id, status);

-- 3. ROW LEVEL SECURITY (RLS) CONFIGURATION
ALTER TABLE public.timetable_entries ENABLE ROW LEVEL SECURITY;

-- Clean up any existing policies
DROP POLICY IF EXISTS "School users can view own timetable entries" ON public.timetable_entries;
DROP POLICY IF EXISTS "School admins can insert timetable entries" ON public.timetable_entries;
DROP POLICY IF EXISTS "School admins can update timetable entries" ON public.timetable_entries;
DROP POLICY IF EXISTS "School admins can delete timetable entries" ON public.timetable_entries;

-- 3A. SELECT:
-- School Admins, Staff, Teachers, and Parents can view timetable entries of their own school.
-- (Teachers and Parents can only view PUBLISHED entries; Admins can view DRAFT, PUBLISHED, and CANCELLED)
CREATE POLICY "School users can view own timetable entries"
ON public.timetable_entries FOR SELECT TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND (
        public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
        OR status = 'PUBLISHED'
    )
);

-- 3B. INSERT: School Admins only, strictly scoped to their authenticated school_id
CREATE POLICY "School admins can insert timetable entries"
ON public.timetable_entries FOR INSERT TO authenticated
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- 3C. UPDATE: School Admins only, strictly scoped to their authenticated school_id
CREATE POLICY "School admins can update timetable entries"
ON public.timetable_entries FOR UPDATE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
)
WITH CHECK (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

-- 3D. DELETE: School Admins only, strictly scoped to their authenticated school_id
CREATE POLICY "School admins can delete timetable entries"
ON public.timetable_entries FOR DELETE TO authenticated
USING (
    school_id = public.get_user_school_id()
    AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin')
);

NOTIFY pgrst, 'reload schema';
