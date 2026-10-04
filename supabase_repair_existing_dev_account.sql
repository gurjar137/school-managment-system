-- ====================================================================
-- OPTIONAL REPAIR SCRIPT FOR EXISTING DEVELOPMENT AUTH ACCOUNT ONLY
-- ====================================================================
-- Use this script ONLY if an existing development Auth user exists in auth.users
-- but does NOT have a corresponding profile in public.profiles.
-- DO NOT RUN IF ONBOARDING A NEW SCHOOL THROUGH THE APP UI.
-- ====================================================================

-- 1. Create development school entity ONLY if it doesn't already exist
INSERT INTO public.schools (id, school_code, name, address, status)
VALUES ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SCH001', 'Primary Development Campus', 'Main Road, Delhi', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- 2. Link existing Auth user to the profile if missing
DO $$
DECLARE
    v_auth_uid UUID;
BEGIN
    SELECT id INTO v_auth_uid FROM auth.users WHERE email = 'admin@school.com' LIMIT 1;
    
    IF v_auth_uid IS NOT NULL THEN
        INSERT INTO public.profiles (
            auth_user_id,
            school_id,
            school_name,
            name,
            email,
            role,
            status,
            designation
        )
        VALUES (
            v_auth_uid,
            'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'Primary Development Campus',
            'Primary School Admin',
            'admin@school.com',
            'school_admin',
            'active',
            'Primary School Administrator'
        )
        ON CONFLICT (auth_user_id) DO NOTHING;
    END IF;
END $$;
