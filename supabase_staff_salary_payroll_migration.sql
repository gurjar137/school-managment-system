-- ==============================================================================
-- SUPABASE MIGRATION: STAFF SALARY MANAGEMENT, MONTHLY PAYROLL & PAYMENTS
-- Authoritative, idempotent schema for Central School SaaS Platform
-- ==============================================================================

-- 1. Create table: salary_structures
CREATE TABLE IF NOT EXISTS public.salary_structures (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL,
    staff_profile_id TEXT NOT NULL,
    staff_name TEXT NOT NULL,
    salary_type TEXT NOT NULL DEFAULT 'Monthly' CHECK (salary_type IN ('Monthly', 'Contractual', 'Hourly', 'Daily')),
    basic_salary NUMERIC(12, 2) NOT NULL DEFAULT 0.0 CHECK (basic_salary >= 0),
    allowances JSONB NOT NULL DEFAULT '[]'::jsonb,
    deductions JSONB NOT NULL DEFAULT '[]'::jsonb,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_schedule TEXT NOT NULL DEFAULT 'Monthly (1st)',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_salary_structures_school_staff UNIQUE (school_id, staff_profile_id)
);

-- 2. Create table: monthly_payrolls
CREATE TABLE IF NOT EXISTS public.monthly_payrolls (
    id TEXT PRIMARY KEY,
    school_id TEXT NOT NULL,
    staff_profile_id TEXT NOT NULL,
    staff_name TEXT NOT NULL,
    employee_id TEXT NOT NULL DEFAULT '',
    designation TEXT NOT NULL DEFAULT '',
    department TEXT NOT NULL DEFAULT '',
    month_year TEXT NOT NULL,
    basic_salary NUMERIC(12, 2) NOT NULL DEFAULT 0.0 CHECK (basic_salary >= 0),
    allowances JSONB NOT NULL DEFAULT '[]'::jsonb,
    deductions JSONB NOT NULL DEFAULT '[]'::jsonb,
    gross_salary NUMERIC(12, 2) NOT NULL DEFAULT 0.0 CHECK (gross_salary >= 0),
    net_payable NUMERIC(12, 2) NOT NULL DEFAULT 0.0 CHECK (net_payable >= 0),
    amount_paid NUMERIC(12, 2) NOT NULL DEFAULT 0.0 CHECK (amount_paid >= 0),
    remaining_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.0 CHECK (remaining_balance >= 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('paid', 'pending', 'partial', 'notConfigured', 'overdue')),
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finalized_at TIMESTAMPTZ,
    payments JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_monthly_payrolls_school_staff_month UNIQUE (school_id, staff_profile_id, month_year)
);

-- 3. Create table: salary_payments
CREATE TABLE IF NOT EXISTS public.salary_payments (
    payment_id TEXT PRIMARY KEY,
    payroll_id TEXT REFERENCES public.monthly_payrolls(id) ON DELETE SET NULL,
    school_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    staff_name TEXT NOT NULL,
    month TEXT NOT NULL,
    net_salary NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    amount_paid NUMERIC(12, 2) NOT NULL CHECK (amount_paid > 0),
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_method TEXT NOT NULL DEFAULT 'Bank Transfer',
    reference_no TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'paid' CHECK (status IN ('paid', 'pending', 'partial', 'overdue')),
    notes TEXT DEFAULT '',
    recorded_by TEXT NOT NULL DEFAULT 'Administrator',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Idempotent Performance Indexes
CREATE INDEX IF NOT EXISTS idx_salary_struct_school_staff ON public.salary_structures(school_id, staff_profile_id);
CREATE INDEX IF NOT EXISTS idx_salary_struct_active ON public.salary_structures(is_active);

CREATE INDEX IF NOT EXISTS idx_monthly_payrolls_school_month ON public.monthly_payrolls(school_id, month_year);
CREATE INDEX IF NOT EXISTS idx_monthly_payrolls_staff ON public.monthly_payrolls(staff_profile_id);
CREATE INDEX IF NOT EXISTS idx_monthly_payrolls_status ON public.monthly_payrolls(status);

CREATE INDEX IF NOT EXISTS idx_salary_payments_school_month ON public.salary_payments(school_id, month);
CREATE INDEX IF NOT EXISTS idx_salary_payments_teacher ON public.salary_payments(teacher_id);
CREATE INDEX IF NOT EXISTS idx_salary_payments_payroll ON public.salary_payments(payroll_id);
CREATE INDEX IF NOT EXISTS idx_salary_payments_date ON public.salary_payments(payment_date DESC);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.salary_structures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_payrolls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salary_payments ENABLE ROW LEVEL SECURITY;

-- 6. Non-Recursive RLS Policies: salary_structures
DROP POLICY IF EXISTS "Admins have full access to salary structures" ON public.salary_structures;
CREATE POLICY "Admins have full access to salary structures"
ON public.salary_structures
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.auth_user_id = auth.uid()
          AND p.school_id = salary_structures.school_id
          AND p.role IN ('school_admin', 'super_admin', 'principal')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.auth_user_id = auth.uid()
          AND p.school_id = salary_structures.school_id
          AND p.role IN ('school_admin', 'super_admin', 'principal')
    )
);

DROP POLICY IF EXISTS "Staff can read their own salary structure" ON public.salary_structures;
CREATE POLICY "Staff can read their own salary structure"
ON public.salary_structures
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.auth_user_id = auth.uid()
          AND (p.id = salary_structures.staff_profile_id OR p.employee_id = salary_structures.staff_profile_id)
    )
);

-- 7. Non-Recursive RLS Policies: monthly_payrolls
DROP POLICY IF EXISTS "Admins have full access to monthly payrolls" ON public.monthly_payrolls;
CREATE POLICY "Admins have full access to monthly payrolls"
ON public.monthly_payrolls
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.auth_user_id = auth.uid()
          AND p.school_id = monthly_payrolls.school_id
          AND p.role IN ('school_admin', 'super_admin', 'principal')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.auth_user_id = auth.uid()
          AND p.school_id = monthly_payrolls.school_id
          AND p.role IN ('school_admin', 'super_admin', 'principal')
    )
);

DROP POLICY IF EXISTS "Staff can read their own monthly payrolls" ON public.monthly_payrolls;
CREATE POLICY "Staff can read their own monthly payrolls"
ON public.monthly_payrolls
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.auth_user_id = auth.uid()
          AND (p.id = monthly_payrolls.staff_profile_id OR p.employee_id = monthly_payrolls.employee_id)
    )
);

-- 8. Non-Recursive RLS Policies: salary_payments
DROP POLICY IF EXISTS "Admins have full access to salary payments" ON public.salary_payments;
CREATE POLICY "Admins have full access to salary payments"
ON public.salary_payments
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.auth_user_id = auth.uid()
          AND p.school_id = salary_payments.school_id
          AND p.role IN ('school_admin', 'super_admin', 'principal')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.auth_user_id = auth.uid()
          AND p.school_id = salary_payments.school_id
          AND p.role IN ('school_admin', 'super_admin', 'principal')
    )
);

DROP POLICY IF EXISTS "Staff can read their own salary payments" ON public.salary_payments;
CREATE POLICY "Staff can read their own salary payments"
ON public.salary_payments
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.auth_user_id = auth.uid()
          AND (p.id = salary_payments.teacher_id OR p.employee_id = salary_payments.teacher_id)
    )
);
