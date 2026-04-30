# =====================================================================
# IMPORTS: The core building blocks of our web server
# =====================================================================
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List
import traceback

from booking_manager import check_availability, supabase

# Here we import the "router" object we just built in routes.py.
# Think of the router as a giant power strip that holds all our endpoints.
from route import router 

# =====================================================================
# 1. APPLICATION BOOTSTRAP
# =====================================================================
# This line creates the actual web server. When uvicorn runs, it looks 
# specifically for this 'app' variable.
app = FastAPI(
    title="OptiFlow Enterprise API",
    description="The centralized backend for the OptiFlow Print Shop Scheduler.",
    version="2.0.0"
)

# =====================================================================
# 2. CORS MIDDLEWARE (The Security Guard)
# =====================================================================
# "Middleware" is code that runs before your actual API endpoints do.
# CORS (Cross-Origin Resource Sharing) is a browser security feature.
# By default, a web browser (or Flutter web app) running on localhost:3000 
# is mathematically forbidden from talking to an API on localhost:8000.
app.add_middleware(
    CORSMiddleware,
    # allow_origins=["*"] means "Let ANY website or app talk to this API." 
    # For production, you would change this to your specific Flutter web URL.
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"], # Allow GET, POST, PUT, PATCH, DELETE
    allow_headers=["*"], # Allow all types of data headers
)

# =====================================================================
# 3. GLOBAL EXCEPTION HANDLER (The Safety Net)
# =====================================================================
# If your C++ engine crashes, or a database query fails, Python usually 
# panics and stops the server. This decorator catches ANY completely 
# unhandled error before it kills the server.
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    # traceback.format_exc() gets the exact line number and error message
    error_detail = traceback.format_exc()
    
    # Print it to the terminal so YOU (the developer) can fix it
    print("CRITICAL SERVER ERROR:\n", error_detail)
    
    # Send a clean 500 error code back to the Flutter app so it doesn't 
    # freeze, but instead shows a "Server Offline" message to the user.
    return JSONResponse(status_code=500, content={"detail": "Internal Server Error. The engineering team has been notified."})

# =====================================================================
# 4. ROUTER INCLUSION (The Traffic Director)
# =====================================================================
# Instead of writing all 50 of our API endpoints in this one file (which 
# would be a nightmare to read), we wrote them in routes.py. 
# This line plugs that "power strip" into the main server.
# The prefix="/api" means every route automatically gets /api added to it.
# (e.g., "/resources" becomes "/api/resources")
app.include_router(router, prefix="/api")

# =====================================================================
# 5. ROOT ENDPOINT (The Pulse Check)
# =====================================================================
# A very simple route just to check if the server is awake.
@app.get("/")
def root():
    return {"message": "OptiFlow Enterprise Engine is Online and Ready. ✅"}

# Keep these original models
class BookingRequest(BaseModel):
    machine_id: str
    user_name: str
    start_time: str
    end_time: str

class JobClaimRequest(BaseModel):
    job_id: str
    student_name: str  

class MachineStatusUpdate(BaseModel):
    status: str

class MachineCreateRequest(BaseModel):
    name: str
    status: str
    price_per_hour: int
    image_url: str

class JobSubmission(BaseModel):
    proof_url: str
    notes: str

class JobStatusUpdate(BaseModel):
    status: str 

# --- NEW OPTIFLOW MODELS (Sadurshika's Task) ---

class TaskDependencyInput(BaseModel):
    predecessor_index: int 
    successor_index: int
    mandatory_wait_minutes: Optional[int] = 0

class TaskInput(BaseModel):
    operation_type_id: Optional[str] = None
    name: str
    quantity_to_process: int

class JobOrderInput(BaseModel):
    title: str
    client_name: Optional[str] = None
    total_quantity: int
    deadline: str 
    created_by: Optional[str] = None
    tasks: List[TaskInput]
    dependencies: List[TaskDependencyInput]

# --- INDIVIDUAL CRUD MODELS ---

class SingleJobInput(BaseModel):
    title: str
    client_name: Optional[str] = None
    total_quantity: int
    deadline: str 
    created_by: str 

class SingleTaskInput(BaseModel):
    job_id: str  # Notice this requires the Job ID so it knows where to attach!
    operation_type_id: str 
    name: str
    quantity_to_process: int


# ------------------- ROOT -------------------

@app.get("/")
def read_root():
    return {"status": "Backend is working."}


# ------------------- MACHINE BOOKING -------------------

@app.post("/book_machine")
def book_machine(request: BookingRequest):
    print(f"Receive request for {request.user_name}")

    is_clear = check_availability(
        request.machine_id,
        request.start_time,
        request.end_time
    )

    if not is_clear:
        raise HTTPException(status_code=400, detail="Slot is already booked!")

    data_to_save = {
        "machine_id": request.machine_id,
        "user_name": request.user_name,
        "start_time": request.start_time,
        "end_time": request.end_time
    }

    supabase.table("bookings").insert(data_to_save).execute()

    return {
        "message": "Booking Confirmed!",
        "saved_data": data_to_save
    }


# ------------------- JOB BOARD -------------------

@app.get("/jobs")
def get_jobs(status: Optional[str] = None):
    query = supabase.table('jobs').select("*")

    if status:
        print(f"Filtering jobs by status: {status}")
        query = query.eq("status", status)

    response = query.execute()
    return {"count": len(response.data), "jobs": response.data}


@app.post("/claim_job")
def claim_job(request: JobClaimRequest):
    print(f"Claim request from {request.student_name} for job {request.job_id}")

    try:
        response = (
            supabase
            .table("jobs")
            .select("*")
            .eq("id", request.job_id)
            .eq("status", "OPEN")
            .execute()
        )

        if not response.data:
            raise HTTPException(status_code=400, detail="Job is already taken.")

        update_data = {
            "status": "TAKEN",
            "assigned_to": request.student_name
        }

        supabase.table("jobs").update(update_data).eq("id", request.job_id).execute()

        return {
            "message": "Job Claimed! Get to work.",
            "job_id": request.job_id
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


# --- NEW OPTIFLOW COMPLEX JOB CREATION (Sadurshika's Task) ---

@app.post("/create_job")
def create_job(order: JobOrderInput):
    print(f"Manager is posting a new complex job: {order.title}")

    try:
        # Prevent foreign key constraint errors if using the dummy UI UUID
        safe_created_by = order.created_by if order.created_by != "11111111-1111-1111-1111-111111111111" else None

        # 1. Insert into the 'jobs' table
        new_job_data = {
            "title": order.title,
            "client_name": order.client_name,
            "total_quantity": order.total_quantity,
            "deadline": order.deadline,
            "created_by": safe_created_by,
            "status": "DRAFT" 
        }
        job_response = supabase.table("jobs").insert(new_job_data).execute()
        new_job_id = job_response.data[0]['id'] 
        
        # 2. Insert into the 'tasks' table
        task_uuid_map = {} 
        
        for index, task in enumerate(order.tasks):
            # Prevent foreign key constraint errors for dummy UI operation types by using a valid fallback UUID
            safe_op_id = task.operation_type_id if len(str(task.operation_type_id)) > 5 else "baa49214-b20a-461f-baf8-da09a83345fd"
            
            task_data = {
                "job_id": new_job_id,
                "operation_type_id": safe_op_id,
                "name": task.name,
                "quantity_to_process": task.quantity_to_process,
                "status": "PENDING"
            }
            task_response = supabase.table("tasks").insert(task_data).execute()
            task_uuid_map[index] = task_response.data[0]['id'] 
            
        # 3. Insert into the 'task_dependencies' table (The DAG)
        dependency_inserts = []
        for dep in order.dependencies:
            dep_data = {
                "predecessor_task_id": task_uuid_map[dep.predecessor_index],
                "successor_task_id": task_uuid_map[dep.successor_index],
                "mandatory_wait_minutes": dep.mandatory_wait_minutes
            }
            dependency_inserts.append(dep_data)
            
        if dependency_inserts:
            supabase.table("task_dependencies").insert(dependency_inserts).execute()
            
        return {
            "message": "Job Order and workflow successfully created!", 
            "job_id": new_job_id
        }

    except Exception as e:
        print(f"ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/jobs")
def create_single_job(job: SingleJobInput):
    print(f"Creating standalone job: {job.title}")
    try:
        job_data = {
            "title": job.title,
            "client_name": job.client_name,
            "total_quantity": job.total_quantity,
            "deadline": job.deadline,
            "created_by": job.created_by,
            "status": "DRAFT"
        }
        response = supabase.table("jobs").insert(job_data).execute()
        
        return {
            "message": "Job successfully created!",
            "job_id": response.data[0]['id']
        }
    except Exception as e:
        print(f"ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to create /api/jobs")

@app.post("/api/tasks")
def create_single_task(task: SingleTaskInput):
    print(f"Adding task {task.name} to Job {task.job_id}")
    try:
        task_data = {
            "job_id": task.job_id,
            "operation_type_id": task.operation_type_id,
            "name": task.name,
            "quantity_to_process": task.quantity_to_process,
            "status": "PENDING"
        }
        response = supabase.table("tasks").insert(task_data).execute()
        
        return {
            "message": "Task successfully added to job!",
            "task_id": response.data[0]['id']
        }
    except Exception as e:
        print(f"ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to create /api/tasks")



# ------------------- MACHINES -------------------

@app.patch("/machines/{machine_id}")
def update_machine_status(machine_id: str, update: MachineStatusUpdate):
    print(f"Updating Machine {machine_id} to {update.status}")

    try:
        response = (
            supabase
            .table("machines")
            .update({"status": update.status})
            .eq("id", machine_id)
            .execute()
        )

        return {
            "message": "Status Updated!",
            "data": response.data
        }

    except Exception as e:
        print(f"ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


@app.get("/machines")
def get_machines():
    try:
        response = supabase.table("resources").select("*").execute()
        return {"machines": response.data}
    except Exception as e:
        print(f"ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


@app.post("/create_machine")
def create_machine(machine: MachineCreateRequest):
    print(f"Create a new machine: {machine.name}")

    try:
        new_machine_data = {
            "name": machine.name,
            "status": machine.status,
            "price_per_hour": machine.price_per_hour,
            "image_url": machine.image_url
        }

        response = supabase.table("machines").insert(new_machine_data).execute()

        return {
            "message": "Machine Registered.",
            "machine_details": response.data
        }

    except Exception as e:
        print(f"ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


# ------------------- JOB SUBMISSION -------------------

@app.post("/jobs/{job_id}/submit")
def submit_job(job_id: str, submission: JobSubmission):
    print(f"Job {job_id} submitted for review")

    try:
        response = (
            supabase
            .table("jobs")
            .update({
                "status": "REVIEW",
                "proof_url": submission.proof_url,
                "worker_notes": submission.notes
            })
            .eq("id", job_id)
            .execute()
        )

        return {
            "message": "Great work! Manager will review it.",
            "data": response.data
        }

    except Exception as e:
        print(f"ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal Server Error")


@app.patch("/jobs/{job_id}")
def update_job_status(job_id: str, update: JobStatusUpdate):
    response = supabase.table('jobs').update({"status": update.status}).eq("id", job_id).execute()
    return {"message": "Job Status Updated", "data": response.data}
