from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine
from app.models.cricket import Team, Player
import os
import sys

# Add backend directory to sys.path so we can import app modules
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend')))

url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
engine = create_engine(url)
Session = sessionmaker(bind=engine)
session = Session()

# Add backend app directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend')))

teams = session.query(Team).all()
print(f"Total Teams: {len(teams)}")
for t in teams:
    print(f"\nTeam: {t.name} ({t.id})")
    print(f"  Players count in relation: {len(t.players)}")
    for p in t.players:
        print(f"    - {p.name} ({p.id})")

session.close()
