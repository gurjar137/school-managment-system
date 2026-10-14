-- ==============================================================================
-- SCHOOL MANAGEMENT APP & SUPER ADMIN MIGRATION:
-- ACADEMIC YEAR AUTO-PROVISIONING, RLS PERMISSION HARDENING & MKC SEED
-- ==============================================================================

-- 1. Ensure academic_years table has proper RLS policies supporting Super Admin / Owner across all schools
-- and School Admins for their own tenant school
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School users can view own academic years" ON public.academic_years;
CREATE POLICY "School users can view own academic years"
ON public.academic_years FOR SELECT TO authenticated
USING (
    school_id = public.get_user_school_id()
    OR public.get_user_role() IN ('owner', 'super_admin')
);

DROP POLICY IF EXISTS "School admins can insert academic years" ON public.academic_years;
CREATE POLICY "School admins can insert academic years"
ON public.academic_years FOR INSERT TO authenticated
WITH CHECK (
    (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'))
    OR public.get_user_role() IN ('owner', 'super_admin')
);

DROP POLICY IF EXISTS "School admins can update academic years" ON public.academic_years;
CREATE POLICY "School admins can update academic years"
ON public.academic_years FOR UPDATE TO authenticated
USING (
    (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'))
    OR public.get_user_role() IN ('owner', 'super_admin')
);

DROP POLICY IF EXISTS "School admins can delete academic years" ON public.academic_years;
CREATE POLICY "School admins can delete academic years"
ON public.academic_years FOR DELETE TO authenticated
USING (
    (school_id = public.get_user_school_id() AND public.get_user_role() IN ('owner', 'super_admin', 'school_admin'))
    OR public.get_user_role() IN ('owner', 'super_admin')
);

-- 2. Seed MKC School (4813e425-1eb8-46df-a7d9-2efa208c7a7a) Academic Year 2026-2027
INSERT INTO public.academic_years (
    school_id,
    name,
    start_date,
    end_date,
    status,
    created_at,
    updated_at
)
SELECT 
    '4813e425-1eb8-46df-a7d9-2efa208c7a7a'::uuid,
    '2026-2027',
    '2026-04-01'::date,
    '2027-03-31'::date,
    'active',
    now(),
    now()
WHERE EXISTS (
    SELECT 1 FROM public.schools WHERE id = '4813e425-1eb8-46df-a7d9-2efa208c7a7a'::uuid
) AND NOT EXISTS (
    SELECT 1 FROM public.academic_years 
    WHERE school_id = '4813e425-1eb8-46df-a7d9-2efa208c7a7a'::uuid AND name = '2026-2027'
);

-- 3. Update provision_school_atomic so every new school automatically gets an active Academic Year initialized
CREATE OR REPLACE FUNCTION public.provision_school_atomic(
    p_school_name TEXT,
    p_school_code TEXT,
    p_school_address TEXT DEFAULT NULL,
    p_school_phone TEXT DEFAULT NULL,
    p_school_email TEXT DEFAULT NULL,
    p_school_logo_url TEXT DEFAULT NULL,
    p_school_status TEXT DEFAULT 'ACTIVE',
    p_app_name TEXT DEFAULT NULL,
    p_package_name TEXT DEFAULT NULL,
    p_app_identifier TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT '1.0.0',
    p_play_store_url TEXT DEFAULT NULL,
    p_app_status TEXT DEFAULT 'ACTIVE',
    p_admin_auth_user_id UUID DEFAULT NULL,
    p_admin_name TEXT DEFAULT NULL,
    p_admin_email TEXT DEFAULT NULL,
    p_admin_phone TEXT DEFAULT NULL,
    p_plan_name TEXT DEFAULT 'Annual School License',
    p_start_date TIMESTAMPTZ DEFAULT now(),
    p_end_date TIMESTAMPTZ DEFAULT (now() + interval '365 days'),
    p_sub_status TEXT DEFAULT 'ACTIVE',
    p_sub_notes TEXT DEFAULT NULL,
    p_billing_rate NUMERIC DEFAULT 20.00,
    p_billing_currency TEXT DEFAULT 'INR',
    p_billing_cycle TEXT DEFAULT 'MONTHLY',
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_caller_role TEXT;
    v_caller_status TEXT;
    v_school_id UUID;
    v_app_id UUID;
    v_billing_id UUID;
    v_sub_id UUID;
    v_profile_id UUID;
    v_ay_id UUID;
    v_norm_code TEXT;
    v_norm_pkg TEXT;
    v_norm_app_id TEXT;
    v_norm_admin_email TEXT;
    v_auth_email TEXT;
    v_norm_idemp_key TEXT;
    v_result JSONB;
    v_existing_payload JSONB;
    v_attempt_auth_id UUID;
BEGIN
    -- 1. Authoritative Super Admin check
    SELECT role, status INTO v_caller_role, v_caller_status
    FROM public.profiles
    WHERE auth_user_id = auth.uid()
    LIMIT 1;

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('super_admin', 'owner') OR LOWER(v_caller_status) != 'active' THEN
        RAISE EXCEPTION 'Unauthorized: Caller is not an active Super Admin or Owner';
    END IF;

    -- 2. Input Validation & Normalization
    v_norm_code := UPPER(TRIM(p_school_code));
    v_norm_pkg := NULLIF(LOWER(TRIM(p_package_name)), '');
    v_norm_app_id := NULLIF(UPPER(TRIM(p_app_identifier)), '');
    v_norm_admin_email := LOWER(TRIM(p_admin_email));
    v_norm_idemp_key := NULLIF(TRIM(p_idempotency_key), '');

    IF TRIM(p_school_name) IS NULL OR TRIM(p_school_name) = '' THEN
        RAISE EXCEPTION 'School name is required';
    END IF;

    IF v_norm_code IS NULL OR v_norm_code = '' THEN
        RAISE EXCEPTION 'School code is required';
    END IF;

    IF p_admin_auth_user_id IS NULL THEN
        RAISE EXCEPTION 'Administrator auth_user_id is required';
    END IF;

    -- 3. Idempotency Check
    IF v_norm_idemp_key IS NOT NULL THEN
        SELECT result_payload, auth_user_id INTO v_existing_payload, v_attempt_auth_id
        FROM public.school_provisioning_attempts
        WHERE idempotency_key = v_norm_idemp_key;

        IF v_existing_payload IS NOT NULL THEN
            RETURN jsonb_set(v_existing_payload, '{idempotent_replay}', 'true'::jsonb);
        END IF;

        IF v_attempt_auth_id IS NOT NULL AND v_attempt_auth_id != p_admin_auth_user_id THEN
            RAISE EXCEPTION 'Ownership mismatch: Idempotency key % belongs to auth user % but called with %',
                v_norm_idemp_key, v_attempt_auth_id, p_admin_auth_user_id USING ERRCODE = '20005';
        END IF;
    END IF;

    -- 4. Auth User Verification
    SELECT email INTO v_auth_email
    FROM auth.users
    WHERE id = p_admin_auth_user_id;

    IF v_auth_email IS NULL THEN
        RAISE EXCEPTION 'Referenced administrator auth user % does not exist in auth.users', p_admin_auth_user_id;
    END IF;

    -- 5. Conflict Checks
    IF EXISTS (SELECT 1 FROM public.schools WHERE UPPER(code) = v_norm_code) THEN
        RAISE EXCEPTION 'School code "%" already exists', v_norm_code USING ERRCODE = '23505';
    END IF;

    IF v_norm_pkg IS NOT NULL AND EXISTS (SELECT 1 FROM public.school_management_apps WHERE LOWER(package_name) = v_norm_pkg) THEN
        RAISE EXCEPTION 'App package name "%" already exists', v_norm_pkg USING ERRCODE = '23505';
    END IF;

    IF v_norm_app_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.school_management_apps WHERE UPPER(app_identifier) = v_norm_app_id) THEN
        RAISE EXCEPTION 'App identifier "%" already exists', v_norm_app_id USING ERRCODE = '23505';
    END IF;

    IF EXISTS (SELECT 1 FROM public.profiles WHERE auth_user_id = p_admin_auth_user_id) THEN
        RAISE EXCEPTION 'Administrator profile already exists for auth user %', p_admin_auth_user_id USING ERRCODE = '23505';
    END IF;

    -- 6. ATOMIC STEP 1: Insert School Institution
    INSERT INTO public.schools (
        name,
        code,
        address,
        phone,
        email,
        logo_url,
        status,
        created_at,
        updated_at
    ) VALUES (
        TRIM(p_school_name),
        v_norm_code,
        NULLIF(TRIM(p_school_address), ''),
        NULLIF(TRIM(p_school_phone), ''),
        NULLIF(LOWER(TRIM(p_school_email)), ''),
        NULLIF(TRIM(p_school_logo_url), ''),
        UPPER(COALESCE(NULLIF(TRIM(p_school_status), ''), 'ACTIVE')),
        now(),
        now()
    ) RETURNING id INTO v_school_id;

    -- 7. ATOMIC STEP 2: Insert Dedicated App
    INSERT INTO public.school_management_apps (
        school_id,
        app_name,
        package_name,
        app_identifier,
        current_version,
        play_store_url,
        status,
        created_at,
        updated_at
    ) VALUES (
        v_school_id,
        COALESCE(NULLIF(TRIM(p_app_name), ''), TRIM(p_school_name) || ' App'),
        COALESCE(NULLIF(v_norm_pkg, ''), 'com.school.app.' || LOWER(REPLACE(v_norm_code, '-', '_'))),
        COALESCE(NULLIF(v_norm_app_id, ''), REPLACE(v_norm_code, '-', '_') || '_APP'),
        COALESCE(NULLIF(TRIM(p_app_version), ''), '1.0.0'),
        NULLIF(TRIM(p_play_store_url), ''),
        UPPER(COALESCE(NULLIF(TRIM(p_app_status), ''), 'ACTIVE')),
        now(),
        now()
    ) RETURNING id INTO v_app_id;

    -- 8. ATOMIC STEP 3: Insert Default Billing Settings
    INSERT INTO public.school_billing_settings (
        school_id,
        rate_per_student,
        currency,
        billing_cycle,
        active,
        created_at,
        updated_at
    ) VALUES (
        v_school_id,
        COALESCE(p_billing_rate, 20.00),
        COALESCE(NULLIF(TRIM(p_billing_currency), ''), 'INR'),
        COALESCE(NULLIF(TRIM(p_billing_cycle), ''), 'MONTHLY'),
        true,
        now(),
        now()
    )
    ON CONFLICT (school_id) DO UPDATE
    SET rate_per_student = EXCLUDED.rate_per_student,
        currency = EXCLUDED.currency,
        billing_cycle = EXCLUDED.billing_cycle,
        updated_at = now()
    RETURNING id INTO v_billing_id;

    -- 9. ATOMIC STEP 4: Insert School App Subscription
    INSERT INTO public.school_app_subscriptions (
        school_app_id,
        plan_name,
        start_date,
        end_date,
        status,
        notes,
        created_at,
        updated_at
    ) VALUES (
        v_app_id,
        COALESCE(NULLIF(TRIM(p_plan_name), ''), 'Annual School License'),
        COALESCE(p_start_date, now()),
        COALESCE(p_end_date, now() + interval '365 days'),
        UPPER(COALESCE(NULLIF(TRIM(p_sub_status), ''), 'ACTIVE')),
        NULLIF(TRIM(p_sub_notes), ''),
        now(),
        now()
    ) RETURNING id INTO v_sub_id;

    -- 10. ATOMIC STEP 5: Insert School Administrator Profile
    INSERT INTO public.profiles (
        auth_user_id,
        school_id,
        full_name,
        email,
        phone,
        role,
        status,
        designation,
        created_at,
        updated_at
    ) VALUES (
        p_admin_auth_user_id,
        v_school_id,
        COALESCE(NULLIF(TRIM(p_admin_name), ''), 'School Administrator'),
        v_auth_email,
        NULLIF(TRIM(p_admin_phone), ''),
        'school_admin',
        'active',
        'School Administrator',
        now(),
        now()
    ) RETURNING id INTO v_profile_id;

    -- 11. ATOMIC STEP 6: Insert Default Active Academic Year (2026-2027)
    INSERT INTO public.academic_years (
        school_id,
        name,
        start_date,
        end_date,
        status,
        created_at,
        updated_at
    ) VALUES (
        v_school_id,
        '2026-2027',
        '2026-04-01'::date,
        '2027-03-31'::date,
        'active',
        now(),
        now()
    ) RETURNING id INTO v_ay_id;

    -- 12. Build Result Payload
    v_result := jsonb_build_object(
        'success', true,
        'school_id', v_school_id,
        'app_id', v_app_id,
        'school_app_id', v_app_id,
        'billing_settings_id', v_billing_id,
        'subscription_id', v_sub_id,
        'profile_id', v_profile_id,
        'academic_year_id', v_ay_id,
        'auth_user_id', p_admin_auth_user_id,
        'idempotent_replay', false
    );

    -- 13. Update Idempotency Tracking to Completed
    IF v_norm_idemp_key IS NOT NULL THEN
        UPDATE public.school_provisioning_attempts
        SET status = 'completed',
            school_id = v_school_id,
            result_payload = v_result,
            updated_at = now()
        WHERE idempotency_key = v_norm_idemp_key;
    END IF;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.provision_school_atomic FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.provision_school_atomic TO authenticated;
