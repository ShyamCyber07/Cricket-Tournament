import os
import sys

# Point to backend directory to resolve app imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))

# Force database URL to the production PostgreSQL database
os.environ["DATABASE_URL"] = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"

# Set APP_ENV to development to allow debug endpoint prints if needed
os.environ["APP_ENV"] = "development"

from fastapi.testclient import TestClient
from app.main import app
from app.core.database import SessionLocal
from app.models.user import User
from app.core.security import create_access_token

def diagnose():
    db = SessionLocal()
    try:
        # Find admin user in DB
        admin_user = db.query(User).filter(User.email == "cricupservice@gmail.com").first()
        if not admin_user:
            print("Admin user cricupservice@gmail.com not found in database!")
            return
        
        print(f"Found admin user: {admin_user.email} (ID: {admin_user.id}, Role: {admin_user.role})")
        
        # Generate token
        token = create_access_token(admin_user.id)
        headers = {"Authorization": f"Bearer {token}"}
        
        client = TestClient(app)
        
        endpoints = [
            "/api/v1/admin/analytics",
            "/api/v1/admin/activity-logs",
            "/api/v1/admin/users",
            f"/api/v1/admin/users/{admin_user.id}",
        ]
        
        for endpoint in endpoints:
            print("\n" + "="*50)
            print(f"Testing endpoint: {endpoint}")
            response = client.get(endpoint, headers=headers)
            print(f"Status Code: {response.status_code}")
            try:
                data = response.json()
                print("Response JSON keys/details:")
                if isinstance(data, dict):
                    for k, v in data.items():
                        # Trucate long text if any
                        val_str = str(v)
                        if len(val_str) > 500:
                            val_str = val_str[:500] + "... (truncated)"
                        print(f"  {k}: {val_str}")
                elif isinstance(data, list):
                    print(f"  List of {len(data)} items. First item: {data[0] if data else 'None'}")
                else:
                    print(f"  {data}")
            except Exception as e:
                print(f"Failed to parse JSON: {e}")
                print(f"Response Text: {response.text}")
                
    finally:
        db.close()

if __name__ == "__main__":
    diagnose()
