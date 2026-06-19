import sqlite3
import uuid
from datetime import datetime, timezone

DB_PATH = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"

def fix_players():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 1. Delete previously added dummy players
    # We can identify them by names starting with "Player "
    cursor.execute("SELECT id FROM players WHERE name LIKE 'Player %'")
    player_ids = [row[0] for row in cursor.fetchall()]
    print(f"Deleting {len(player_ids)} old players: {player_ids}")
    
    for pid in player_ids:
        cursor.execute("DELETE FROM team_players WHERE player_id = ?", (pid,))
        cursor.execute("DELETE FROM players WHERE id = ?", (pid,))
        
    # 2. Fetch teams
    cursor.execute("SELECT id, name, created_by FROM teams")
    teams = cursor.fetchall()
    
    for team_id, team_name, created_by in teams:
        # Check current players in this team
        cursor.execute("SELECT COUNT(*) FROM team_players WHERE team_id = ?", (team_id,))
        count = cursor.fetchone()[0]
        print(f"Team '{team_name}' currently has {count} players.")
        
        needed = 5 - count
        if needed > 0:
            print(f"Adding {needed} hex-players to '{team_name}'...")
            for i in range(needed):
                # Use uuid.uuid4().hex (32 chars, no dashes)
                player_id = uuid.uuid4().hex
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
                
            print(f"Added hex-players to '{team_name}'.")
            
    conn.commit()
    conn.close()
    print("Database fixed and committed successfully.")

if __name__ == "__main__":
    fix_players()
