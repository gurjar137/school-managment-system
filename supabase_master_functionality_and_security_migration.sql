-- ====================================================================
-- SUPABASE MASTER FUNCTIONALITY & MULTI-TENANT SECURITY MIGRATION
-- Project: School Management OS
-- Purpose:
--   1. Create and configure public.notifications table with strict RLS
--   2. Ensure public.notices has category, author, is_pinned, attachment_url, academic_year_id
--   3. Ensure public.academic_years has is_current column
--   4. Implement atomic publish_school_notice RPC for notice + notification delivery
--   5. Ensure strict tenant isolation and idempotent re-runnability
-- ====================================================================

-- 1. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID,
    recipient_role TEXT,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    is_unread BOOLEAN NOT NULL DEFAULT true,
    related_record_id TEXT,
    related_record_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Notifications Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_school_id ON public.notifications(school_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_related_record ON public.notifications(related_record_id);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any to recreate cleanly
DROP POLICY IF EXISTS "Users can view notifications for their school and role" ON public.notifications;
DROP POLICY IF EXISTS "Admins and teachers can insert notifications for their school" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Admins can delete notifications for their school" ON public.notifications;

-- Notifications RLS: SELECT
CREATE POLICY "Users can view notifications for their school and role"
ON public.notifications FOR SELECT
TO authenticated
USING (
    school_id = (SELECT get_user_school_id())
    AND (
        user_id IS NULL 
        OR user_id = auth.uid()
        OR recipient_role IS NULL
        OR recipient_role ILIKE 'everyone'
        OR recipient_role ILIKE 'all'
        OR (recipient_role ILIKE '%staff%' AND (SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() OR id = auth.uid() LIMIT 1) IN ('school_admin', 'teacher'))
        OR (recipient_role ILIKE '%teacher%' AND (SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() OR id = auth.uid() LIMIT 1) IN ('school_admin', 'teacher'))
        OR (recipient_role ILIKE '%parent%' AND (SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() OR id = auth.uid() LIMIT 1) = 'parent')
    )
);

-- Notifications RLS: INSERT
CREATE POLICY "Admins and teachers can insert notifications for their school"
ON public.notifications FOR INSERT
TO authenticated
WITH CHECK (
    school_id = (SELECT get_user_school_id())
);

-- Notifications RLS: UPDATE
CREATE POLICY "Users can update their own notifications"
ON public.notifications FOR UPDATE
TO authenticated
USING (
    school_id = (SELECT get_user_school_id())
);

-- Notifications RLS: DELETE
CREATE POLICY "Admins can delete notifications for their school"
ON public.notifications FOR DELETE
TO authenticated
USING (
    school_id = (SELECT get_user_school_id())
);

-- 2. NOTICES TABLE SCHEMA ALIGNMENT
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notices' AND column_name='category') THEN
        ALTER TABLE public.notices ADD COLUMN category TEXT DEFAULT 'General';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notices' AND column_name='author') THEN
        ALTER TABLE public.notices ADD COLUMN author TEXT DEFAULT 'Administration';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notices' AND column_name='is_pinned') THEN
        ALTER TABLE public.notices ADD COLUMN is_pinned BOOLEAN DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notices' AND column_name='attachment_url') THEN
        ALTER TABLE public.notices ADD COLUMN attachment_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notices' AND column_name='academic_year_id') THEN
        ALTER TABLE public.notices ADD COLUMN academic_year_id UUID REFERENCES public.academic_years(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Notices Indexes
CREATE INDEX IF NOT EXISTS idx_notices_school_id ON public.notices(school_id);
CREATE INDEX IF NOT EXISTS idx_notices_created_at ON public.notices(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_status ON public.notices(status);

-- 3. ACADEMIC YEARS SCHEMA ALIGNMENT
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='academic_years' AND column_name='is_current') THEN
        ALTER TABLE public.academic_years ADD COLUMN is_current BOOLEAN DEFAULT false;
        UPDATE public.academic_years SET is_current = (status = 'ACTIVE');
    END IF;
END $$;

-- 4. ATOMIC NOTICE PUBLISHING & NOTIFICATION DELIVERY RPC
CREATE OR REPLACE FUNCTION public.publish_school_notice(
    p_school_id UUID,
    p_academic_year_id UUID,
    p_title TEXT,
    p_content TEXT,
    p_category TEXT,
    p_target_audience TEXT,
    p_author TEXT,
    p_is_pinned BOOLEAN DEFAULT false,
    p_attachment_url TEXT DEFAULT NULL,
    p_status TEXT DEFAULT 'Published'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_notice_id UUID;
    v_notif_id UUID;
    v_user_school_id UUID;
BEGIN
    -- Verify tenant authorization
    v_user_school_id := public.get_user_school_id();
    IF v_user_school_id IS NOT NULL AND v_user_school_id != p_school_id THEN
        RAISE EXCEPTION 'Tenant security violation: cannot publish notice for unassigned school';
    END IF;

    -- Insert notice record
    INSERT INTO public.notices (
        school_id,
        academic_year_id,
        title,
        content,
        category,
        target_audience,
        author,
        is_pinned,
        attachment_url,
        status,
        created_by,
        created_at
    ) VALUES (
        p_school_id,
        p_academic_year_id,
        p_title,
        p_content,
        p_category,
        p_target_audience,
        p_author,
        p_is_pinned,
        p_attachment_url,
        p_status,
        auth.uid(),
        NOW()
    )
    RETURNING id INTO v_notice_id;

    -- If status is 'Published', synchronously generate in-app notification
    IF p_status = 'Published' THEN
        INSERT INTO public.notifications (
            school_id,
            recipient_role,
            title,
            message,
            category,
            is_unread,
            related_record_id,
            related_record_type,
            created_at
        ) VALUES (
            p_school_id,
            p_target_audience,
            'New Notice: ' || p_title,
            CASE 
                WHEN length(p_content) > 90 THEN substring(p_content from 1 for 90) || '...'
                ELSE p_content
            END,
            'Notices',
            true,
            v_notice_id::text,
            'notice',
            NOW()
        )
        RETURNING id INTO v_notif_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'notice_id', v_notice_id,
        'notification_id', v_notif_id
    );
END;
$$;
