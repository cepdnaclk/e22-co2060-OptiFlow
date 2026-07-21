import os
import math
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

    Extended: Also fetches task_allowed_resources and resource types
    for break and resource-restriction support.
    """
    # 1. Get every step required to complete this specific order
    tasks = supabase.table("tasks").select("*").eq("job_id", job_id).execute().data

    # 2. Extract the unique operation types this job needs
    needed_op_type_ids = list(set(
        t['operation_type_id'] for t in tasks
        if t.get('operation_type_id') is not None
    ))

    if not needed_op_type_ids:
        return tasks, [], [], {}, {}

    # 3. Get the DAG (Directed Acyclic Graph) rules
    task_ids = [t['id'] for t in tasks]
    dependencies = (
        supabase.table("task_dependencies")
        .select("*")
        .in_("successor_task_id", task_ids)
        .execute()
        .data
    )

    # FIX 3: Filtered capabilities — only fetch what this job needs.
    # Embed resource metadata (type, status) via a Supabase nested join so we
    # never read non-existent type/status fields directly off a capability row.
    capabilities = (
        supabase.table("resource_capabilities")
        .select("*, resources(id, name, type, status)")
        .in_("operation_type_id", needed_op_type_ids)
        .execute()
        .data
    )

    # 4. Fetch allowed resources for each task (from normalized join table)
    allowed_resources_map = {}  # {task_id: [resource_id, ...]}
    if task_ids:
        try:
            allowed_rows = (
                supabase.table("task_allowed_resources")
                .select("task_id, resource_id")
                .in_("task_id", task_ids)
                .execute()
                .data
            )
            for row in (allowed_rows or []):
                tid = row["task_id"]
                rid = row["resource_id"]
                if tid not in allowed_resources_map:
                    allowed_resources_map[tid] = []
                allowed_resources_map[tid].append(rid)
        except Exception as e:
            # Table may not exist yet in old deployments — graceful fallback
            print(f"[Optimizer] Warning: could not fetch task_allowed_resources: {e}")

    # 5. Build resource metadata lookup from the embedded nested join data.
    # Structure: {resource_id: {"type": "MACHINE"|"HUMAN", "status": "ACTIVE"|...}}
    # Replaces the old separate supabase.table("resources") round-trip, which
    # could store None for type if the column value was NULL, causing the
    # break-type filter comparison (None == 'MACHINE') to silently fail.
    resource_types_map = {}
    for cap in (capabilities or []):
        res = cap.get("resources")
        rid = cap.get("resource_id")
        if rid and res and isinstance(res, dict):
            resource_types_map[rid] = {
                "type":   str(res.get("type")   or "MACHINE").upper(),
                "status": str(res.get("status") or "ACTIVE").upper(),
            }

    return tasks, dependencies, capabilities, allowed_resources_map, resource_types_map


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
            start_min = max(0, int(math.floor((start_dt.replace(tzinfo=None) - now).total_seconds() / 60.0)))
            end_min   = max(start_min + 1, int(math.ceil((end_dt.replace(tzinfo=None) - now).total_seconds() / 60.0)))
            if r_id not in blocked:
                blocked[r_id] = []
            blocked[r_id].append((start_min, end_min))
        except Exception:
            continue

    # Merge overlapping intervals for each resource to prevent AddNoOverlap from throwing INFEASIBLE
    for r_id in blocked:
        blocked[r_id].sort(key=lambda x: x[0])
        merged = []
        for current in blocked[r_id]:
            if not merged:
                merged.append(current)
            else:
                last = merged[-1]
                if current[0] < last[1]: # Overlap
                    merged[-1] = (last[0], max(last[1], current[1]))
                else:
                    merged.append(current)
        blocked[r_id] = merged

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
    tasks, dependencies, capabilities, allowed_resources_map, resource_types_map = fetch_optiflow_data(job_id)

    # ------------------------------------------------------------------
    # Helper: resolve resource metadata from a capability row.
    # Prefers the nested 'resources' JOIN object embedded in each cap row;
    # falls back to the pre-built resource_types_map dict.
    # Always returns strings normalised to UPPERCASE.
    # ------------------------------------------------------------------
    def _res_meta(cap: dict) -> dict:
        """Returns {'type': ..., 'status': ...} for a capability (both UPPERCASE str)."""
        nested = cap.get("resources")
        if nested and isinstance(nested, dict):
            return {
                "type":   str(nested.get("type")   or "MACHINE").upper(),
                "status": str(nested.get("status") or "ACTIVE").upper(),
            }
        # Fallback: use the pre-built map (which itself was built from nested data)
        return resource_types_map.get(
            cap.get("resource_id", ""),
            {"type": "MACHINE", "status": "ACTIVE"},
        )

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

    # -----------------------------------------------------------------
    # DYNAMIC HORIZON — sum of worst-case duration + break for each task
    # -----------------------------------------------------------------
    horizon = 0
    for task in schedulable_tasks:
        op_type = task['operation_type_id']
        qty     = max(task.get('quantity_to_process', 1) or 1, 1)
        manual_time = task.get('processing_time_minutes') or 0
        break_mins  = task.get('break_after_minutes', 0) or 0
        capable = [c for c in capabilities if c['operation_type_id'] == op_type]
        if capable:
            if manual_time > 0:
                # Manual duration + worst-case setup + break
                worst_duration = manual_time + max(
                    c.get('setup_time_minutes', 0) for c in capable
                ) + break_mins
            else:
                # Quantity-based worst case + break
                worst_duration = max(
                    int((qty / max(c.get('processing_rate_per_hr', 1), 0.001)) * 60
                        + c.get('setup_time_minutes', 0))
                    for c in capable
                ) + break_mins
            horizon += worst_duration
    # Also account for dependency wait times
    for dep in dependencies:
        horizon += dep.get('mandatory_wait_minutes', 0) or 0
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
        t_id       = task['id']
        t_name     = task.get('name', str(t_id))
        op_type    = task['operation_type_id']
        qty        = max(task.get('quantity_to_process', 1) or 1, 1)
        manual_time = task.get('processing_time_minutes') or 0
        break_mins  = task.get('break_after_minutes', 0) or 0
        break_type  = task.get('break_type', 'NONE') or 'NONE'

        task_start = model.NewIntVar(0, horizon, f'start_{t_id}')
        task_end   = model.NewIntVar(0, horizon, f'end_{t_id}')
        task_vars[t_id] = {'start': task_start, 'end': task_end}

        # --- STEP 3a: Base candidates — operation type match ---
        capable_resources = [c for c in capabilities if c['operation_type_id'] == op_type]

        # --- STEP 3b: Filter out non-ACTIVE resources ---
        # Uses the nested 'resources' join data embedded in each capability row
        # so we never compare against a raw capability field that doesn't exist.
        capable_resources = [
            c for c in capable_resources
            if _res_meta(c).get("status", "ACTIVE") == "ACTIVE"
        ]

        # --- STEP 3c: allowed_resource_ids restriction ---
        # An EMPTY list means "no restriction — allow every capable active resource".
        # Only filter when the task explicitly names specific resources.
        task_allowed = allowed_resources_map.get(t_id, [])
        if task_allowed:
            capable_resources = [
                c for c in capable_resources
                if c['resource_id'] in task_allowed
            ]

        # --- STEP 3d: break_type resource-type filter ---
        # MACHINE break requires a MACHINE resource; HUMAN break requires HUMAN.
        # NONE does not restrict by resource type.
        if break_type == "MACHINE":
            capable_resources = [
                c for c in capable_resources
                if _res_meta(c).get("type", "MACHINE") == "MACHINE"
            ]
        elif break_type == "HUMAN":
            capable_resources = [
                c for c in capable_resources
                if _res_meta(c).get("type", "MACHINE") == "HUMAN"
            ]
        # break_type == "NONE": no type filter applied

        # --- Diagnostics: log candidate resolution for every task ---
        print(
            f"[Optimizer] Task {t_id!r} ({t_name!r}): "
            f"operation={op_type}, "
            f"break_type={break_type}, "
            f"allowed_resources={task_allowed}, "
            f"candidate_resources={[c['resource_id'] for c in capable_resources]}"
        )

        # Early return with a clear error if no candidate resources remain.
        # Do NOT build CP-SAT variables with zero candidates.
        if not capable_resources:
            return {
                "status":        "error",
                "solver_status": "NO_CANDIDATE_RESOURCE",
                "message": (
                    f'Task "{t_name}" has no valid active resource. '
                    f'Operation type: {op_type}; '
                    f'break type: {break_type}; '
                    f'allowed resources: {task_allowed}.'
                ),
            }

        presence_literals = []

        for cap in capable_resources:
            r_id = cap['resource_id']

            if r_id not in machine_intervals:
                machine_intervals[r_id] = []

            # --- DURATION LOGIC ---
            # If processing_time_minutes is provided and > 0, use it + setup_time
            # Otherwise fall back to quantity/rate + setup_time
            setup = cap.get('setup_time_minutes', 0) or 0
            if manual_time > 0:
                duration = max(manual_time + setup, 1)
            else:
                rate = max(cap.get('processing_rate_per_hr', 1), 0.001)
                duration = max(int((qty / rate) * 60 + setup), 1)

            # Integer cost: duration_in_hours * cost_per_hour
            task_cost = int((duration / 60.0) * float(cap.get('cost_per_hour', 0)))

            # THE SWITCH: did the solver pick this resource?
            is_present = model.NewBoolVar(f'presence_{t_id}_{r_id}')
            presence_literals.append(is_present)
            presence_trackers[(t_id, r_id)] = is_present

            cost_expressions.append(is_present * task_cost)

            local_start = model.NewIntVar(0, horizon, f'local_start_{t_id}_{r_id}')
            local_end   = model.NewIntVar(0, horizon, f'local_end_{t_id}_{r_id}')

            # Task execution interval
            interval = model.NewOptionalIntervalVar(
                local_start, duration, local_end, is_present,
                f'int_{t_id}_{r_id}'
            )

            model.Add(task_start == local_start).OnlyEnforceIf(is_present)
            model.Add(task_end   == local_end).OnlyEnforceIf(is_present)

            machine_intervals[r_id].append(interval)

            # --- BREAK INTERVAL ---
            # If break_after_minutes > 0, create an optional break interval
            # on the SAME resource, starting exactly at task execution end.
            # Uses the same presence Boolean so it's active only when
            # this resource is chosen for the task.
            if break_mins > 0:
                break_start = model.NewIntVar(0, horizon, f'break_start_{t_id}_{r_id}')
                break_end   = model.NewIntVar(0, horizon, f'break_end_{t_id}_{r_id}')

                break_interval = model.NewOptionalIntervalVar(
                    break_start, break_mins, break_end, is_present,
                    f'break_int_{t_id}_{r_id}'
                )

                # Break starts exactly when the task execution ends
                model.Add(break_start == local_end).OnlyEnforceIf(is_present)

                # Add break to the same resource's NoOverlap list
                machine_intervals[r_id].append(break_interval)

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
    # Note: Dependencies use task execution end, NOT break end.
    # The break blocks the RESOURCE, not the successor task.
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

    # Validate model structure before handing it to the solver.
    # Catches zero-duration intervals, bad variable bounds, etc.
    validation_error = model.Validate()
    if validation_error:
        return {
            "status":        "error",
            "solver_status": "MODEL_INVALID",
            "message":       f"Optimizer model validation failed: {validation_error}",
        }

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
        print(f"[Optimizer] Schedule found ({quality}). Makespan: {final_makespan} mins | Cost: ${final_cost}")

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
            # scheduled_end_time = task execution end (NOT break end)
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
        status_name = solver.StatusName(status)
        print(f"[Optimizer] No feasible schedule found. Solver status: {status_name}")

        if status_name == "INFEASIBLE":
            msg = (
                "The solver determined no valid schedule exists (INFEASIBLE). "
                "Check that task dependencies do not form a cycle and that every task "
                "has at least one capable, active resource."
            )
        elif status_name == "MODEL_INVALID":
            msg = (
                "The constraint model is invalid (MODEL_INVALID). "
                "This usually means a task duration or horizon value is 0 or negative. "
                "Verify all processing rates and quantities are positive."
            )
        elif status_name == "UNKNOWN":
            msg = (
                "The solver could not find a solution within the 60-second time limit (UNKNOWN). "
                "Try simplifying the job (fewer tasks / resources) or increase task processing rates."
            )
        else:
            msg = (
                f"Optimization failed with solver status: {status_name}. "
                "Check that all tasks have capable resources and that dependencies form no cycles."
            )

        return {
            "status":        "error",
            "solver_status": status_name,
            "message":       msg,
        }