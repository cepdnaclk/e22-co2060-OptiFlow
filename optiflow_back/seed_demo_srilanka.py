"""
seed_demo_srilanka.py

CLEAN-SLATE demo seed. Deletes all prior demo jobs/tasks/resources/
capabilities/minder-links, then rebuilds everything with:

  1. The shop's ACTUAL machines (edit REAL_MACHINES below with the names
     you confirmed on-site — this is the one thing you must fill in).
  2. Sri Lankan minder names, each with a Supabase Auth login so they can
     sign into the mobile app.
  3. Every machine linked to at least one minder in
     worker_machine_assignments — this is what lets the optimizer (after
     the assigned_human_id patch) actually put a task on someone's phone.
     A machine with NO minder linked to it is a machine the solver can
     schedule work onto but nobody will ever be notified about — this
     script asserts that can't happen before it finishes.
  4. Two DRAFT jobs in Sri Lankan print-shop context (exam past papers
     and a school diary) built from the PRD's real routes, ready to
     Optimize live on stage.

WHY THIS FIXES "no minder assigned" 
-------------------------------------
A task never gets assigned DIRECTLY to a minder by the optimizer for a
machine operation — the solver picks a MACHINE, then (per the
optimizer.py patch) looks up who operates that machine via
worker_machine_assignments and fills assigned_human_id from there. If a
machine has zero rows in worker_machine_assignments, that lookup returns
nothing, assigned_human_id stays NULL, and no phone gets the task — the
Gantt will still look correct because assigned_machine_id is set, which
is exactly the "job looks scheduled but no one got notified" symptom.
This script guarantees that can't happen by refusing to finish if any
machine used by a task ends up with no linked minder.

RUN FROM optiflow_back/:
    python seed_demo_srilanka.py
Add --wipe to actually delete existing demo data first (safe default is
to run without it once, review what it WOULD delete, then re-run with
--wipe once you're happy):
    python seed_demo_srilanka.py --wipe
"""
import sys
import uuid
from datetime import datetime, timedelta, timezone
from databse import supabase


# =======================================================================
# EDIT THIS SECTION with the machines you confirmed at the shop.
# name       -> what shows on the Gantt / mobile app
# category   -> one of PRINT, FOLD, SEW, PERFECT_BIND, CUT (matches PRD
#               machine_category in machine_specs, informational only
#               here — the operation_type below is what actually drives
#               the scheduler)
# op_type    -> operation_types.name this machine performs
# rate_hr    -> processing_rate_per_hr for its capability row
# setup_min  -> setup_time_minutes
# cost_hr    -> cost_per_hour
# =======================================================================
REAL_MACHINES = [
    # name                              category       op_type   rate_hr  setup_min  cost_hr
    ("Heidelberg SORM (Press 1)",        "PRINT",       "PRINT",  8000,    20,        100),
    ("Heidelberg SORMZ (Press 2)",       "PRINT",       "PRINT",  9500,    25,        130),
    ("Heidelberg Stahlfolder",           "FOLD",        "FOLD",   6000,    10,        45),
    ("Horizon Perfect Binder",           "PERFECT_BIND","PERFECT_BIND", 4000, 15,     60),
    ("Manual Sewing Station",            "SEW",         "SEW",    800,     5,         30),
    ("Guillotine Cutter (MCGS)",         "CUT",         "CUT",    10000,   10,        35),
]

# =======================================================================
# Sri Lankan minders. Each gets a resources row (type=HUMAN) + a
# Supabase Auth login so they can sign into the mobile app, matching the
# pattern in create_minders.py.
# machines: list of REAL_MACHINES names (above) this minder is
#           authorised to operate — must reference names exactly as
#           spelled above.
# =======================================================================
MINDERS = [
    {
        "email": "kasun@optiflow.lk",
        "password": "Password123!",
        "name": "Kasun Perera",
        "machines": ["Heidelberg SORM (Press 1)"],
    },
    {
        "email": "nadeesha@optiflow.lk",
        "password": "Password123!",
        "name": "Nadeesha Wickramasinghe",
        "machines": ["Heidelberg SORMZ (Press 2)"],
    },
    {
        "email": "chamara@optiflow.lk",
        "password": "Password123!",
        "name": "Chamara Fernando",
        "machines": ["Heidelberg Stahlfolder", "Guillotine Cutter (MCGS)"],
    },
    {
        "email": "dilani@optiflow.lk",
        "password": "Password123!",
        "name": "Dilani Rajapaksha",
        "machines": ["Horizon Perfect Binder", "Manual Sewing Station"],
    },
]


# =======================================================================
# DEMO JOBS — Sri Lankan print-shop context, following the PRD's own
# routes (sections 6.1 / 6.3). Each op_type below must exist in
# REAL_MACHINES above or the job will be built with a missing
# capability and the optimizer will reject it — the script checks this
# up front and tells you exactly what's missing before inserting
# anything.
# =======================================================================
DEMO_JOBS = [
    {
        "title": "G.C.E. O/L Model Papers — Zonal Education Office, Kandy",
        "client_name": "Zonal Education Office, Kandy",
        "total_quantity": 3000,
        "priority": "URGENT",
        "product_type": "MODEL_PAPER",
        "deadline_days": 2,
        "route": [  # (task name, op_type, wait_minutes_before_this_task)
            ("Print O/L Model Paper Sheets", "PRINT", 0),
            ("Fold Signatures", "FOLD", 30),  # 30 min drying wait
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
    {
        "title": "2027 School Diary — 4000 units, Ananda College",
        "client_name": "Ananda College, Colombo",
        "total_quantity": 4000,
        "priority": "HIGH",
        "product_type": "DIARY",
        "deadline_days": 4,
        "extra_fields": {
            "finished_width_mm": 148,
            "finished_height_mm": 210,
            "page_count": 192,
            "inner_colour_count": 2,
            "cover_colour_count": 4,
            "print_sides": 2,
        },
        "route": [
            ("Print Diary Signatures", "PRINT", 0),
            ("Fold Signatures", "FOLD", 30),
            ("Sew Bindings + Attach Cover", "SEW", 0),
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
    {
        "title": "Grade 5 Scholarship Past Papers — Gampaha District",
        "client_name": "Gampaha District Education Office",
        "total_quantity": 5000,
        "priority": "URGENT",
        "product_type": "PAST_PAPER",
        "deadline_days": 1,
        "route": [
            ("Print Scholarship Past Paper Sheets", "PRINT", 0),
            ("Fold Signatures", "FOLD", 30),
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
    {
        "title": "Perfect-Bound Revision Book — 2500 units, Royal Institute",
        "client_name": "Royal Institute, Colombo",
        "total_quantity": 2500,
        "priority": "MEDIUM",
        "product_type": "BOOK",
        "deadline_days": 5,
        "extra_fields": {
            "finished_width_mm": 210,
            "finished_height_mm": 297,
            "page_count": 260,
            "inner_colour_count": 1,
            "cover_colour_count": 4,
            "print_sides": 2,
        },
        "route": [
            ("Print Book Signatures", "PRINT", 0),
            ("Fold Signatures", "FOLD", 30),
            ("Perfect Bind + Cover Glue", "PERFECT_BIND", 0),
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
    {
        "title": "Wedding Invitation Cards — 1000 units, Private Order (Nugegoda)",
        "client_name": "Private Customer — Nugegoda",
        "total_quantity": 1000,
        "priority": "LOW",
        "product_type": "OTHER",
        "deadline_days": 6,
        "extra_fields": {
            "cover_colour_count": 4,
            "print_sides": 1,
        },
        "route": [
            ("Print Invitation Cards", "PRINT", 0),
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
    {
        "title": "G.C.E. A/L Model Papers — Zonal Education Office, Gampaha",
        "client_name": "Zonal Education Office, Gampaha",
        "total_quantity": 2800,
        "priority": "URGENT",
        "product_type": "MODEL_PAPER",
        "deadline_days": 1,
        "route": [
            ("Print A/L Model Paper Sheets", "PRINT", 0),
            ("Fold Signatures", "FOLD", 30),
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
    {
        "title": "Term Test Papers — Visakha Vidyalaya, Colombo",
        "client_name": "Visakha Vidyalaya",
        "total_quantity": 1800,
        "priority": "HIGH",
        "product_type": "PAST_PAPER",
        "deadline_days": 2,
        "route": [
            ("Print Term Test Sheets", "PRINT", 0),
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
    {
        "title": "2027 Office Planner — 1500 units, Commercial Bank HR Dept",
        "client_name": "Commercial Bank of Ceylon — HR Department",
        "total_quantity": 1500,
        "priority": "MEDIUM",
        "product_type": "DIARY",
        "deadline_days": 5,
        "extra_fields": {
            "finished_width_mm": 210,
            "finished_height_mm": 148,
            "page_count": 160,
            "inner_colour_count": 2,
            "cover_colour_count": 4,
            "print_sides": 2,
        },
        "route": [
            ("Print Planner Signatures", "PRINT", 0),
            ("Fold Signatures", "FOLD", 30),
            ("Sew Bindings + Attach Cover", "SEW", 0),
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
    {
        "title": "Perfect-Bound Tuition Guide — 3200 units, Nolimit Campus",
        "client_name": "Nolimit Campus, Maharagama",
        "total_quantity": 3200,
        "priority": "HIGH",
        "product_type": "BOOK",
        "deadline_days": 3,
        "extra_fields": {
            "finished_width_mm": 210,
            "finished_height_mm": 297,
            "page_count": 180,
            "inner_colour_count": 1,
            "cover_colour_count": 2,
            "print_sides": 2,
        },
        "route": [
            ("Print Guide Signatures", "PRINT", 0),
            ("Fold Signatures", "FOLD", 30),
            ("Perfect Bind + Cover Glue", "PERFECT_BIND", 0),
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
    {
        "title": "Birthday Party Invitation Cards — 600 units, Private Order (Dehiwala)",
        "client_name": "Private Customer — Dehiwala",
        "total_quantity": 600,
        "priority": "LOW",
        "product_type": "OTHER",
        "deadline_days": 7,
        "route": [
            ("Print Invitation Cards", "PRINT", 0),
            ("Trim to Finished Size", "CUT", 0),
        ],
    },
]


# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------

def wipe_demo_data():
    print("Wiping existing demo data...")
    # Order matters: children before parents (FK constraints).
    tables_in_order = [
        "task_dependencies",
        "task_allowed_resources",
        "tasks",
        "jobs",
        "resource_capabilities",
        "worker_machine_assignments",
        "machine_specs",
        "resources",
        "operation_types",
    ]
    for table in tables_in_order:
        try:
            supabase.table(table).delete().neq(
                "id" if table != "task_dependencies" else "id",
                "00000000-0000-0000-0000-000000000000",
            ).execute()
            print(f"  cleared {table}")
        except Exception as e:
            print(f"  skipped {table}: {e}")


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


def ensure_capability(resource_id, op_type_id, rate_per_hr, setup_minutes, cost_per_hr, skill_level=3):
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


def ensure_worker_machine_link(worker_id, machine_id):
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


def register_minder_auth(email, password, name, resource_id):
    try:
        res = supabase.auth.sign_up({
            "email": email,
            "password": password,
            "options": {"data": {"full_name": name, "resource_id": resource_id}},
        })
        if res.user:
            print(f"  + Supabase Auth login created for {name} ({email})")
        else:
            print(f"  ? Auth sign_up returned no user for {email}: {res}")
    except Exception as e:
        # Most common cause: already registered — fine, not fatal.
        print(f"  [note] could not create auth login for {email} (likely already exists): {e}")


def main():
    do_wipe = "--wipe" in sys.argv

    print("=== OptiFlow Sri Lanka demo seed ===\n")

    if do_wipe:
        wipe_demo_data()
        print()
    else:
        print("Running WITHOUT --wipe: existing rows are kept, everything below")
        print("is created idempotently (looked up by name first). Re-run with")
        print("--wipe for a true clean slate.\n")

    # -------------------------------------------------------------
    # 1. Machines
    # -------------------------------------------------------------
    print("Machines:")
    machine_ids = {}       # name -> resource id
    op_type_ids = {}       # op_type name -> operation_type id
    for name, category, op_type_name, rate_hr, setup_min, cost_hr in REAL_MACHINES:
        m_id = get_or_create_resource(name, "MACHINE")
        machine_ids[name] = m_id
        op_id = op_type_ids.get(op_type_name) or get_or_create_operation_type(op_type_name)
        op_type_ids[op_type_name] = op_id
        ensure_capability(m_id, op_id, rate_hr, setup_min, cost_hr)
    print()

    # -------------------------------------------------------------
    # 2. Minders — resources + Supabase Auth + worker_machine_assignments
    # -------------------------------------------------------------
    print("Minders:")
    minder_ids = {}  # name -> resource id
    for m in MINDERS:
        r_id = get_or_create_resource(m["name"], "HUMAN")
        minder_ids[m["name"]] = r_id
        register_minder_auth(m["email"], m["password"], m["name"], r_id)
        for machine_name in m["machines"]:
            if machine_name not in machine_ids:
                raise SystemExit(
                    f"ERROR: minder '{m['name']}' references machine "
                    f"'{machine_name}' which is not in REAL_MACHINES. "
                    f"Fix the spelling or add it to REAL_MACHINES."
                )
            ensure_worker_machine_link(r_id, machine_ids[machine_name])
    print()

    # -------------------------------------------------------------
    # 3. Safety check: every machine must have at least one minder,
    #    or tasks scheduled onto it can never reach a phone.
    # -------------------------------------------------------------
    print("Checking every machine has a minder linked...")
    unlinked = []
    for name, m_id in machine_ids.items():
        links = (
            supabase.table("worker_machine_assignments")
            .select("id")
            .eq("machine_id", m_id)
            .execute()
            .data
        )
        if not links:
            unlinked.append(name)
    if unlinked:
        raise SystemExit(
            "ERROR: these machines have NO minder assigned — tasks scheduled "
            "onto them will show on the Gantt but notify nobody:\n  - "
            + "\n  - ".join(unlinked)
            + "\nAdd them to a minder's \"machines\" list in MINDERS above and re-run."
        )
    print("  OK — every machine has at least one minder.\n")

    # -------------------------------------------------------------
    # 4. Jobs
    # -------------------------------------------------------------
    print("Jobs:")
    for job_def in DEMO_JOBS:
        # Verify every op_type this job's route needs actually has a
        # capability somewhere before inserting — fail loud, not silent.
        missing_ops = [op for _, op, _ in job_def["route"] if op not in op_type_ids]
        if missing_ops:
            raise SystemExit(
                f"ERROR: job '{job_def['title']}' needs operation type(s) "
                f"{missing_ops} but no machine in REAL_MACHINES performs "
                f"them. Add a machine for that operation type first."
            )

        job_row = {
            "title": job_def["title"],
            "client_name": job_def["client_name"],
            "total_quantity": job_def["total_quantity"],
            "priority": job_def["priority"],
            "product_type": job_def["product_type"],
            "deadline": (datetime.now(timezone.utc) + timedelta(days=job_def["deadline_days"])).isoformat(),
            "status": "DRAFT",
            **job_def.get("extra_fields", {}),
        }
        job_id = supabase.table("jobs").insert(job_row).execute().data[0]["id"]
        print(f"  + job '{job_def['title']}' ({job_id})")

        prev_task_id = None
        for task_name, op_type_name, wait_minutes in job_def["route"]:
            task_id = supabase.table("tasks").insert({
                "job_id": job_id,
                "operation_type_id": op_type_ids[op_type_name],
                "name": task_name,
                "quantity_to_process": job_def["total_quantity"],
                "status": "PENDING",
            }).execute().data[0]["id"]

            if prev_task_id is not None:
                supabase.table("task_dependencies").insert({
                    "predecessor_task_id": prev_task_id,
                    "successor_task_id": task_id,
                    "mandatory_wait_minutes": wait_minutes,
                }).execute()
            prev_task_id = task_id

        print(f"    {len(job_def['route'])} tasks wired: "
              + " -> ".join(name for name, _, _ in job_def["route"]))
    print()

    print("Done. Demo script:")
    print("  1. Jobs screen -> pick either DRAFT job -> Optimize")
    print("  2. Schedule screen -> bars appear across the real machines")
    print("  3. Log into mobile as one of:")
    for m in MINDERS:
        print(f"       {m['email']} / {m['password']}  ({m['name']})")
    print("     -> that minder's linked machine's tasks should appear")
    print()
    print("If a minder's phone is still empty after Optimize, confirm the")
    print("optimizer.py patch (writes assigned_human_id via")
    print("worker_machine_assignments) is applied — this script only")
    print("guarantees the DATA side (every machine has a linked minder);")
    print("it can't fix the optimizer code itself if the patch isn't in.")


if __name__ == "__main__":
    main()
