import sys
import os

# Put backend path first
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend')))

from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine
from app.models.cricket import Team, Player

url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
engine = create_engine(url)
Session = sessionmaker(bind=engine)
session = Session()

try:
    teams = session.query(Team).all()
    print(f"Total Teams: {len(teams)}")
    for t in teams:
        print(f"\nTeam: {t.name} ({t.id}) - Owner: {t.created_by}")
        print(f"  Players count in relation: {len(t.players)}")
        for p in t.players:
            print(f"    - {p.name} ({p.id})")
except Exception as e:
    print("Database inspect failed:", e)
finally:
    session.close()
