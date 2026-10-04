-- ====================================================================
-- MASTER MIGRATION: SECURE SERVER-SIDE STUDENT REGISTRATION RPC
-- ====================================================================
-- Description:
-- Moves Class UUID and Section UUID resolution completely server-side
-- to guarantee foreign key integrity without relying on client IDs.
-- ====================================================================

CREATE OR REPLACE FUNCTION public.create_student_securely(
    p_school_id UUID,
    p_academic_year_id UUID,
    p_class_name TEXT,
    p_section_name TEXT,
    p_name TEXT,
    p_admission_number TEXT,
    p_roll_number TEXT DEFAULT NULL,
    p_gender TEXT DEFAULT 'Male',
    p_date_of_birth DATE DEFAULT NULL,
    p_father_name TEXT DEFAULT NULL,
    p_father_mobile TEXT DEFAULT NULL,
    p_mother_name TEXT DEFAULT NULL,
    p_mother_mobile TEXT DEFAULT NULL,
    p_guardian_name TEXT DEFAULT NULL,
    p_emergency_contact TEXT DEFAULT NULL,
    p_parent_email TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_state TEXT DEFAULT NULL,
    p_pin_code TEXT DEFAULT NULL,
    p_blood_group TEXT DEFAULT 'O+',
    p_medical_notes TEXT DEFAULT NULL,
    p_important_notes TEXT DEFAULT NULL,
    p_status TEXT DEFAULT 'active'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_auth_uid UUID;
    v_caller_school_id UUID;
    v_caller_role TEXT;
    v_class_id UUID;
    v_section_id UUID;
    v_section_class_id UUID;
    v_inserted_record RECORD;
    v_final_class_name TEXT;
    v_final_section_name TEXT;
    v_final_adm_no TEXT;
    v_student_code TEXT;
BEGIN
    -- 1. Security & Authentication Check
    v_caller_auth_uid := auth.uid();
    IF v_caller_auth_uid IS NOT NULL THEN
        SELECT school_id, role INTO v_caller_school_id, v_caller_role
        FROM public.profiles
        WHERE auth_user_id = v_caller_auth_uid
        LIMIT 1;

        IF v_caller_school_id IS NOT NULL AND v_caller_school_id != p_school_id THEN
            RAISE EXCEPTION 'Unauthorized: You do not belong to this school.';
        END IF;

        IF v_caller_role IS NOT NULL AND v_caller_role NOT IN ('owner', 'super_admin', 'school_admin', 'staff', 'teacher') THEN
            RAISE EXCEPTION 'Unauthorized: Insufficient permissions to add a student.';
        END IF;
    END IF;

    -- Format class / section display names
    v_final_class_name := TRIM(p_class_name);
    v_final_section_name := TRIM(p_section_name);

    -- 2. Resolve Class UUID
    SELECT id INTO v_class_id
    FROM public.classes
    WHERE school_id = p_school_id
      AND (academic_year_id = p_academic_year_id OR academic_year_id IS NULL)
      AND (LOWER(TRIM(name)) = LOWER(v_final_class_name) OR LOWER(TRIM(name)) = LOWER(REPLACE(v_final_class_name, 'Class ', '')))
    ORDER BY display_order ASC
    LIMIT 1;

    IF v_class_id IS NULL THEN
        SELECT id INTO v_class_id
        FROM public.classes
        WHERE school_id = p_school_id
          AND (LOWER(TRIM(name)) = LOWER(v_final_class_name) OR LOWER(TRIM(name)) = LOWER(REPLACE(v_final_class_name, 'Class ', '')))
        ORDER BY display_order ASC
        LIMIT 1;
    END IF;

    IF v_class_id IS NULL THEN
        INSERT INTO public.classes (
            school_id,
            academic_year_id,
            name,
            code,
            display_order
        )
        VALUES (
            p_school_id,
            p_academic_year_id,
            v_final_class_name,
            'CLS-' || UPPER(SUBSTRING(MD5(v_final_class_name) FROM 1 FOR 4)),
            COALESCE((SELECT MAX(display_order) + 1 FROM public.classes WHERE school_id = p_school_id), 1)
        )
        RETURNING id INTO v_class_id;
    END IF;

    IF v_class_id IS NULL THEN
        RAISE EXCEPTION 'Class "%" not found for the current school and academic year', p_class_name;
    END IF;

    -- 3. Resolve Section UUID
    SELECT id, class_id INTO v_section_id, v_section_class_id
    FROM public.sections
    WHERE school_id = p_school_id
      AND class_id = v_class_id
      AND (LOWER(TRIM(name)) = LOWER(v_final_section_name) OR LOWER(TRIM(name)) = LOWER(REPLACE(v_final_section_name, 'Section ', '')))
    LIMIT 1;

    IF v_section_id IS NULL THEN
        INSERT INTO public.sections (
            school_id,
            class_id,
            name
        )
        VALUES (
            p_school_id,
            v_class_id,
            v_final_section_name
        )
        RETURNING id, class_id INTO v_section_id, v_section_class_id;
    END IF;

    IF v_section_id IS NULL THEN
        RAISE EXCEPTION 'Section "%" not found for selected class', p_section_name;
    END IF;

    -- 4. Verify section belongs to class
    IF v_section_class_id != v_class_id THEN
        RAISE EXCEPTION 'Section does not belong to selected class.';
    END IF;

    -- 5. Format Admission Number & Student Code
    v_final_adm_no := TRIM(p_admission_number);
    IF v_final_adm_no IS NULL OR v_final_adm_no = '' THEN
        v_final_adm_no := 'STU-2026-' || LPAD(FLOOR(RANDOM() * 90000 + 10000)::TEXT, 5, '0');
    END IF;
    v_student_code := v_final_adm_no;

    -- 6. Insert into public.students using authoritative UUIDs
    INSERT INTO public.students (
        school_id,
        academic_year_id,
        class_id,
        section_id,
        student_code,
        admission_number,
        roll_number,
        name,
        class_name,
        section,
        gender,
        date_of_birth,
        father_name,
        father_mobile,
        mother_name,
        mother_mobile,
        guardian_name,
        emergency_contact,
        parent_email,
        address,
        city,
        state,
        pin_code,
        blood_group,
        medical_notes,
        important_notes,
        status
    )
    VALUES (
        p_school_id,
        p_academic_year_id,
        v_class_id,
        v_section_id,
        v_student_code,
        v_final_adm_no,
        p_roll_number,
        p_name,
        v_final_class_name,
        v_final_section_name,
        p_gender,
        p_date_of_birth,
        p_father_name,
        p_father_mobile,
        p_mother_name,
        p_mother_mobile,
        p_guardian_name,
        p_emergency_contact,
        p_parent_email,
        p_address,
        p_city,
        p_state,
        p_pin_code,
        p_blood_group,
        p_medical_notes,
        p_important_notes,
        LOWER(COALESCE(p_status, 'active'))
    )
    RETURNING * INTO v_inserted_record;

    -- 7. Return inserted student object
    RETURN jsonb_build_object(
        'id', v_inserted_record.id,
        'school_id', v_inserted_record.school_id,
        'academic_year_id', v_inserted_record.academic_year_id,
        'class_id', v_inserted_record.class_id,
        'section_id', v_inserted_record.section_id,
        'student_code', v_inserted_record.student_code,
        'admission_number', v_inserted_record.admission_number,
        'roll_number', v_inserted_record.roll_number,
        'name', v_inserted_record.name,
        'class_name', v_inserted_record.class_name,
        'section', v_inserted_record.section,
        'gender', v_inserted_record.gender,
        'date_of_birth', v_inserted_record.date_of_birth,
        'father_name', v_inserted_record.father_name,
        'father_mobile', v_inserted_record.father_mobile,
        'mother_name', v_inserted_record.mother_name,
        'mother_mobile', v_inserted_record.mother_mobile,
        'guardian_name', v_inserted_record.guardian_name,
        'emergency_contact', v_inserted_record.emergency_contact,
        'parent_email', v_inserted_record.parent_email,
        'address', v_inserted_record.address,
        'city', v_inserted_record.city,
        'state', v_inserted_record.state,
        'pin_code', v_inserted_record.pin_code,
        'blood_group', v_inserted_record.blood_group,
        'status', v_inserted_record.status
    );
END;
$$;

REVOKE ALL ON FUNCTION public.create_student_securely FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_student_securely TO authenticated;

NOTIFY pgrst, 'reload schema';
