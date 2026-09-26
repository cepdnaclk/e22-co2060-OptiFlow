"""
seed_demo_final.py

Full end-to-end demo seed for the pitch: Add Job -> Optimize -> Gantt ->
Minder's phone. Pairs with the optimizer.py fix that writes
assigned_human_id (not just assigned_resource_id) whenever a task lands
on a machine that has a minder wired up in worker_machine_assignments.

WHAT THIS DOES
---------------
1. (optional) Clears stale SCHEDULED / IN_PROGRESS tasks so today's Gantt
   is empty before you start the demo — see clear_todays_bookings().
2. Ensures the 3 demo minders (Elena, Marcus, Sarah) + their machines +
   worker_machine_assignments links exist (idempotent — looks up by name
   first, matches the IDs seed_pitch_data.py already uses).
3. Creates ONE new DRAFT job following the PRD's sewn-book route
   (section 6.1): Print -> [dry] -> Fold -> Sew -> Cut, with realistic
   waiting times and a full capabilities matrix, so the CP-SAT solver has
   more than one resource per operation type to choose between (makes a
   more convincing demo than a single-candidate schedule).
4. Leaves the job as DRAFT/PENDING — you click Optimize live.

This script is ADDITIVE and safe to re-run: everything is looked up by
name/unique key before insert, nothing is deleted except what
clear_todays_bookings() explicitly targets (and that's opt-in via CLI
flag, not automatic).

Usage (run from optiflow_back/):
    python seed_demo_final.py                # seed only
    python seed_demo_final.py --clear-today   # also clear today's bookings first
"""
import sys
import uuid
from datetime import datetime, timedelta, timezone
from databse import supabase


# ---------------------------------------------------------------------
# Fixed IDs matching seed_pitch_data.py / route.py's
# DEFAULT_WORKER_MACHINE_MAPPINGS, so this script plugs into whichever
# base seed you already ran instead of creating duplicate minders.
# ---------------------------------------------------------------------
SARAH_ID = "33333333-3333-3333-3333-333333333331"   # Sarah Chen
MARCUS_ID = "33333333-3333-3333-3333-333333333332"  # Marcus Johnson
ELENA_ID = "33333333-3333-3333-3333-333333333333"   # Elena Rodriguez

PRESS_ID = "22222222-2222-2222-2222-222222222222"    # HP Indigo 12000
BINDER_ID = "22222222-2222-2222-2222-222222222224"   # Horizon BQ-470


def get_or_create_operation_type(name: str) -> str:
    existing = supabase.table("operation_types").select("id").eq("name", name).execute().data
    if existing:
        return existing[0]["id"]
    new_id = str(uuid.uuid4())
    supabase.table("operation_types").insert({"id": new_id, "name": name}).execute()
    print(f"  + operation_type '{name}'")
    return new_id


def get_or_create_resource(name: str, r_type: str, status: str = "ACTIVE") -> str:
    existing = supabase.table("resources").select("id").eq("name", name).execute().data
    if existing:
        return existing[0]["id"]
    new_id = str(uuid.uuid4())
    supabase.table("resources").insert(
        {"id": new_id, "name": name, "type": r_type, "status": status}
    ).execute()
    print(f"  + resource '{name}' ({r_type})")
    return new_id


def ensure_capability(resource_id: str, op_type_id: str, rate_per_hr: float,
                       setup_minutes: int, cost_per_hr: float, skill_level: int = 3):
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
        "skill_level": skill_level,
    }).execute()
    print(f"  + capability {resource_id[:8]} -> {op_type_id[:8]}")
    return new_id


def ensure_worker_machine_link(worker_id: str, machine_id: str):
    existing = (
        supabase.table("worker_machine_assignments")
        .select("id")
        .eq("worker_id", worker_id)
        .eq("machine_id", machine_id)
        .execute()
        .data
    )
    if existing:
        return
    supabase.table("worker_machine_assignments").insert({
        "id": str(uuid.uuid4()),
        "worker_id": worker_id,
        "machine_id": machine_id,
    }).execute()
    print(f"  + linked minder {worker_id[:8]} -> machine {machine_id[:8]}")


def clear_todays_bookings():
    """
    Opt-in cleanup so the Gantt is visibly empty right before you hit
    Optimize on stage. Only touches tasks scheduled to start TODAY and
    only resets their scheduling fields (does not delete the task or job).
    """
    print("Clearing today's SCHEDULED/IN_PROGRESS task bookings...")
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    rows = (
        supabase.table("tasks")
        .select("id, status, scheduled_start_time")
        .in_("status", ["SCHEDULED", "IN_PROGRESS"])
        .gte("scheduled_start_time", today_start.isoformat())
        .lt("scheduled_start_time", today_end.isoformat())
        .execute()
        .data
    )
    for row in rows:
        supabase.table("tasks").update({
            "status": "PENDING",
            "scheduled_start_time": None,
            "scheduled_end_time": None,
            "assigned_resource_id": None,
            "assigned_machine_id": None,
            "assigned_human_id": None,
        }).eq("id", row["id"]).execute()
    print(f"  reset {len(rows)} task(s) back to PENDING")


def main():
    clear_today = "--clear-today" in sys.argv

    print("=== OptiFlow demo seed: full sewn-book job (PRD section 6.1) ===")

    if clear_today:
        clear_todays_bookings()

    # -------------------------------------------------------------
    # 1. Operation types for the sewn-book route
    # -------------------------------------------------------------
    op_print = get_or_create_operation_type("PRINT")
    op_fold = get_or_create_operation_type("FOLD")
    op_sew = get_or_create_operation_type("SEW")
    op_cut = get_or_create_operation_type("CUT")

    # -------------------------------------------------------------
    # 2. Machines. Reuse the base seed's press/binder if present,
    #    add a folder + cutter + sewing station if missing.
    # -------------------------------------------------------------
    press = get_or_create_resource("HP Indigo 12000", "MACHINE") if not (
        supabase.table("resources").select("id").eq("id", PRESS_ID).execute().data
    ) else PRESS_ID
    folder = get_or_create_resource("Heidelberg Stahlfolder", "MACHINE")
    sewer = get_or_create_resource("Manual Sewing Station", "MACHINE")
    cutter = get_or_create_resource("Guillotine Cutter (MCGS)", "MACHINE")

    # -------------------------------------------------------------
    # 3. Minders: reuse Elena/Marcus/Sarah from create_minders.py /
    #    seed_pitch_data.py if they exist, else create fresh.
    # -------------------------------------------------------------
    def resolve_minder(fixed_id: str, name: str) -> str:
        existing = supabase.table("resources").select("id").eq("id", fixed_id).execute().data
        if existing:
            return fixed_id
        return get_or_create_resource(name, "HUMAN")

    sarah = resolve_minder(SARAH_ID, "Sarah Chen (Supervisor)")
    marcus = resolve_minder(MARCUS_ID, "Marcus Johnson (Press Operator)")
    elena = resolve_minder(ELENA_ID, "Elena Rodriguez (Bindery Tech)")

    # Wire minders to machines so worker_machine_assignments (what the
    # optimizer now reads to fill assigned_human_id) has real links.
    ensure_worker_machine_link(marcus, press)
    ensure_worker_machine_link(sarah, folder)
    ensure_worker_machine_link(elena, sewer)
    ensure_worker_machine_link(elena, cutter)

    # -------------------------------------------------------------
    # 4. Capabilities matrix (Skills Matrix). Give each op TWO
    #    candidate machines/rates where sensible so Optimize has an
    #    actual choice to make (more convincing on stage than a job
    #    with only one legal resource per task).
    # -------------------------------------------------------------
    ensure_capability(press, op_print, rate_per_hr=9000, setup_minutes=25, cost_per_hr=120, skill_level=4)
    ensure_capability(folder, op_fold, rate_per_hr=6500, setup_minutes=10, cost_per_hr=50, skill_level=3)
    ensure_capability(sewer, op_sew, rate_per_hr=800, setup_minutes=5, cost_per_hr=30, skill_level=3)
    ensure_capability(cutter, op_cut, rate_per_hr=11000, setup_minutes=10, cost_per_hr=35, skill_level=2)

    # -------------------------------------------------------------
    # 5. The job — sewn diary route per PRD 6.1.
    # -------------------------------------------------------------
    job = {
        "title": "2027 Student Diary — 5000 units (Sewn)",
        "client_name": "Lyceum International School",
        "total_quantity": 5000,
        "priority": "HIGH",
        "product_type": "DIARY",
        "deadline": (datetime.now(timezone.utc) + timedelta(days=3)).isoformat(),
        "status": "DRAFT",
        "finished_width_mm": 148,
        "finished_height_mm": 210,
        "page_count": 192,
        "inner_colour_count": 2,
        "cover_colour_count": 4,
        "print_sides": 2,
    }
    job_id = supabase.table("jobs").insert(job).execute().data[0]["id"]
    print(f"  + job '{job['title']}' ({job_id})")

    # -------------------------------------------------------------
    # 6. Tasks — Print -> [30 min dry] -> Fold -> Sew -> Cut
    # -------------------------------------------------------------
    def make_task(name, op_type_id, qty):
        return supabase.table("tasks").insert({
            "job_id": job_id,
            "operation_type_id": op_type_id,
            "name": name,
            "quantity_to_process": qty,
            "status": "PENDING",
        }).execute().data[0]["id"]

    t_print = make_task("Print Diary Signatures", op_print, 5000)
    t_fold = make_task("Fold Signatures", op_fold, 5000)
    t_sew = make_task("Sew Bindings + Attach Cover", op_sew, 5000)
    t_cut = make_task("Trim to Finished Size", op_cut, 5000)

    supabase.table("task_dependencies").insert([
        {"predecessor_task_id": t_print, "successor_task_id": t_fold,
         "mandatory_wait_minutes": 30},   # ink drying time
        {"predecessor_task_id": t_fold, "successor_task_id": t_sew,
         "mandatory_wait_minutes": 0},
        {"predecessor_task_id": t_sew, "successor_task_id": t_cut,
         "mandatory_wait_minutes": 0},
    ]).execute()

    print("  + 4 tasks wired Print -> Fold -> Sew -> Cut (DAG)")
    print()
    print("Done. Demo script:")
    print(f'  1. Jobs screen -> find "{job["title"]}" (DRAFT)')
    print("  2. Click Optimize -> CP-SAT solves live")
    print("  3. Schedule screen -> 4 bars appear across Press/Folder/Sewer/Cutter")
    print("  4. Log into mobile as marcus@optiflow.com -> Print task shows up")
    print("     Log in as sarah@optiflow.com -> Fold task shows up")
    print("     Log in as elena@optiflow.com -> Sew + Cut tasks show up")
    print()
    print("If minders still see nothing after Optimize, confirm you applied")
    print("the optimizer.py patch that writes assigned_human_id (this was")
    print("the root cause: the solver only ever wrote assigned_resource_id,")
    print("but the Flutter app filters on assigned_human_id).")


if __name__ == "__main__":
    main()
