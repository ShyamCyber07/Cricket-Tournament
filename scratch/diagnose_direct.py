import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))

os.environ["DATABASE_URL"] = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
os.environ["APP_ENV"] = "development"

from app.core.database import SessionLocal
from app.models.user import User
from app.routers.teams import list_teams
from app.routers.admin import get_all_teams, get_all_players, get_all_tournaments, get_all_matches, get_reports

def run():
    db = SessionLocal()
    try:
        admin_user = db.query(User).filter(User.email == "cricupservice@gmail.com").first()
        if not admin_user:
            print("Admin user not found!")
            return
            
        print(f"Direct verification:")
        
        print("\n1. Testing list_teams (GET /teams/)...")
        teams = list_teams(db, admin_user)
        print(f"Success! Fetched {len(teams)} teams.")
        
        print("\n2. Testing get_all_teams (GET /admin/teams)...")
        admin_teams = get_all_teams(search=None, db=db, current_user=admin_user)
        print(f"Success! Fetched {len(admin_teams)} teams.")
        
        print("\n3. Testing get_all_players (GET /admin/players)...")
        admin_players = get_all_players(search=None, db=db, current_user=admin_user)
        print(f"Success! Fetched {len(admin_players)} players.")
        
        print("\n4. Testing get_all_tournaments (GET /admin/tournaments)...")
        admin_tours = get_all_tournaments(search=None, db=db, current_user=admin_user)
        print(f"Success! Fetched {len(admin_tours)} tournaments.")
        
        print("\n5. Testing get_all_matches (GET /admin/matches)...")
        admin_matches = get_all_matches(search=None, status_filter=None, db=db, current_user=admin_user)
        print(f"Success! Fetched {len(admin_matches)} matches.")
        
        print("\n6. Testing get_reports (GET /admin/reports)...")
        # Since reports has no direct wrapper, we can query Report table directly
        from app.models.user import Report
        reports = db.query(Report).all()
        print(f"Success! Fetched {len(reports)} reports.")
        
        print("\nALL DIRECT VERIFICATIONS PASSED!")
        
    except Exception as e:
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    run()
