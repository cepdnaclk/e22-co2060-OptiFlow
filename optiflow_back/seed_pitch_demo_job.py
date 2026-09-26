"""
seed_pitch_demo_job.py

Adds ONE fresh, un-scheduled job to OptiFlow that matches the PRD's
"Past paper / model paper" route (section 6.3):

    Order Intake -> Printing -> Required Waiting -> Folding -> Cutting
                 -> Quality Check -> Completed

This is intentionally left as PENDING/DRAFT — you click "Optimize" on it
LIVE during the demo so the audience watches CP-SAT actually place it
onto the Gantt chart and dispatch it to a minder's phone.

Unlike seed_pitch_data.py, this script is ADDITIVE and idempotent:
- it does NOT delete anything
- it looks up resources/operation types by NAME first, and only
  creates what's missing, so you can run it as many times as you want
  before a demo without duplicating rows.

Run from optiflow_back/ (same folder as databse.py) so the import works:
    cd optiflow_back
    python ../seed_pitch_demo_job.py
(or drop this file into optiflow_back/ directly and run it from there)
"""
import uuid
from datetime import datetime, timedelta, timezone
from databse import supabase


def get_or_create_operation_type(name: str) -> str:
    existing = supabase.table("operation_types").select("id").eq("name", name).execute().data
    if existing:
        return existing[0]["id"]
    new_id = str(uuid.uuid4())
    supabase.table("operation_types").insert({"id": new_id, "name": name}).execute()
    print(f"  + created operation_type '{name}'")
    return new_id


def get_or_create_resource(name: str, r_type: str, status: str = "ACTIVE") -> str:
    existing = supabase.table("resources").select("id").eq("name", name).execute().data
    if existing:
        return existing[0]["id"]
    new_id = str(uuid.uuid4())
    supabase.table("resources").insert(
        {"id": new_id, "name": name, "type": r_type, "status": status}
    ).execute()
    print(f"  + created resource '{name}' ({r_type})")
    return new_id


def ensure_capability(resource_id: str, op_type_id: str, rate_per_hr: float,
                       setup_minutes: int, cost_per_hr: float):
    existing = (
        supabase.table("resource_capabilities")
        .select("id")
        .eq("resource_id", resource_id)
        .eq("operation_type_id", op_type_id)
        .execute()
        .data
    )
    if existing:
        return existing[0]["id"]
    new_id = str(uuid.uuid4())
    supabase.table("resource_capabilities").insert({
        "id": new_id,
        "resource_id": resource_id,
        "operation_type_id": op_type_id,
        "processing_rate_per_hr": rate_per_hr,
        "setup_time_minutes": setup_minutes,
        "cost_per_hour": cost_per_hr,
    }).execute()
    print(f"  + created capability {resource_id[:8]} -> {op_type_id[:8]}")
    return new_id


def main():
    print("=== Seeding one demo-ready PRD job (Model Paper run) ===")

    # ---------------------------------------------------------------
    # 1. Operation types straight from the PRD's domain model (section 5)
    # ---------------------------------------------------------------
    op_print = get_or_create_operation_type("PRINT")
    op_fold = get_or_create_operation_type("FOLD")
    op_cut = get_or_create_operation_type("CUT")

    # ---------------------------------------------------------------
    # 2. Machines named after the PRD's reference profiles (section 14)
    #    + one minder so the mobile app has someone to dispatch to.
    # ---------------------------------------------------------------
    press = get_or_create_resource("Heidelberg SORM (Press 1)", "MACHINE")
    folder = get_or_create_resource("Heidelberg Stahlfolder", "MACHINE")
    cutter = get_or_create_resource("Guillotine Cutter (MCGS)", "MACHINE")
    minder = get_or_create_resource("Nadeesha Perera (Minder)", "HUMAN")

    # Wire the minder to the machines they're allowed to operate.
    # This is what the mobile app (/api/tasks?resource_id=<human_id>)
    # actually reads — a task never gets assigned_resource_id = a HUMAN
    # id directly, it goes to worker_machine_assignments instead.
    for machine_id in (press, folder, cutter):
        already = (
            supabase.table("worker_machine_assignments")
            .select("id")
            .eq("worker_id", minder)
            .eq("machine_id", machine_id)
            .execute()
            .data
        )
        if not already:
            supabase.table("worker_machine_assignments").insert({
                "id": str(uuid.uuid4()),
                "worker_id": minder,
                "machine_id": machine_id,
            }).execute()
            print(f"  + linked minder to machine {machine_id[:8]}")

    # ---------------------------------------------------------------
    # 3. Capabilities (Skills Matrix) — every machine needs at least
    #    one row here or the optimizer will reject the job with
    #    NO_CANDIDATE_RESOURCE.
    # ---------------------------------------------------------------
    ensure_capability(press, op_print, rate_per_hr=8000, setup_minutes=20, cost_per_hr=100)
    ensure_capability(folder, op_fold, rate_per_hr=6000, setup_minutes=10, cost_per_hr=45)
    ensure_capability(cutter, op_cut, rate_per_hr=10000, setup_minutes=10, cost_per_hr=35)

    # ---------------------------------------------------------------
    # 4. The job itself — a Grade 10 model-paper run, DRAFT/PENDING.
    #    Deliberately NOT pre-scheduled: this is the job you optimize
    #    live in front of the audience.
    # ---------------------------------------------------------------
    job = {
        "title": "Grade 10 Model Papers — Kandy Central College",
        "client_name": "Kandy Central College",
        "total_quantity": 2000,
        "priority": "HIGH",
        "product_type": "MODEL_PAPER",
        "deadline": (datetime.now(timezone.utc) + timedelta(days=2)).isoformat(),
        "status": "DRAFT",
    }
    job_id = supabase.table("jobs").insert(job).execute().data[0]["id"]
    print(f"  + created job '{job['title']}' ({job_id})")

    # ---------------------------------------------------------------
    # 5. Tasks — Print -> (wait to dry) -> Fold -> Cut, per PRD 6.3.
    #    No scheduled_start_time / assigned_resource_id: those only
    #    get filled in once you click Optimize.
    # ---------------------------------------------------------------
    t_print = supabase.table("tasks").insert({
        "job_id": job_id,
        "operation_type_id": op_print,
        "name": "Print Model Paper Sheets",
        "quantity_to_process": 2000,
        "status": "PENDING",
    }).execute().data[0]["id"]

    t_fold = supabase.table("tasks").insert({
        "job_id": job_id,
        "operation_type_id": op_fold,
        "name": "Fold Signatures",
        "quantity_to_process": 2000,
        "status": "PENDING",
    }).execute().data[0]["id"]

    t_cut = supabase.table("tasks").insert({
        "job_id": job_id,
        "operation_type_id": op_cut,
        "name": "Trim to Finished Size",
        "quantity_to_process": 2000,
        "status": "PENDING",
    }).execute().data[0]["id"]

    # DAG edges + the PRD's "drying/waiting" constraint (30 min after print)
    supabase.table("task_dependencies").insert([
        {"predecessor_task_id": t_print, "successor_task_id": t_fold,
         "mandatory_wait_minutes": 30},
        {"predecessor_task_id": t_fold, "successor_task_id": t_cut,
         "mandatory_wait_minutes": 0},
    ]).execute()

    print("  + created 3 tasks with a Print -> Fold -> Cut dependency chain")
    print()
    print("Done. In the app:")
    print(f'  1. Open Jobs -> find "{job["title"]}" (status DRAFT/PENDING)')
    print("  2. Click Optimize -> watch the CP-SAT solver run")
    print("  3. Switch to Schedule -> the 3 bars should appear on the "
          "machines above, TODAY (see note on stale bookings below)")
    print("  4. Log into the mobile app as the minder to see the task queue")
    print()
    print("NOTE: if the Gantt still looks empty after optimizing, it's very")
    print("likely because Press 1 / the Folder / the Cutter already have")
    print("SCHEDULED tasks (e.g. from a previous demo run or seed_pitch_data.py)")
    print("occupying today's hours — the solver correctly pushes this job")
    print("to the next free slot, which may be tomorrow. Check the response")
    print("snackbar/console for the actual scheduled_start_time, or clear old")
    print("SCHEDULED/IN_PROGRESS tasks before the real demo.")


if __name__ == "__main__":
    main()
