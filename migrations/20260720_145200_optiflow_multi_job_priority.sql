-- Migration for OptiFlow Multi-Job, Priority Scheduling, and Task-Level Break
-- Do not execute automatically. Wait for approval.
-- Safe to re-run (uses IF NOT EXISTS / DO blocks).

-- ─────────────────────────────────────────────────────────────
-- 1. Add priority to jobs
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.jobs
    ADD COLUMN IF NOT EXISTS priority VARCHAR(10) NOT NULL DEFAULT 'MEDIUM';

-- ─────────────────────────────────────────────────────────────
-- 2. Task-level scheduling fields
-- ─────────────────────────────────────────────────────────────

-- Manual processing duration entered by the manager
ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS processing_time_minutes INTEGER;

-- Optional resource chosen by the manager (null = no restriction)
ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS restricted_resource_id UUID;

-- Break controls (per task, not per resource)
ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS break_enabled BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS break_type VARCHAR(20);

ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS break_duration_minutes INTEGER NOT NULL DEFAULT 0;

-- When the assigned resource becomes available again after processing + break
ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS scheduled_rest_end_time TIMESTAMPTZ;

-- ─────────────────────────────────────────────────────────────
-- 3. Foreign key: restricted_resource_id -> resources.id
--    (added only after verifying resources.id is UUID)
-- ─────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_tasks_restricted_resource'
          AND table_name = 'tasks'
    ) THEN
        ALTER TABLE public.tasks
            ADD CONSTRAINT fk_tasks_restricted_resource
            FOREIGN KEY (restricted_resource_id)
            REFERENCES public.resources(id)
            ON DELETE SET NULL;
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 4. Validation constraints (repeat-safe DO blocks)
-- ─────────────────────────────────────────────────────────────
DO $$
BEGIN
    -- jobs.priority
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_jobs_priority') THEN
        ALTER TABLE public.jobs
            ADD CONSTRAINT chk_jobs_priority
            CHECK (priority IN ('HIGH', 'MEDIUM', 'LOW'));
    END IF;

    -- tasks.processing_time_minutes must be positive when set
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tasks_processing_time') THEN
        ALTER TABLE public.tasks
            ADD CONSTRAINT chk_tasks_processing_time
            CHECK (processing_time_minutes IS NULL OR processing_time_minutes > 0);
    END IF;

    -- tasks.break_duration_minutes in [0, 480]
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tasks_break_duration') THEN
        ALTER TABLE public.tasks
            ADD CONSTRAINT chk_tasks_break_duration
            CHECK (break_duration_minutes >= 0 AND break_duration_minutes <= 480);
    END IF;

    -- tasks.break_type only 'MACHINE' when set
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tasks_break_type') THEN
        ALTER TABLE public.tasks
            ADD CONSTRAINT chk_tasks_break_type
            CHECK (break_type IS NULL OR break_type = 'MACHINE');
    END IF;

    -- When break is enabled, duration must be > 0
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tasks_break_consistency') THEN
        ALTER TABLE public.tasks
            ADD CONSTRAINT chk_tasks_break_consistency
            CHECK (break_enabled = FALSE OR break_duration_minutes > 0);
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 5. Indexes
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_jobs_status           ON public.jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_priority         ON public.jobs(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_status          ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_jobs_status_priority_deadline
    ON public.jobs(status, priority, deadline);
CREATE INDEX IF NOT EXISTS idx_tasks_restricted_resource
    ON public.tasks(restricted_resource_id);
