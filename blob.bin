import os
from datetime import datetime, timedelta
from ortools.sat.python import cp_model
from databse import supabase

# =====================================================================
# PHASE 1: SYSTEM SETUP & DATA INGESTION
# =====================================================================

def fetch_optiflow_data(job_id: str):
    """
    Pulls the current physical reality of the print shop out of PostgreSQL
    and translates it into Python lists and dictionaries.

    FIX 3: Capabilities are now filtered to only the operation_type_ids
    that this specific job's tasks actually need, avoiding a full-table scan.
    """
    # 1. Get every step required to complete this specific order
    tasks = supabase.table("tasks").select("*").eq("job_id", job_id).execute().data

    # 2. Extract the unique operation types this job needs
    needed_op_type_ids = list(set(
        t['operation_type_id'] for t in tasks
        if t.get('operation_type_id') is not None
    ))

    if not needed_op_type_ids:
        return tasks, [], []

    # 3. Get the DAG (Directed Acyclic Graph) rules
    task_ids = [t['id'] for t in tasks]
    dependencies = (
        supabase.table("task_dependencies")
        .select("*")
        .in_("successor_task_id", task_ids)
        .execute()
        .data
    )

    # FIX 3: Filtered capabilities — only fetch what this job needs
    capabilities = (
        supabase.table("resource_capabilities")
        .select("*")
        .in_("operation_type_id", needed_op_type_ids)
        .execute()
        .data
    )

    return tasks, dependencies, capabilities


def fetch_already_scheduled_intervals(job_id: str):
    """
    FIX 2: Fetches all tasks from OTHER jobs that are currently SCHEDULED
    or IN_PROGRESS, so the solver knows which resource time-slots are
    already taken. This prevents cross-job machine double-booking.

    Returns: { resource_id: [(start_minutes_from_now, end_minutes_from_now), ...] }
    """
    try:
        scheduled = (
            supabase.table("tasks")
            .select("assigned_resource_id, scheduled_start_time, scheduled_end_time, job_id")
            .in_("status", ["SCHEDULED", "IN_PROGRESS"])
            .neq("job_id", job_id)
            .not_.is_("assigned_resource_id", "null")
            .not_.is_("scheduled_start_time", "null")
            .not_.is_("scheduled_end_time", "null")
            .execute()
            .data
        )
    except Exception as e:
        print(f"[Optimizer] Warning: could not fetch existing schedule: {e}")
        return {}

    blocked = {}
    now = datetime.utcnow()

    for row in scheduled:
        r_id      = row.get("assigned_resource_id")
        start_str = row.get("scheduled_start_time")
        end_str   = row.get("scheduled_end_time")
        if not r_id or not start_str or not end_str:
            continue
        try:
            start_dt = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
            end_dt   = datetime.fromisoformat(end_str.replace("Z", "+00:00"))
            # Convert to minutes relative to now (project_start_time proxy)
            start_min = max(0, int((start_dt.replace(tzinfo=None) - now).total_seconds() / 60))
            end_min   = max(start_min + 1, int((end_dt.replace(tzinfo=None) - now).total_seconds() / 60))
            if r_id not in blocked:
                blocked[r_id] = []
            blocked[r_id].append((start_min, end_min))
        except Exception:
            continue

    return blocked


# =====================================================================
# PHASE 2: THE MATHEMATICAL BRAIN (CP-SAT)
# =====================================================================

def run_optimization_engine(job_id: str, project_start_time: datetime, alpha: int = 70, beta: int = 30):
    """
    Executes the Constraint Programming solver.
    alpha: The weight given to completing the job quickly (Time).
    beta:  The weight given to minimizing operational expenses (Cost).
    """
    # Bring the database information into the engine's memory
    tasks, dependencies, capabilities = fetch_optiflow_data(job_id)

    # FIX 5 / FIX 6: Early-exit guards before touching the model
    if not tasks:
        return {"status": "error", "message": "This job has no tasks to schedule."}

    schedulable_tasks = [t for t in tasks if t.get('operation_type_id') is not None]
    if not schedulable_tasks:
        return {
            "status": "error",
            "message": "No tasks have an operation type assigned. Please configure task operation types first.",
        }

    # FIX 2: Get time blocks already occupied by other active jobs
    blocked_intervals_data = fetch_already_scheduled_intervals(job_id)

    # Instantiate the blank canvas
    model = cp_model.CpModel()

    # FIX 1: Dynamic horizon — sum of the worst-case duration for each task
    # (slowest capable machine + longest setup). Much tighter than 100,000.
    horizon = 0
    for task in schedulable_tasks:
        op_type = task['operation_type_id']
        qty     = max(task.get('quantity_to_process', 1) or 1, 1)
        capable = [c for c in capabilities if c['operation_type_id'] == op_type]
        if capable:
            worst_duration = max(
                int((qty / max(c.get('processing_rate_per_hr', 1), 0.001)) * 60
                    + c.get('setup_time_minutes', 0))
                for c in capable
            )
            horizon += worst_duration
    horizon = max(horizon, 1440)  # minimum 24 hours

    # --- TRACKING DICTIONARIES ---
    task_vars         = {}  # Global start/end variables per task
    machine_intervals = {}  # All interval blocks per resource (including blockers)
    presence_trackers = {}  # BoolVar: is this (task, resource) pairing chosen?
    cost_expressions  = []  # Accumulated cost terms
    skipped_tasks     = []  # Tasks skipped due to no capable resource

    # -----------------------------------------------------------------
    # STEP 2: INJECT ALREADY-SCHEDULED INTERVALS (FIX 2)
    # Lock in time blocks owned by tasks from other active jobs so the
    # solver cannot re-use those slots.
    # -----------------------------------------------------------------
    for r_id, blocks in blocked_intervals_data.items():
        if r_id not in machine_intervals:
            machine_intervals[r_id] = []
        for (start_min, end_min) in blocks:
            duration = max(end_min - start_min, 1)
            blocker_start    = model.NewConstant(start_min)
            blocker_end      = model.NewConstant(end_min)
            blocker_interval = model.NewFixedSizeIntervalVar(
                blocker_start, duration, f'blocked_{r_id}_{start_min}'
            )
            machine_intervals[r_id].append(blocker_interval)

    # -----------------------------------------------------------------
    # STEP 3: CREATING THE QUANTUM TIMELINE
    # -----------------------------------------------------------------
    for task in schedulable_tasks:
        t_id    = task['id']
        op_type = task['operation_type_id']
        qty     = max(task.get('quantity_to_process', 1) or 1, 1)

        task_start = model.NewIntVar(0, horizon, f'start_{t_id}')
        task_end   = model.NewIntVar(0, horizon, f'end_{t_id}')
        task_vars[t_id] = {'start': task_start, 'end': task_end}

        capable_resources = [c for c in capabilities if c['operation_type_id'] == op_type]

        # FIX 5: If no resource can handle this task, skip it gracefully
        # instead of crashing with AddExactlyOne([])
        if not capable_resources:
            skipped_tasks.append(t_id)
            del task_vars[t_id]
            continue

        presence_literals = []

        for cap in capable_resources:
            r_id = cap['resource_id']

            if r_id not in machine_intervals:
                machine_intervals[r_id] = []

            rate     = max(cap.get('processing_rate_per_hr', 1), 0.001)
            duration = max(int((qty / rate) * 60 + cap.get('setup_time_minutes', 0)), 1)

            # Integer cost: duration_in_hours * cost_per_hour
            task_cost = int((duration / 60.0) * float(cap.get('cost_per_hour', 0)))

            # THE SWITCH: did the solver pick this resource?
            is_present = model.NewBoolVar(f'presence_{t_id}_{r_id}')
            presence_literals.append(is_present)
            presence_trackers[(t_id, r_id)] = is_present

            cost_expressions.append(is_present * task_cost)

            local_start = model.NewIntVar(0, horizon, f'local_start_{t_id}_{r_id}')
            local_end   = model.NewIntVar(0, horizon, f'local_end_{t_id}_{r_id}')

            interval = model.NewOptionalIntervalVar(
                local_start, duration, local_end, is_present,
                f'int_{t_id}_{r_id}'
            )

            model.Add(task_start == local_start).OnlyEnforceIf(is_present)
            model.Add(task_end   == local_end).OnlyEnforceIf(is_present)

            machine_intervals[r_id].append(interval)

        # RULE: Exactly one resource handles this task
        model.AddExactlyOne(presence_literals)

    # FIX 6: Guard — if ALL tasks were skipped, fail cleanly
    if not task_vars:
        msg = (
            "No tasks could be scheduled. Ensure every task has an operation type "
            "and at least one capable resource configured in the Skills Matrix."
        )
        if skipped_tasks:
            msg += f" ({len(skipped_tasks)} task(s) had no capable resource.)"
        return {"status": "error", "message": msg}

    # -----------------------------------------------------------------
    # STEP 4: ENFORCING CHRONOLOGY (The DAG)
    # -----------------------------------------------------------------
    for dep in dependencies:
        pred_id = dep['predecessor_task_id']
        succ_id = dep['successor_task_id']
        wait    = dep.get('mandatory_wait_minutes', 0) or 0

        if pred_id in task_vars and succ_id in task_vars:
            model.Add(task_vars[succ_id]['start'] >= task_vars[pred_id]['end'] + wait)

    # -----------------------------------------------------------------
    # STEP 5: PREVENTING CLASHES (No Overlap per resource)
    # -----------------------------------------------------------------
    for r_id, intervals in machine_intervals.items():
        if len(intervals) > 1:
            model.AddNoOverlap(intervals)

    # -----------------------------------------------------------------
    # STEP 6: THE MULTI-OBJECTIVE EQUATION
    # -----------------------------------------------------------------
    makespan_var = model.NewIntVar(0, horizon, 'makespan')
    model.AddMaxEquality(makespan_var, [v['end'] for v in task_vars.values()])

    total_cost_var = model.NewIntVar(0, 99_999_999, 'total_cost')
    if cost_expressions:
        model.Add(total_cost_var == sum(cost_expressions))
    else:
        model.Add(total_cost_var == 0)

    model.Minimize((alpha * makespan_var) + (beta * total_cost_var))

    # -----------------------------------------------------------------
    # STEP 7: UNLEASH THE ENGINE
    # FIX 4: 60-second wall-clock limit so the API never hangs indefinitely
    # -----------------------------------------------------------------
    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = 60.0
    status = solver.Solve(model)

    # =====================================================================
    # PHASE 3: DATA EXTRACTION & SAVING THE RESULTS
    # =====================================================================

    if status in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        final_makespan = solver.Value(makespan_var)
        final_cost     = solver.Value(total_cost_var)

        # FIX 4: Tell the caller whether this is a proven optimal result or
        # the best found within the 60-second time budget
        quality = "optimal" if status == cp_model.OPTIMAL else "feasible"
        print(f"✅ Schedule Found ({quality})! Makespan: {final_makespan} mins | Cost: ${final_cost}")

        for task in schedulable_tasks:
            t_id = task['id']
            if t_id not in task_vars:
                continue  # Was skipped (no capable resource)

            start_minutes = solver.Value(task_vars[t_id]['start'])
            end_minutes   = solver.Value(task_vars[t_id]['end'])

            actual_start = project_start_time + timedelta(minutes=start_minutes)
            actual_end   = project_start_time + timedelta(minutes=end_minutes)

            # Find the resource the solver chose for this task
            assigned_r_id = None
            for (track_t_id, r_id), is_present_var in presence_trackers.items():
                if track_t_id == t_id and solver.Value(is_present_var) == 1:
                    assigned_r_id = r_id
                    break

            # Commit schedule to Supabase
            supabase.table("tasks").update({
                "scheduled_start_time": actual_start.isoformat(),
                "scheduled_end_time":   actual_end.isoformat(),
                "assigned_resource_id": assigned_r_id,
                "status":               "SCHEDULED",
            }).eq("id", t_id).execute()

        # Mark the parent job as scheduled
        supabase.table("jobs").update({"status": "SCHEDULED"}).eq("id", job_id).execute()

        return {
            "status":           "success",
            "quality":          quality,
            "makespan_minutes": final_makespan,
            "total_cost":       final_cost,
            "skipped_tasks":    len(skipped_tasks),
        }

    else:
        print("❌ No feasible schedule found.")
        return {
            "status":  "error",
            "message": (
                "The solver could not find a valid schedule within the time limit. "
                "Check that all tasks have capable resources and that dependencies form no cycles."
            ),
        }

