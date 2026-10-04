-- ====================================================================
-- MASTER CLEANUP SCRIPT: 10,000 TEST STUDENTS, TEST FEES & TEST TEACHERS
-- ====================================================================
-- NOTE: DO NOT EXECUTE THIS SCRIPT UNTIL YOU WISH TO PURGE THE TEST DATASET.
-- This script is completely safe, idempotent, and specifically scoped.
-- It deletes ONLY records matching deterministic test identifiers:
--   - Students with admission_number LIKE 'TEST-ADM-%'
--   - Fee accounts linked to test students or matching the test fee pattern
--   - Test teachers with email LIKE '%@school-test.local%'
--
-- Genuine production data is 100% preserved.
-- ====================================================================

BEGIN;

-- 1. Safely remove test fee payments (if any were created during testing)
DELETE FROM public.fee_payments
WHERE student_id IN (
    SELECT id FROM public.students
    WHERE school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'
    AND admission_number LIKE 'TEST-ADM-%'
);

-- 2. Safely remove test fee accounts (10,000 accounts)
DELETE FROM public.student_fee_accounts
WHERE school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'
AND (
    student_id IN (
        SELECT id FROM public.students
        WHERE school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'
        AND admission_number LIKE 'TEST-ADM-%'
    )
    OR id::text LIKE '00000000-0000-4000-9000-%'
);

-- 3. Safely remove test parent linkages (if any parents were linked to test students)
DELETE FROM public.parent_students
WHERE student_id IN (
    SELECT id FROM public.students
    WHERE school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'
    AND admission_number LIKE 'TEST-ADM-%'
);

-- 4. Safely remove test attendance rows (if attendance was recorded for test students)
DELETE FROM public.attendance
WHERE student_id IN (
    SELECT id FROM public.students
    WHERE school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'
    AND admission_number LIKE 'TEST-ADM-%'
);

-- 5. Safely remove the 10,000 test students
DELETE FROM public.students
WHERE school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'
AND admission_number LIKE 'TEST-ADM-%';

-- 6. Safely remove test teacher profiles (if any were created)
DELETE FROM public.profiles
WHERE school_id = '6254bee9-151d-4332-8a1c-3994af7d2153'
AND (
    email LIKE '%@school-test.local%'
    OR full_name LIKE 'Test Teacher%'
);

COMMIT;
