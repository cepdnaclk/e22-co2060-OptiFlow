from pydantic import BaseModel, Field
from typing import Optional

# =====================================================================
# PYDANTIC MODELS (Data Validation & Security)
# These classes define the exact "shape" the JSON data must have.
# =====================================================================

# ─────────────────────────────────────────
# OPERATION TYPES
# ─────────────────────────────────────────

class OperationTypeCreate(BaseModel):
    """Used when creating a new operation (e.g., POST request). Name is strictly required."""
    name: str

class OperationTypeUpdate(BaseModel):
    """Used when updating (PUT request). Name is optional because 
       you might not want to change it during an update."""
    name: Optional[str] = None


# ─────────────────────────────────────────
# RESOURCES (Machines & Workers)
# ─────────────────────────────────────────

class ResourceCreate(BaseModel):
    """Defines the exact shape of data needed to register a machine/worker."""
    name: str
    type: str
    # If the Flutter app forgets to send a status, the API won't crash. 
    # It will safely and automatically default to "ACTIVE".
    status: Optional[str] = "ACTIVE"

class ResourceUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[str] = None
    status: Optional[str] = None


# ─────────────────────────────────────────
# CAPABILITIES (The Skills Matrix)
# ─────────────────────────────────────────

class CapabilityCreate(BaseModel):
    """This is critical for your math engine. It forces the Flutter app to 
       provide strictly valid numbers for processing speed and cost."""
    resource_id: str
    operation_type_id: str
    
    # Field(..., gt=0) means: This field is REQUIRED (...), and it 
    # MUST be Greater Than Zero (gt=0). If the Flutter app sends 
    # "-50" or "0" for the processing rate, Pydantic will instantly 
    # block the request and return a 422 Unprocessable Entity error.
    processing_rate_per_hr: float = Field(..., gt=0)
    
    setup_time_minutes: Optional[int] = 0
    
    # Cost per hour must also be strictly positive.
    cost_per_hour: float = Field(..., gt=0)

class CapabilityUpdate(BaseModel):
    processing_rate_per_hr: Optional[float] = Field(None, gt=0)
    setup_time_minutes: Optional[int] = None
    cost_per_hour: Optional[float] = Field(None, gt=0)

class OptimizationRequest(BaseModel):
    # If the Flutter app doesn't send them, default to 70% Time / 30% Cost
    alpha: int = 70  
    beta: int = 30


# ─────────────────────────────────────────
# WORKER MACHINE ASSIGNMENTS
# ─────────────────────────────────────────

class WorkerMachineAssignmentCreate(BaseModel):
    worker_id: str
    machine_id: str