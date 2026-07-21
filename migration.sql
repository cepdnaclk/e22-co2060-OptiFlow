-- Migration for OptiFlow Multi-Job and Priority Scheduling
-- Do not execute automatically. Wait for approval.

-- 1. Add priority to jobs
ALTER TABLE jobs 
ADD COLUMN priority VARCHAR(10) DEFAULT 'MEDIUM' 
CHECK (priority IN ('HIGH', 'MEDIUM', 'LOW'));

-- 2. Add rest_after_task_minutes to resources
ALTER TABLE resources 
ADD COLUMN rest_after_task_minutes INTEGER DEFAULT 0 
CHECK (rest_after_task_minutes >= 0 AND rest_after_task_minutes <= 480);

-- 3. Add scheduled_rest_end_time to tasks
ALTER TABLE tasks 
ADD COLUMN scheduled_rest_end_time TIMESTAMP WITH TIME ZONE;

-- 4. Useful Indexes
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_priority ON jobs(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
