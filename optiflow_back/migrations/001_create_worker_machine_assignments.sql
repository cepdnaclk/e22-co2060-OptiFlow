-- =====================================================================
-- Migration: 001_create_worker_machine_assignments.sql
-- Description: Create worker_machine_assignments junction table to map
--              human workers to the machines they operate.
-- =====================================================================

-- 1. Create table
CREATE TABLE IF NOT EXISTS public.worker_machine_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES public.resources(id) ON DELETE CASCADE,
    machine_id UUID NOT NULL REFERENCES public.resources(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_worker_machine UNIQUE (worker_id, machine_id)
);

-- 2. Performance indexes for fast querying by worker or machine
CREATE INDEX IF NOT EXISTS idx_wma_worker_id ON public.worker_machine_assignments(worker_id);
CREATE INDEX IF NOT EXISTS idx_wma_machine_id ON public.worker_machine_assignments(machine_id);

-- 3. Row-Level Security (RLS) configuration
ALTER TABLE public.worker_machine_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to worker_machine_assignments"
    ON public.worker_machine_assignments
    FOR SELECT
    USING (true);

CREATE POLICY "Allow public insert/update/delete on worker_machine_assignments"
    ON public.worker_machine_assignments
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- 4. Initial Seed Mappings:
-- Marcus Johnson (Press Operator) -> HP Indigo 12000
-- Elena Rodriguez (Bindery Tech)  -> Horizon BQ-470
-- David Kim (Pre-press)           -> Epson SureColor
INSERT INTO public.worker_machine_assignments (worker_id, machine_id)
VALUES
    ('33333333-3333-3333-3333-333333333332', '22222222-2222-2222-2222-222222222222'),
    ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222224'),
    ('33333333-3333-3333-3333-333333333334', '22222222-2222-2222-2222-222222222225')
ON CONFLICT (worker_id, machine_id) DO NOTHING;
