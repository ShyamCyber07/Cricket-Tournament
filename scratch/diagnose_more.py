import os
import sys
import traceback

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))

os.environ["DATABASE_URL"] = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
os.environ["APP_ENV"] = "development"

from fastapi.testclient import TestClient
from app.main import app
from app.core.database import SessionLocal
from app.models.user import User
from app.core.security import create_access_token

def diagnose():
    db = SessionLocal()
    try:
        admin_user = db.query(User).filter(User.email == "cricupservice@gmail.com").first()
        if not admin_user:
            print("Admin user cricupservice@gmail.com not found!")
            return
            
        token = create_access_token(admin_user.id)
        headers = {"Authorization": f"Bearer {token}"}
        
        client = TestClient(app)
        
        endpoints = [
            "/api/v1/teams/",
            "/api/v1/admin/teams",
            "/api/v1/admin/players",
            "/api/v1/admin/tournaments",
            "/api/v1/admin/matches",
            "/api/v1/admin/reports",
            "/api/v1/admin/activity-logs"
        ]
        
        for endpoint in endpoints:
            print("\n" + "="*80)
            print(f"TESTING ENDPOINT: {endpoint}")
            try:
                response = client.get(endpoint, headers=headers)
                print(f"Status Code: {response.status_code}")
                if response.status_code == 500:
                    print("ERROR 500 Response text:")
                    print(response.text)
                elif response.status_code == 200:
                    try:
                        data = response.json()
                        print(f"Success! Returned list/dict of size {len(data)}")
                    except Exception as parse_err:
                        print(f"Response succeeded but parse error: {parse_err}")
                else:
                    print(f"Unexpected status: {response.status_code}")
                    print(response.text)
            except Exception as exc:
                print("EXCEPTION CAUGHT:")
                traceback.print_exc()
                
    finally:
        db.close()

if __name__ == "__main__":
    diagnose()
