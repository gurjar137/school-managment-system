-- ============================================================================
-- SCHOOL FEE MANAGEMENT MODULE: COMPLETE MIGRATION
-- ============================================================================

-- 1. SEQUENCES & RECEIPTS
CREATE SEQUENCE IF NOT EXISTS fee_receipt_seq START 1;

-- 2. FEE STRUCTURES TABLE
CREATE TABLE IF NOT EXISTS fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES academic_years(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT,
    class_name TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. FEE COMPONENTS TABLE
CREATE TABLE IF NOT EXISTS fee_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_structure_id UUID NOT NULL REFERENCES fee_structures(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    frequency TEXT NOT NULL DEFAULT 'yearly' CHECK (frequency IN ('one_time', 'monthly', 'quarterly', 'half_yearly', 'yearly')),
    due_day INT DEFAULT 10,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. STUDENT FEE ASSIGNMENTS TABLE
CREATE TABLE IF NOT EXISTS student_fee_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES academic_years(id) ON DELETE SET NULL,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    fee_structure_id UUID NOT NULL REFERENCES fee_structures(id) ON DELETE CASCADE,
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (discount_amount >= 0),
    discount_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(student_id, fee_structure_id, academic_year_id)
);

-- 5. STUDENT FEE LEDGER TABLE
CREATE TABLE IF NOT EXISTS student_fee_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES academic_years(id) ON DELETE SET NULL,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    fee_structure_id UUID REFERENCES fee_structures(id) ON DELETE SET NULL,
    fee_component_id UUID REFERENCES fee_components(id) ON DELETE SET NULL,
    component_name TEXT NOT NULL,
    billing_period TEXT,
    due_date DATE NOT NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (discount_amount >= 0),
    paid_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (paid_amount >= 0),
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PARTIAL', 'PAID', 'OVERDUE', 'WAIVED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. FEE PAYMENTS & AUDIT TABLE
CREATE TABLE IF NOT EXISTS fee_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    academic_year_id UUID REFERENCES academic_years(id) ON DELETE SET NULL,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    receipt_number TEXT NOT NULL UNIQUE,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'upi', 'bank_transfer', 'card', 'cheque', 'other')),
    transaction_reference TEXT,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Payment Allocations to Ledger entries
CREATE TABLE IF NOT EXISTS fee_payment_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES fee_payments(id) ON DELETE CASCADE,
    ledger_id UUID NOT NULL REFERENCES student_fee_ledger(id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_fee_structures_school ON fee_structures(school_id, class_name);
CREATE INDEX IF NOT EXISTS idx_fee_components_structure ON fee_components(fee_structure_id);
CREATE INDEX IF NOT EXISTS idx_fee_assignments_student ON student_fee_assignments(student_id);
CREATE INDEX IF NOT EXISTS idx_fee_ledger_student ON student_fee_ledger(school_id, student_id, status);
CREATE INDEX IF NOT EXISTS idx_fee_payments_student ON fee_payments(school_id, student_id, payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_fee_payments_receipt ON fee_payments(receipt_number);

-- 8. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE fee_structures ENABLE ROW LEVEL SECURITY;
ALTER TABLE fee_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_fee_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_fee_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE fee_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fee_payment_allocations ENABLE ROW LEVEL SECURITY;

-- Fee Structures & Components: Admins manage, authenticated users read
DROP POLICY IF EXISTS "admin_all_fee_structures" ON fee_structures;
CREATE POLICY "admin_all_fee_structures" ON fee_structures
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'))
    WITH CHECK (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'));

DROP POLICY IF EXISTS "users_read_fee_structures" ON fee_structures;
CREATE POLICY "users_read_fee_structures" ON fee_structures
    FOR SELECT TO authenticated
    USING (school_id = get_user_school_id());

DROP POLICY IF EXISTS "admin_all_fee_components" ON fee_components;
CREATE POLICY "admin_all_fee_components" ON fee_components
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'))
    WITH CHECK (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'));

DROP POLICY IF EXISTS "users_read_fee_components" ON fee_components;
CREATE POLICY "users_read_fee_components" ON fee_components
    FOR SELECT TO authenticated
    USING (school_id = get_user_school_id());

-- Fee Assignments: Admin full access
DROP POLICY IF EXISTS "admin_all_fee_assignments" ON student_fee_assignments;
CREATE POLICY "admin_all_fee_assignments" ON student_fee_assignments
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'))
    WITH CHECK (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'));

-- Fee Ledger: Admin full access, Parents view own child's ledger
DROP POLICY IF EXISTS "admin_all_fee_ledger" ON student_fee_ledger;
CREATE POLICY "admin_all_fee_ledger" ON student_fee_ledger
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'))
    WITH CHECK (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'));

DROP POLICY IF EXISTS "parent_read_fee_ledger" ON student_fee_ledger;
CREATE POLICY "parent_read_fee_ledger" ON student_fee_ledger
    FOR SELECT TO authenticated
    USING (
        student_id IN (
            SELECT id FROM students
            WHERE parent_phone = (SELECT phone FROM profiles WHERE id = auth.uid())
               OR parent_id = auth.uid()
        )
    );

-- Fee Payments: Admin full access, Parents view own child's payments
DROP POLICY IF EXISTS "admin_all_fee_payments" ON fee_payments;
CREATE POLICY "admin_all_fee_payments" ON fee_payments
    FOR ALL TO authenticated
    USING (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'))
    WITH CHECK (school_id = get_user_school_id() AND get_user_role() IN ('owner', 'super_admin', 'school_admin'));

DROP POLICY IF EXISTS "parent_read_fee_payments" ON fee_payments;
CREATE POLICY "parent_read_fee_payments" ON fee_payments
    FOR SELECT TO authenticated
    USING (
        student_id IN (
            SELECT id FROM students
            WHERE parent_phone = (SELECT phone FROM profiles WHERE id = auth.uid())
               OR parent_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "admin_all_fee_payment_allocations" ON fee_payment_allocations;
CREATE POLICY "admin_all_fee_payment_allocations" ON fee_payment_allocations
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM fee_payments p
            WHERE p.id = payment_id
              AND p.school_id = get_user_school_id()
              AND get_user_role() IN ('owner', 'super_admin', 'school_admin')
        )
    );

-- 9. ATOMIC STORED PROCEDURES (RPC)

-- Function to assign a fee structure to all students in a class or an individual student
CREATE OR REPLACE FUNCTION assign_fee_structure(
    p_school_id UUID,
    p_academic_year_id UUID,
    p_fee_structure_id UUID,
    p_class_name TEXT DEFAULT NULL,
    p_student_id UUID DEFAULT NULL,
    p_discount_amount NUMERIC DEFAULT 0.00,
    p_discount_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student RECORD;
    v_component RECORD;
    v_assigned_count INT := 0;
    v_total_structure_amount NUMERIC := 0;
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_total_structure_amount
    FROM fee_components
    WHERE fee_structure_id = p_fee_structure_id;

    FOR v_student IN
        SELECT id, name, class_name, total_fee, paid_fee, pending_fee
        FROM students
        WHERE school_id = p_school_id
          AND (p_student_id IS NULL OR id = p_student_id)
          AND (p_class_name IS NULL OR class_name = p_class_name)
    LOOP
        INSERT INTO student_fee_assignments (
            school_id, academic_year_id, student_id, fee_structure_id,
            discount_amount, discount_reason
        )
        VALUES (
            p_school_id, p_academic_year_id, v_student.id, p_fee_structure_id,
            p_discount_amount, p_discount_reason
        )
        ON CONFLICT (student_id, fee_structure_id, academic_year_id) DO NOTHING;

        FOR v_component IN
            SELECT id, name, amount, frequency, due_day
            FROM fee_components
            WHERE fee_structure_id = p_fee_structure_id
        LOOP
            INSERT INTO student_fee_ledger (
                school_id, academic_year_id, student_id, fee_structure_id,
                fee_component_id, component_name, billing_period, due_date,
                amount, discount_amount, paid_amount, status
            )
            VALUES (
                p_school_id, p_academic_year_id, v_student.id, p_fee_structure_id,
                v_component.id, v_component.name,
                TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || v_component.frequency,
                CURRENT_DATE + INTERVAL '1 month',
                v_component.amount, 0, 0, 'PENDING'
            );
        END LOOP;

        UPDATE students
        SET total_fee = COALESCE(total_fee, 0) + (v_total_structure_amount - p_discount_amount),
            pending_fee = (COALESCE(total_fee, 0) + (v_total_structure_amount - p_discount_amount)) - COALESCE(paid_fee, 0),
            fee_status = CASE 
                WHEN COALESCE(paid_fee, 0) >= (COALESCE(total_fee, 0) + (v_total_structure_amount - p_discount_amount)) THEN 'paid'
                WHEN COALESCE(paid_fee, 0) > 0 THEN 'partial'
                ELSE 'pending'
            END
        WHERE id = v_student.id;

        v_assigned_count := v_assigned_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'assigned_count', v_assigned_count,
        'structure_amount', v_total_structure_amount
    );
END;
$$;

-- Atomic Payment Collection Procedure
CREATE OR REPLACE FUNCTION collect_student_fee_payment(
    p_school_id UUID,
    p_academic_year_id UUID,
    p_student_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_transaction_reference TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_receipt_number TEXT;
    v_payment_id UUID;
    v_remaining NUMERIC := p_amount;
    v_ledger RECORD;
    v_to_apply NUMERIC;
    v_student_name TEXT;
    v_class_name TEXT;
    v_new_paid NUMERIC;
    v_new_pending NUMERIC;
    v_new_status TEXT;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero';
    END IF;

    v_receipt_number := 'REC-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || LPAD(nextval('fee_receipt_seq')::TEXT, 6, '0');

    SELECT name, class_name INTO v_student_name, v_class_name
    FROM students
    WHERE id = p_student_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student not found in this school';
    END IF;

    INSERT INTO fee_payments (
        school_id, academic_year_id, student_id, receipt_number,
        amount, payment_date, payment_method, transaction_reference,
        notes, created_by
    )
    VALUES (
        p_school_id, p_academic_year_id, p_student_id, v_receipt_number,
        p_amount, CURRENT_DATE, p_payment_method, p_transaction_reference,
        p_notes, p_created_by
    )
    RETURNING id INTO v_payment_id;

    FOR v_ledger IN
        SELECT id, amount, discount_amount, paid_amount,
               (amount - discount_amount - paid_amount) AS outstanding
        FROM student_fee_ledger
        WHERE student_id = p_student_id
          AND school_id = p_school_id
          AND status IN ('PENDING', 'PARTIAL', 'OVERDUE')
        ORDER BY due_date ASC, created_at ASC
    LOOP
        IF v_remaining <= 0 THEN
            EXIT;
        END IF;

        IF v_ledger.outstanding > 0 THEN
            v_to_apply := LEAST(v_remaining, v_ledger.outstanding);
            
            INSERT INTO fee_payment_allocations (payment_id, ledger_id, amount)
            VALUES (v_payment_id, v_ledger.id, v_to_apply);

            UPDATE student_fee_ledger
            SET paid_amount = paid_amount + v_to_apply,
                status = CASE 
                    WHEN (paid_amount + v_to_apply) >= (amount - discount_amount) THEN 'PAID'
                    ELSE 'PARTIAL'
                END,
                updated_at = now()
            WHERE id = v_ledger.id;

            v_remaining := v_remaining - v_to_apply;
        END IF;
    END LOOP;

    UPDATE students
    SET paid_fee = COALESCE(paid_fee, 0) + p_amount,
        pending_fee = GREATEST(0, COALESCE(total_fee, 0) - (COALESCE(paid_fee, 0) + p_amount)),
        fee_status = CASE 
            WHEN (COALESCE(paid_fee, 0) + p_amount) >= COALESCE(total_fee, 0) AND COALESCE(total_fee, 0) > 0 THEN 'paid'
            WHEN (COALESCE(paid_fee, 0) + p_amount) > 0 THEN 'partial'
            ELSE 'pending'
        END
    WHERE id = p_student_id
    RETURNING paid_fee, pending_fee, fee_status INTO v_new_paid, v_new_pending, v_new_status;

    RETURN jsonb_build_object(
        'success', true,
        'payment_id', v_payment_id,
        'receipt_number', v_receipt_number,
        'student_id', p_student_id,
        'student_name', v_student_name,
        'class_name', v_class_name,
        'amount', p_amount,
        'payment_method', p_payment_method,
        'payment_date', CURRENT_DATE,
        'paid_fee', v_new_paid,
        'pending_fee', v_new_pending,
        'fee_status', v_new_status
    );
END;
$$;
