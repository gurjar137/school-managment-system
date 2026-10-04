-- ====================================================================
-- TEACHER PROFILE ENHANCEMENT: ASSIGNED CLASS & SECTION (TEXT FIELDS)
-- ====================================================================

-- 1. ADD COLUMNS TO public.profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS assigned_class TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS assigned_section TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS designation TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. BACKFILL TEACHER ASSIGNMENT & DETAILS FROM auth.users METADATA
UPDATE public.profiles p
SET
    assigned_class = COALESCE(u.raw_user_meta_data->>'class', split_part(u.raw_user_meta_data->>'assigned_class', '-', 1)),
    assigned_section = COALESCE(u.raw_user_meta_data->>'section', split_part(u.raw_user_meta_data->>'assigned_class', '-', 2)),
    designation = COALESCE(u.raw_user_meta_data->>'designation', p.designation, 'Teacher'),
    phone = COALESCE(u.raw_user_meta_data->>'phone', p.phone),
    email = COALESCE(u.email, p.email)
FROM auth.users u
WHERE p.auth_user_id = u.id;

-- Clean whitespace
UPDATE public.profiles
SET 
    assigned_class = TRIM(assigned_class),
    assigned_section = TRIM(assigned_section)
WHERE assigned_class IS NOT NULL OR assigned_section IS NOT NULL;

-- 3. SECURE RPC TO UPDATE TEACHER ASSIGNMENT (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.update_teacher_assignment(
    p_teacher_id UUID,
    p_class TEXT,
    p_section TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_school_id UUID;
    v_caller_role TEXT;
    v_updated_id UUID;
BEGIN
    v_caller_role := public.get_user_role();
    v_school_id := public.get_user_school_id();

    IF v_caller_role NOT IN ('owner', 'super_admin', 'school_admin') THEN
        RAISE EXCEPTION 'Only school administrators can update teacher class assignments.';
    END IF;

    UPDATE public.profiles
    SET
        assigned_class = NULLIF(TRIM(p_class), ''),
        assigned_section = NULLIF(TRIM(p_section), ''),
        updated_at = NOW()
    WHERE (id = p_teacher_id OR auth_user_id = p_teacher_id)
      AND school_id = v_school_id
    RETURNING id INTO v_updated_id;

    IF v_updated_id IS NULL THEN
        RAISE EXCEPTION 'Teacher record not found in your school.';
    END IF;

    -- Also keep user_metadata synced if auth_user_id exists
    UPDATE auth.users u
    SET raw_user_meta_data = 
        COALESCE(u.raw_user_meta_data, '{}'::jsonb) || 
        jsonb_build_object(
            'assigned_class', CASE 
                WHEN NULLIF(TRIM(p_class), '') IS NOT NULL AND NULLIF(TRIM(p_section), '') IS NOT NULL THEN TRIM(p_class) || ' - ' || TRIM(p_section)
                ELSE COALESCE(NULLIF(TRIM(p_class), ''), NULLIF(TRIM(p_section), ''))
            END,
            'class', NULLIF(TRIM(p_class), ''),
            'section', NULLIF(TRIM(p_section), '')
        )
    FROM public.profiles p
    WHERE p.id = v_updated_id AND p.auth_user_id = u.id;

    RETURN jsonb_build_object(
        'success', true,
        'profile_id', v_updated_id,
        'assigned_class', NULLIF(TRIM(p_class), ''),
        'assigned_section', NULLIF(TRIM(p_section), '')
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_teacher_assignment(UUID, TEXT, TEXT) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
