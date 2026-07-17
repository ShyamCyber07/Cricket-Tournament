import sys
from sqlalchemy import create_engine, text

pg_url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"

try:
    engine = create_engine(pg_url)
    with engine.connect() as conn:
        print("Connected successfully!")
        
        # Get matches
        print("\n--- Matches ---")
        matches = conn.execute(
            text("""
                SELECT id, team1_id, team2_id, status, team1_squad_locked, team2_squad_locked, 
                       assigned_scorer_id, umpire_name, umpire2_name, scorer_name, toss_winner_id, toss_decision
                FROM matches
            """)
        ).mappings().all()
        for m in matches:
            t1 = conn.execute(text("SELECT name FROM teams WHERE id = :id"), {"id": m["team1_id"]}).scalar()
            t2 = conn.execute(text("SELECT name FROM teams WHERE id = :id"), {"id": m["team2_id"]}).scalar()
            print(f"Match ID: {m['id']} | {t1} vs {t2} | Status: {m['status']}")
            print(f"  Squad Locks: T1 Locked = {m['team1_squad_locked']} | T2 Locked = {m['team2_squad_locked']}")
            print(f"  Officials: Umpire1 = {m['umpire_name']} | Umpire2 = {m['umpire2_name']} | Scorer = {m['scorer_name']}")
            print(f"  Toss: Winner = {m['toss_winner_id']} | Decision = {m['toss_decision']}")
            
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
