-- ==============================================================================
-- CLEAN OPERATIONAL DEMO/TEST DATA RESET
-- Preserves: schools, admin accounts, profiles, auth, classes, sections, academic years, schema, RLS.
-- Cleans: students, teachers, attendance, fees, payroll, exams, homework, notices.
-- ==============================================================================

DO $$
BEGIN
    -- 1. DELETE STUDENT ATTENDANCE & LEAVES
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'attendances') THEN
        DELETE FROM public.attendances;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'student_attendance') THEN
        DELETE FROM public.student_attendance;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'attendance') THEN
        DELETE FROM public.attendance;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'leave_requests') THEN
        DELETE FROM public.leave_requests;
    END IF;

    -- 2. DELETE EXAMS & RESULTS
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'exam_results') THEN
        DELETE FROM public.exam_results;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'results') THEN
        DELETE FROM public.results;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'exams') THEN
        DELETE FROM public.exams;
    END IF;

    -- 3. DELETE HOMEWORK
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'homework_submissions') THEN
        DELETE FROM public.homework_submissions;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'homework') THEN
        DELETE FROM public.homework;
    END IF;

    -- 4. DELETE FEES & PAYMENTS
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'fee_payments') THEN
        DELETE FROM public.fee_payments;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'student_fees') THEN
        DELETE FROM public.student_fees;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'fee_records') THEN
        DELETE FROM public.fee_records;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'student_fee_plans') THEN
        DELETE FROM public.student_fee_plans;
    END IF;

    -- 5. DELETE SALARY & PAYROLL
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salary_payments') THEN
        DELETE FROM public.salary_payments;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salary_records') THEN
        DELETE FROM public.salary_records;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'teacher_salaries') THEN
        DELETE FROM public.teacher_salaries;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salaries') THEN
        DELETE FROM public.salaries;
    END IF;

    -- 6. DELETE PARENT-STUDENT LINKAGES
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'parent_students') THEN
        DELETE FROM public.parent_students;
    END IF;

    -- 7. DELETE OPERATIONAL NOTICES & COMMUNICATIONS
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notices') THEN
        DELETE FROM public.notices;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        DELETE FROM public.notifications;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'activity_logs') THEN
        DELETE FROM public.activity_logs;
    END IF;

    -- 8. DELETE ALL DEMO/TEST STUDENTS
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'students') THEN
        DELETE FROM public.students;
    END IF;

    -- 9. DELETE ALL DEMO/TEST TEACHERS (PRESERVING ADMIN USERS AND ADMIN PROFILES)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'teacher_attendance') THEN
        DELETE FROM public.teacher_attendance;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'teacher_assignments') THEN
        DELETE FROM public.teacher_assignments;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'teachers') THEN
        DELETE FROM public.teachers;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
        -- Only delete teacher or demo profiles, never delete admin/school_admin profiles
        DELETE FROM public.profiles 
        WHERE role ILIKE '%teacher%' OR role ILIKE '%demo%';
    END IF;

END $$;
