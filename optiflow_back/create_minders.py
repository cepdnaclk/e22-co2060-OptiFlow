import os
from supabase import create_client
from dotenv import load_dotenv

def create_minder_users():
    load_dotenv(".env.local")
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")

    if not url or not key:
        print("Error: Missing SUPABASE_URL or SUPABASE_KEY in .env.local")
        return

    client = create_client(url, key)
    print("Connected to Supabase. Registering 3 minders...")

    minders = [
        {
            "email": "elena@optiflow.com",
            "password": "Password123!",
            "name": "Elena Rodriguez",
            "resource_id": "33333333-3333-3333-3333-333333333333",
        },
        {
            "email": "marcus@optiflow.com",
            "password": "Password123!",
            "name": "Marcus Johnson",
            "resource_id": "33333333-3333-3333-3333-333333333332",
        },
        {
            "email": "sarah@optiflow.com",
            "password": "Password123!",
            "name": "Sarah Chen",
            "resource_id": "33333333-3333-3333-3333-333333333331",
        }
    ]

    for m in minders:
        try:
            res = client.auth.sign_up({
                "email": m["email"],
                "password": m["password"],
                "options": {
                    "data": {
                        "full_name": m["name"],
                        "resource_id": m["resource_id"]
                    }
                }
            })
            if res.user:
                print(f"[OK] User {m['name']} ({m['email']}) registered successfully.")
            else:
                print(f"[NOTE] User {m['email']} response: {res}")
        except Exception as e:
            print(f"[INFO] Could not create {m['email']}: {e}")

    print("\nDone! You can now log in on the mobile phone using:")
    print("1. Elena:  elena@optiflow.com  / Password123!")
    print("2. Marcus: marcus@optiflow.com / Password123!")
    print("3. Sarah:  sarah@optiflow.com  / Password123!")

if __name__ == "__main__":
    create_minder_users()
