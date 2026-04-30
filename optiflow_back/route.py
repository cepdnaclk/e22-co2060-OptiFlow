# =====================================================================
# IMPORTS: Bringing in the tools we need
# =====================================================================
import uuid
from datetime import datetime
from fastapi import APIRouter, HTTPException

# Import the database connection Sulakshan built
from databse import supabase 

# Import all the Pydantic data models (validation rules) Sulakshan built
from models import * # Import Rashad's optimization engine
from optimizer import run_optimization_engine 

# Create the router object. This is like a mini-FastAPI app that we can 
# plug into the main.py file later.
router = APIRouter()

# =====================================================================
# SLICE 4: OPERATION TYPES (Sulakshan)
# What kind of work can this shop do? (e.g., "Print A4", "Fold", "Bind")
# =====================================================================

@router.get("/operation-types")
def get_all_operation_types():
    """Fetches all operation types from the database."""
    res = supabase.table("operation_types").select("*").execute()
    return res.data

@router.post("/operation-types")
def create_operation_type(body: OperationTypeCreate):
    """Creates a new operation type. Validates that the name doesn't already exist."""
    # 1. Check if it already exists
    existing = supabase.table("operation_types").select("id").eq("name", body.name).execute()
    if existing.data:
        raise HTTPException(status_code=400, detail="Operation type already exists")
    
    # 2. Convert the Pydantic model into a normal Python dictionary
    data = body.model_dump()
    
    # 3. Generate a unique ID (UUID) for this new operation
    data["id"] = str(uuid.uuid4())
    
    # 4. Save to PostgreSQL
    res = supabase.table("operation_types").insert(data).execute()
    return res.data[0]

@router.put("/operation-types/{id}")
def update_operation_type(id: str, body: OperationTypeUpdate):
    """Updates an existing operation type."""
    # exclude_none=True ensures we don't accidentally overwrite good data with "null"
    res = supabase.table("operation_types").update(body.model_dump(exclude_none=True)).eq("id", id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Operation type not found")
    return res.data[0]

@router.delete("/operation-types/{id}")
def delete_operation_type(id: str):
    """Deletes an operation type."""
    supabase.table("operation_types").delete().eq("id", id).execute()
    return {"message": "Deleted successfully"}


# =====================================================================
# SLICE 4: RESOURCES (Sulakshan)
# The physical machines and human workers in the shop.
# =====================================================================

@router.get("/resources")
def get_all_resources():
    """Gets every machine and worker in the shop."""
    res = supabase.table("resources").select("*").execute()
    return res.data

@router.get("/resources/{id}")
def get_resource(id: str):
    """Gets one specific machine or worker by their ID."""
    res = supabase.table("resources").select("*").eq("id", id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Resource not found")
    return res.data[0]

@router.post("/resources")
def create_resource(body: ResourceCreate):
    """Registers a new machine or worker into the system."""
    # Hardcoded safety checks to ensure bad data doesn't enter the database
    if body.type not in ["MACHINE", "HUMAN"]:
        raise HTTPException(status_code=400, detail="Type must be 'MACHINE' or 'HUMAN'")
    if body.status not in ["ACTIVE", "IDLE", "OFFLINE"]:
        raise HTTPException(status_code=400, detail="Status must be ACTIVE, IDLE, or OFFLINE")
    
    data = body.model_dump()
    data["id"] = str(uuid.uuid4())
    res = supabase.table("resources").insert(data).execute()
    return res.data[0]

@router.put("/resources/{id}")
def update_resource(id: str, body: ResourceUpdate):
    """Updates a machine/worker (e.g., changing status from ACTIVE to BROKEN)."""
    if body.type and body.type not in ["MACHINE", "HUMAN"]:
        raise HTTPException(status_code=400, detail="Type must be 'MACHINE' or 'HUMAN'")
    if body.status and body.status not in ["ACTIVE", "IDLE", "OFFLINE"]:
        raise HTTPException(status_code=400, detail="Status must be ACTIVE, IDLE, or OFFLINE")
        
    res = supabase.table("resources").update(body.model_dump(exclude_none=True)).eq("id", id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Resource not found")
    return res.data[0]

@router.delete("/resources/{id}")
def delete_resource(id: str):
    """Removes a resource from the database entirely."""
    supabase.table("resources").delete().eq("id", id).execute()
    return {"message": "Deleted successfully"}


# =====================================================================
# SLICE 4: RESOURCE CAPABILITIES / SKILLS MATRIX (Sulakshan)
# Connecting Resources to Operation Types (e.g., "Printer A" can "Print A4")
# =====================================================================

@router.get("/capabilities")
def get_all_capabilities():
    """Gets the entire skills matrix. Notice the nested query 'resources(*)' 
       which tells Supabase to fetch the linked resource data automatically."""
    res = supabase.table("resource_capabilities").select("*, resources(*), operation_types(*)").execute()
    return res.data

@router.get("/capabilities/resource/{resource_id}")
def get_capabilities_by_resource(resource_id: str):
    """Finds out everything a specific machine or worker is capable of doing."""
    res = supabase.table("resource_capabilities").select("*, operation_types(*)").eq("resource_id", resource_id).execute()
    return res.data

@router.post("/capabilities")
def create_capability(body: CapabilityCreate):
    """Assigns a new skill/capability to a resource."""
    # Safety Check: Prevent assigning the exact same skill twice to the same person/machine
    existing = supabase.table("resource_capabilities") \
        .select("id") \
        .eq("resource_id", body.resource_id) \
        .eq("operation_type_id", body.operation_type_id) \
        .execute()
        
    if existing.data:
        raise HTTPException(status_code=400, detail="This resource already has this capability assigned")
        
    res = supabase.table("resource_capabilities").insert(body.model_dump()).execute()
    return res.data[0]

@router.put("/capabilities/{id}")
def update_capability(id: str, body: CapabilityUpdate):
    """Updates the speed or cost of a specific capability."""
    res = supabase.table("resource_capabilities").update(body.model_dump(exclude_none=True)).eq("id", id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Capability not found")
    return res.data[0]

@router.delete("/capabilities/{id}")
def delete_capability(id: str):
    """Removes a capability from a resource."""
    supabase.table("resource_capabilities").delete().eq("id", id).execute()
    return {"message": "Deleted successfully"}


# =====================================================================
# SLICE 1: RASHAD'S OPTIMIZATION ENGINE
# The brain of the operation. Triggered when the manager clicks "Optimize"
# =====================================================================

@router.post("/optimize/{job_id}")
def optimize_job(job_id: str):
    """
    Triggers the Google OR-Tools C++ solver.
    It reads the DAG, calculates the perfect schedule, and saves it to Supabase.
    """
    try:
        # Define 'time zero' for the math engine
        project_start_time = datetime.now()
        
        # Execute the heavy math algorithm from optimizer.py
        result = run_optimization_engine(job_id, project_start_time)
        
        # Check the dictionary returned by optimizer.py
        if result["status"] == "success":
            return {
                "message": "Schedule Optimized!", 
                "makespan_minutes": result["makespan_minutes"]
            }
        else:
            # If the engine returns an error (like a broken DAG), throw a 400 Bad Request
            raise HTTPException(status_code=400, detail="Could not find a valid schedule. Check constraints.")
            
    except Exception as e:
        # If the Python code crashes completely, throw a 500 Internal Server Error
        print(f"Engine Error: {str(e)}")
        raise HTTPException(status_code=500, detail="Optimization Engine Failed")


# =====================================================================
# SLICE 3: VIKASHAN'S WORKER EXECUTION
# Webhooks for the Mobile Flutter App
# =====================================================================

@router.patch("/tasks/{task_id}/status")
def update_task_status(task_id: str, body: dict):
    """
    Called by the Flutter mobile app when a worker taps "Start" or "Complete".
    Using a PATCH request because we are only updating ONE specific field (status), 
    not the entire row.
    """
    # Extract the new status from the incoming JSON payload
    status = body.get("status")
    valid_statuses = ["SCHEDULED", "IN_PROGRESS", "COMPLETED"]
    
    # Safety Check: Don't let the Flutter app send a made-up status like "DONE"
    if status not in valid_statuses:
        raise HTTPException(status_code=400, detail="Invalid status")
        
    # Ask Supabase to update just the status column for this specific task
    res = supabase.table("tasks").update({"status": status}).eq("id", task_id).execute()
    
    if not res.data:
        raise HTTPException(status_code=404, detail="Task not found")
        
    # Return success so the Flutter app knows it can update its UI
    return {"message": f"Task updated to {status}", "task": res.data[0]}