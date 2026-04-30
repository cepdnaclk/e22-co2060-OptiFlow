import os
from datetime import datetime, timedelta
from supabase import create_client, Client

url = "https://rtqgwssnrqjjmgpnttgq.supabase.co"  
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0cWd3c3NucnFqam1ncG50dGdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTg2MDMsImV4cCI6MjA4NTE5NDYwM30.9xXUA7MxrLgPMi2P9GmcyAnbU242xRgvbmenNLg8iE4"     
supabase: Client = create_client(url, key)

# --- 2. THE BOUNCER LOGIC ---
def check_availability(machine_id, new_start_str, new_end_str):
    """
    Checks if a machine is free during the requested slot.
    Returns: True (Available), False (Conflict)
    """
    print(f"\n Checking availability for Machine...")
    
    # FIXED: Changed the comma to a period here!
    machine_info = supabase.table('machine').select("status").eq("id", machine_id).execute()
    
    if machine_info.data and machine_info.data[0]['status'] != 'ACTIVE':
        print(f"MACHINE DOWN Status is: {machine_info.data[0]['status']}")
        return False
    
    # A. Fetch all EXISTING bookings for this machine
    response = supabase.table('bookings').select("*").eq("machine_id", machine_id).execute()
    existing_bookings = response.data
    
    # B. Convert string inputs to computer time objects
    new_start = datetime.strptime(new_start_str, "%Y-%m-%d %H:%M:%S")
    new_end = datetime.strptime(new_end_str, "%Y-%m-%d %H:%M:%S")

    # C. The "Overlap" Algorithm
    for booking in existing_bookings:
        clean_start = booking['start_time'].split('+')[0].replace('T', ' ')
        clean_end = booking['end_time'].split('+')[0].replace('T', ' ')
        
        existing_start = datetime.strptime(clean_start, "%Y-%m-%d %H:%M:%S")
        existing_end = datetime.strptime(clean_end, "%Y-%m-%d %H:%M:%S")
        
        if new_start < existing_end and new_end > existing_start:
            print(f"❌ CONFLICT! Overlaps with booking: {clean_start} to {clean_end}")
            return False 

    print("✅ Slot is Clear! Booking allowed.")
    return True

def create_booking(machine_id, user_name, start_time, end_time):
    """
    Tries to save a booking ONLY if the slot is clear.
    """
    is_available = check_availability(machine_id, start_time, end_time)
    
    if is_available:
        data = {
            "machine_id": machine_id,
            "user_name": user_name,
            "start_time": start_time,
            "end_time": end_time
        }
        supabase.table('bookings').insert(data).execute()
        print(" Booking Successfully Saved to Database!")
    else:
        print("Booking Rejected: Slot is busy.")
        