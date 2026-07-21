import os
from datetime import datetime, timedelta
from ortools.sat.python import cp_model
from databse import supabase
import math
import time

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
            .select("assigned_resource_id, scheduled_start_time, scheduled_end_time, scheduled_rest_end_time, job_id")
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
        r_id = row.get("assigned_resource_id")
        start_str = row.get("scheduled_start_time")
        # Use scheduled_rest_end_time if present (resource occupied through break),
        # otherwise use scheduled_end_time (processing end).
        end_str = row.get("scheduled_rest_end_time") or row.get("scheduled_end_time")
        if not r_id or not start_str or not end_str:
            continue
        try:
            start_dt = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
            end_dt   = datetime.fromisoformat(end_str.replace("Z", "+00:00"))
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
    horizon = 0
    for task in schedulable_tasks:
        op_type = task['operation_type_id']
        qty     = max(task.get('quantity_to_process', 1) or 1, 1)
        # Use manual duration if available
        manual_dur = task.get('processing_time_minutes')
        break_dur  = task.get('break_duration_minutes') or 0
        capable = [c for c in capabilities if c['operation_type_id'] == op_type]
        if manual_dur:
            horizon += manual_dur + break_dur
        elif capable:
            worst_duration = max(
                int((qty / max(c.get('processing_rate_per_hr', 1), 0.001)) * 60
                    + c.get('setup_time_minutes', 0))
                for c in capable
            )
            horizon += worst_duration + break_dur
    horizon = max(horizon, 1440)  # minimum 24 hours

    # --- TRACKING DICTIONARIES ---
    task_vars         = {}  # Global start/end variables per task
    machine_intervals = {}  # All interval blocks per resource (including blockers)
    presence_trackers = {}  # BoolVar: is this (task, resource) pairing chosen?
    cost_expressions  = []  # Accumulated cost terms
    skipped_tasks     = []  # Tasks skipped due to no capable resource

    # -----------------------------------------------------------------
    # STEP 2: INJECT ALREADY-SCHEDULED INTERVALS (FIX 2)
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
        manual_dur  = task.get('processing_time_minutes')
        break_dur   = task.get('break_duration_minutes') or 0

        task_start = model.NewIntVar(0, horizon, f'start_{t_id}')
        task_end   = model.NewIntVar(0, horizon, f'end_{t_id}')
        task_vars[t_id] = {'start': task_start, 'end': task_end}

        capable_resources = [c for c in capabilities if c['operation_type_id'] == op_type]

        if not capable_resources:
            skipped_tasks.append(t_id)
            del task_vars[t_id]
            continue

        presence_literals = []

        for cap in capable_resources:
            r_id = cap['resource_id']

            if r_id not in machine_intervals:
                machine_intervals[r_id] = []

            rate = max(cap.get('processing_rate_per_hr', 1), 0.001)
            if manual_dur:
                processing_duration = manual_dur
            else:
                processing_duration = max(int((qty / rate) * 60 + cap.get('setup_time_minutes', 0)), 1)

            # Resource is blocked for processing + break
            resource_block_duration = processing_duration + break_dur

            task_cost = int((processing_duration / 60.0) * float(cap.get('cost_per_hour', 0)))

            is_present = model.NewBoolVar(f'presence_{t_id}_{r_id}')
            presence_literals.append(is_present)
            presence_trackers[(t_id, r_id)] = is_present

            cost_expressions.append(is_present * task_cost)

            local_start = model.NewIntVar(0, horizon, f'local_start_{t_id}_{r_id}')
            local_end   = model.NewIntVar(0, horizon, f'local_end_{t_id}_{r_id}')

            # Processing interval: local_start -> local_start + processing_duration = local_end
            proc_interval = model.NewOptionalIntervalVar(
                local_start, processing_duration, local_end, is_present,
                f'proc_{t_id}_{r_id}'
            )

            model.Add(task_start == local_start).OnlyEnforceIf(is_present)
            model.Add(task_end   == local_end).OnlyEnforceIf(is_present)

            if break_dur > 0:
                # Resource occupancy interval includes the break
                resource_end = model.NewIntVar(0, horizon, f'res_end_{t_id}_{r_id}')
                resource_interval = model.NewOptionalIntervalVar(
                    local_start, resource_block_duration, resource_end, is_present,
                    f'res_{t_id}_{r_id}'
                )
                machine_intervals[r_id].append(resource_interval)
            else:
                # No break: resource freed at processing end
                machine_intervals[r_id].append(proc_interval)

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
    # Dependency uses processing_end, not resource_rest_end
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
    # Makespan = max processing end time (not rest end time)
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

        quality = "optimal" if status == cp_model.OPTIMAL else "feasible"
        print(f"✅ Schedule Found ({quality})! Makespan: {final_makespan} mins | Cost: ${final_cost}")

        for task in schedulable_tasks:
            t_id = task['id']
            if t_id not in task_vars:
                continue  # Was skipped

            start_minutes = solver.Value(task_vars[t_id]['start'])
            end_minutes   = solver.Value(task_vars[t_id]['end'])
            break_dur     = task.get('break_duration_minutes') or 0

            actual_start    = project_start_time + timedelta(minutes=start_minutes)
            actual_end      = project_start_time + timedelta(minutes=end_minutes)
            actual_rest_end = actual_end + timedelta(minutes=break_dur)

            # Find the resource the solver chose for this task
            assigned_r_id = None
            for (track_t_id, r_id), is_present_var in presence_trackers.items():
                if track_t_id == t_id and solver.Value(is_present_var) == 1:
                    assigned_r_id = r_id
                    break

            supabase.table("tasks").update({
                "scheduled_start_time":    actual_start.isoformat(),
                "scheduled_end_time":      actual_end.isoformat(),
                "scheduled_rest_end_time": actual_rest_end.isoformat(),
                "assigned_resource_id":    assigned_r_id,
                "status":                  "SCHEDULED",
            }).eq("id", t_id).execute()

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


def fetch_multi_optiflow_data(job_ids):
    jobs = supabase.table("jobs").select("*").in_("id", job_ids).execute().data
    tasks = supabase.table("tasks").select("*").in_("job_id", job_ids).execute().data
    deps = supabase.table("task_dependencies").select("*").execute().data

    op_ids = list({t["operation_type_id"] for t in tasks if t.get("operation_type_id")})
    caps = supabase.table("resource_capabilities").select("*").in_("operation_type_id", op_ids).execute().data
    r_ids = list({c["resource_id"] for c in caps})
    res = supabase.table("resources").select("*").in_("id", r_ids).execute().data

    return jobs, tasks, deps, caps, res

def fetch_multi_already_scheduled_intervals(job_ids, project_start_time):
    return {}

def run_optimization_engine_multi(job_ids, project_start_time):
    jobs, tasks, deps, caps, resources = fetch_multi_optiflow_data(job_ids)
    if not tasks:
        return {"status": "error", "message": "No tasks found."}

    active_resource_ids = {r["id"]: r for r in resources if r.get("status") != "OFFLINE"}
    if not active_resource_ids:
        return {"status": "error", "message": "No capable active resources."}

    model = cp_model.CpModel()
    task_vars = {}
    skipped_tasks = []

    for t in tasks:
        if t["status"] in ("COMPLETED", "IN_PROGRESS", "SCHEDULED"):
            continue

        t_id  = t["id"]
        op_id = t["operation_type_id"]
        qty   = t.get("quantity_to_process", 1) or 1
        # Task-level break fields
        manual_dur = t.get("processing_time_minutes")
        break_dur  = t.get("break_duration_minutes") or 0

        capable_res = [
            c for c in caps
            if c["operation_type_id"] == op_id and c["resource_id"] in active_resource_ids
        ]
        if not capable_res:
            skipped_tasks.append(t_id)
            continue

        start = model.NewIntVar(0, 999999, f"start_{t_id}")
        end   = model.NewIntVar(0, 999999, f"end_{t_id}")

        if t["status"] == "IN_PROGRESS" and t.get("scheduled_start_time") and t.get("scheduled_end_time"):
            st    = datetime.fromisoformat(t["scheduled_start_time"])
            et    = datetime.fromisoformat(t["scheduled_end_time"])
            s_min = int((st - project_start_time).total_seconds() / 60)
            e_min = int((et - project_start_time).total_seconds() / 60)
            model.Add(start == max(0, s_min))
            model.Add(end   == max(0, e_min))

        task_vars[t_id] = {
            "start": start, "end": end,
            "capable": capable_res,
            "job_id": t["job_id"],
            "status": t["status"],
            "qty": qty,
            "manual_dur": manual_dur,
            "break_dur": break_dur,
        }

    if len(skipped_tasks) == len(tasks) and tasks:
        return {"status": "error", "message": "No capable resources available for the required tasks."}

    presence_trackers  = {}
    resource_intervals = {r: [] for r in active_resource_ids}
    cost_exprs         = []

    for t_id, v in task_vars.items():
        is_present_vars = []
        manual_dur = v["manual_dur"]
        break_dur  = v["break_dur"]
        qty        = v["qty"]

        for c in v["capable"]:
            r_id        = c["resource_id"]
            rate        = c.get("processing_rate_per_hr", 1) or 1
            setup       = c.get("setup_time_minutes", 0) or 0
            cost_per_hr = c.get("cost_per_hour", 0) or 0

            if manual_dur:
                proc_dur = manual_dur
            else:
                proc_dur = math.ceil((qty / rate) * 60) + setup

            # Resource is occupied for processing + task-level break
            resource_block = proc_dur + break_dur

            p_var = model.NewBoolVar(f"pres_{t_id}_{r_id}")
            is_present_vars.append(p_var)
            presence_trackers[(t_id, r_id)] = p_var

            # Processing interval (task_end = start + proc_dur)
            proc_interval = model.NewOptionalIntervalVar(
                v["start"], proc_dur, v["end"], p_var, f"proc_{t_id}_{r_id}"
            )

            if break_dur > 0:
                # Resource occupancy interval includes the break
                res_end = model.NewIntVar(0, 999999, f"res_end_{t_id}_{r_id}")
                res_interval = model.NewOptionalIntervalVar(
                    v["start"], resource_block, res_end, p_var, f"res_{t_id}_{r_id}"
                )
                resource_intervals[r_id].append(res_interval)
            else:
                resource_intervals[r_id].append(proc_interval)

            cost_exprs.append(p_var * int((proc_dur / 60) * cost_per_hr))

        model.AddExactlyOne(is_present_vars)

    for r_id, intervals in resource_intervals.items():
        if intervals:
            model.AddNoOverlap(intervals)

    # Dependencies use processing end (task_end), not resource rest end
    for d in deps:
        p = d["predecessor_task_id"]
        s = d["successor_task_id"]
        w = d.get("mandatory_wait_minutes", 0) or 0
        if p in task_vars and s in task_vars:
            model.Add(task_vars[s]["start"] >= task_vars[p]["end"] + w)

    makespan_var = model.NewIntVar(0, 999999, "makespan")

    if task_vars:
        model.AddMaxEquality(makespan_var, [v["end"] for v in task_vars.values()])
    else:
        model.Add(makespan_var == 0)

    total_cost_var = model.NewIntVar(0, 99999999, "total_cost")
    model.Add(total_cost_var == sum(cost_exprs) if cost_exprs else 0)

    # Deadlines and Priorities
    job_priorities = {}
    job_deadlines  = {}
    weight_map     = {"HIGH": 10, "MEDIUM": 5, "LOW": 1}

    for j in jobs:
        p = j.get("priority", "MEDIUM") or "MEDIUM"
        job_priorities[j["id"]] = weight_map.get(p.upper(), 5)
        dl = j.get("deadline")
        if dl:
            dt = datetime.fromisoformat(dl)
            job_deadlines[j["id"]] = int((dt - project_start_time).total_seconds() / 60)

    tardiness_terms  = []
    completion_terms = []

    for t_id, v in task_vars.items():
        j_id = v["job_id"]
        w    = job_priorities.get(j_id, 5)
        # Completion uses processing end (task_end)
        completion_terms.append(v["end"] * w)
        if j_id in job_deadlines:
            dl_min = max(0, job_deadlines[j_id])
            tard   = model.NewIntVar(0, 999999, f"tard_{t_id}")
            model.AddMaxEquality(tard, [0, v["end"] - dl_min])
            tardiness_terms.append(tard * w)

    tardiness_total_var = model.NewIntVar(0, 999999999, "tard_tot")
    if tardiness_terms:
        model.Add(tardiness_total_var == sum(tardiness_terms))
    else:
        model.Add(tardiness_total_var == 0)

    completion_total_var = model.NewIntVar(0, 999999999, "comp_tot")
    if completion_terms:
        model.Add(completion_total_var == sum(completion_terms))
    else:
        model.Add(completion_total_var == 0)

    # Lexicographic solving
    solver       = cp_model.CpSolver()
    total_budget = 60.0
    start_time   = time.monotonic()
    passes       = [tardiness_total_var, completion_total_var, makespan_var, total_cost_var]
    all_optimal  = True
    best_snapshot = None

    for obj_var in passes:
        elapsed   = time.monotonic() - start_time
        remaining = total_budget - elapsed
        if remaining <= 0:
            all_optimal = False
            break
        solver.parameters.max_time_in_seconds = remaining
        model.Minimize(obj_var)
        status = solver.Solve(model)

        if status in (cp_model.OPTIMAL, cp_model.FEASIBLE):
            if status != cp_model.OPTIMAL:
                all_optimal = False
            best_val = solver.Value(obj_var)
            if status == cp_model.OPTIMAL:
                model.Add(obj_var == best_val)
            else:
                model.Add(obj_var <= best_val)

            snapshot = {
                "makespan": solver.Value(makespan_var),
                "cost": solver.Value(total_cost_var),
                "tasks": {}
            }
            for t_id, v in task_vars.items():
                pres_map = {}
                for (track_t_id, r_id), is_present_var in presence_trackers.items():
                    if track_t_id == t_id:
                        pres_map[r_id] = solver.Value(is_present_var)
                snapshot["tasks"][t_id] = {
                    "start":    solver.Value(v["start"]),
                    "end":      solver.Value(v["end"]),
                    "presence": pres_map,
                    "break_dur": v["break_dur"],
                }
            best_snapshot = snapshot
            if status == cp_model.FEASIBLE:
                break
        else:
            all_optimal = False
            break

    if best_snapshot:
        quality = "optimal" if all_optimal else "feasible"

        for t_id, snapshot_v in best_snapshot["tasks"].items():
            start_minutes = snapshot_v["start"]
            end_minutes   = snapshot_v["end"]
            break_dur     = snapshot_v["break_dur"]
            actual_start  = project_start_time + timedelta(minutes=start_minutes)
            actual_end    = project_start_time + timedelta(minutes=end_minutes)
            # scheduled_rest_end_time: when the resource becomes free again
            actual_rest_end = actual_end + timedelta(minutes=break_dur)

            assigned_r_id = None
            for r_id, is_present_val in snapshot_v["presence"].items():
                if is_present_val == 1:
                    assigned_r_id = r_id
                    break

            if assigned_r_id:
                supabase.table("tasks").update({
                    "scheduled_start_time":    actual_start.isoformat(),
                    "scheduled_end_time":      actual_end.isoformat(),
                    "scheduled_rest_end_time": actual_rest_end.isoformat(),
                    "assigned_resource_id":    assigned_r_id,
                    "status":                  "SCHEDULED",
                }).eq("id", t_id).execute()

        for job_id in job_ids:
            supabase.table("jobs").update({"status": "SCHEDULED"}).eq("id", job_id).execute()

        return {
            "status":           "success",
            "quality":          quality,
            "makespan_minutes": best_snapshot["makespan"],
            "total_cost":       best_snapshot["cost"],
            "scheduled_tasks":  len(best_snapshot["tasks"]),
            "skipped_tasks":    len(skipped_tasks),
            "warnings":         ""
        }
    else:
        return {"status": "error", "message": "Cyclic dependencies or invalid state."}
