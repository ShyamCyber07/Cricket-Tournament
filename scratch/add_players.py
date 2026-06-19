import sqlite3
import uuid
from datetime import datetime, timezone

DB_PATH = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"

def add_players():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 1. Fetch all teams
    cursor.execute("SELECT id, name, created_by FROM teams")
    teams = cursor.fetchall()
    print(f"Found teams: {teams}")
    
    for team_id, team_name, created_by in teams:
        # Check current players in this team
        cursor.execute("SELECT COUNT(*) FROM team_players WHERE team_id = ?", (team_id,))
        count = cursor.fetchone()[0]
        print(f"Team '{team_name}' currently has {count} players.")
        
        needed = 5 - count
        if needed > 0:
            print(f"Adding {needed} players to '{team_name}'...")
            for i in range(needed):
                player_id = str(uuid.uuid4())
                player_name = f"Player {i+1} of {team_name}"
                role = "all_rounder"
                batting_style = "right_hand"
                bowling_style = "right_arm_fast"
                
                # Insert player
                cursor.execute(
                    "INSERT INTO players (id, created_by, name, role, batting_style, bowling_style) VALUES (?, ?, ?, ?, ?, ?)",
                    (player_id, created_by, player_name, role, batting_style, bowling_style)
                )
                
                # Insert team association
                joined_at = datetime.now(timezone.utc).isoformat()
                cursor.execute(
                    "INSERT INTO team_players (team_id, player_id, joined_at) VALUES (?, ?, ?)",
                    (team_id, player_id, joined_at)
                )
                
            print(f"Added players to '{team_name}'.")
            
    conn.commit()
    conn.close()
    print("Database committed successfully.")

if __name__ == "__main__":
    add_players()
