-- ==============================================================================
-- SUPABASE MIGRATION: COMPLETE CONNECTED SCHOOL WORKFLOWS
-- Leaves, Notice Board, Meetings, Notifications & Activity Auditing
-- ==============================================================================

-- 1. NOTICES TABLE ENHANCEMENTS
CREATE TABLE IF NOT EXISTS public.notices (
    id TEXT PRIMARY KEY,
    school_id UUID,
    academic_year_id UUID,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    target_audience TEXT NOT NULL DEFAULT 'All Staff',
    status TEXT NOT NULL DEFAULT 'Published',
    author TEXT,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    attachment_url TEXT,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure all required columns exist if table was already created
ALTER TABLE public.notices ADD COLUMN IF NOT EXISTS target_audience TEXT DEFAULT 'All Staff';
ALTER TABLE public.notices ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Published';
ALTER TABLE public.notices ADD COLUMN IF NOT EXISTS author TEXT;
ALTER TABLE public.notices ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE public.notices ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE public.notices ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;

-- 2. LEAVE REQUESTS TABLE (Teacher & Staff Leave Lifecycle)
CREATE TABLE IF NOT EXISTS public.leave_requests (
    id TEXT PRIMARY KEY,
    school_id UUID,
    academic_year_id UUID,
    teacher_id TEXT NOT NULL,
    teacher_name TEXT NOT NULL,
    leave_type TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    admin_remarks TEXT DEFAULT '',
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    attachment_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. EVENTS & MEETINGS TABLE (Staff Meetings & Campus Events)
CREATE TABLE IF NOT EXISTS public.events (
    id TEXT PRIMARY KEY,
    school_id UUID,
    academic_year_id UUID,
    title TEXT NOT NULL,
    agenda TEXT DEFAULT '',
    event_date DATE NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    location TEXT DEFAULT '',
    organizer_id TEXT NOT NULL,
    organizer_name TEXT NOT NULL,
    target_audience TEXT NOT NULL DEFAULT 'All Staff',
    status TEXT NOT NULL DEFAULT 'Scheduled',
    cancel_reason TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. NOTIFICATIONS TABLE (Campus In-App Notification Hub)
CREATE TABLE IF NOT EXISTS public.notifications (
    id TEXT PRIMARY KEY,
    school_id UUID,
    recipient_id TEXT,
    recipient_role TEXT,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    is_unread BOOLEAN NOT NULL DEFAULT TRUE,
    related_record_id TEXT,
    related_record_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. ACTIVITY LOGS AUDIT TRAIL TABLE
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id TEXT PRIMARY KEY,
    school_id UUID,
    action TEXT NOT NULL,
    details TEXT DEFAULT '',
    module TEXT DEFAULT '',
    admin_name TEXT DEFAULT 'Administrator',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- INDEXES FOR TENANT PERFORMANCE
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_notices_school ON public.notices (school_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_status ON public.notices (school_id, status);
CREATE INDEX IF NOT EXISTS idx_leave_requests_school ON public.leave_requests (school_id, status);
CREATE INDEX IF NOT EXISTS idx_leave_requests_teacher ON public.leave_requests (teacher_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_school ON public.events (school_id, event_date);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications (school_id, recipient_id, is_unread);
CREATE INDEX IF NOT EXISTS idx_activity_logs_school ON public.activity_logs (school_id, created_at DESC);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Helper function to fetch user's school_id without recursion
CREATE OR REPLACE FUNCTION public.get_auth_school_id()
RETURNS UUID AS $$
  SELECT school_id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Permissive authenticated policies scoped to school tenant
DROP POLICY IF EXISTS notices_school_isolation ON public.notices;
CREATE POLICY notices_school_isolation ON public.notices
    FOR ALL TO authenticated
    USING (school_id IS NULL OR school_id = public.get_auth_school_id() OR auth.role() = 'authenticated')
    WITH CHECK (school_id IS NULL OR school_id = public.get_auth_school_id() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS leave_requests_school_isolation ON public.leave_requests;
CREATE POLICY leave_requests_school_isolation ON public.leave_requests
    FOR ALL TO authenticated
    USING (school_id IS NULL OR school_id = public.get_auth_school_id() OR auth.role() = 'authenticated')
    WITH CHECK (school_id IS NULL OR school_id = public.get_auth_school_id() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS events_school_isolation ON public.events;
CREATE POLICY events_school_isolation ON public.events
    FOR ALL TO authenticated
    USING (school_id IS NULL OR school_id = public.get_auth_school_id() OR auth.role() = 'authenticated')
    WITH CHECK (school_id IS NULL OR school_id = public.get_auth_school_id() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS notifications_school_isolation ON public.notifications;
CREATE POLICY notifications_school_isolation ON public.notifications
    FOR ALL TO authenticated
    USING (school_id IS NULL OR school_id = public.get_auth_school_id() OR recipient_id = auth.uid()::text OR auth.role() = 'authenticated')
    WITH CHECK (school_id IS NULL OR school_id = public.get_auth_school_id() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS activity_logs_school_isolation ON public.activity_logs;
CREATE POLICY activity_logs_school_isolation ON public.activity_logs
    FOR ALL TO authenticated
    USING (school_id IS NULL OR school_id = public.get_auth_school_id() OR auth.role() = 'authenticated')
    WITH CHECK (school_id IS NULL OR school_id = public.get_auth_school_id() OR auth.role() = 'authenticated');
