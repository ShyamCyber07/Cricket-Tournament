import psycopg2

db_url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"

try:
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()
    cur.execute("SELECT id, name, status, num_teams FROM tournaments ORDER BY created_at DESC LIMIT 1;")
    tour = cur.fetchone()
    print("Latest Tournament:")
    if tour:
        tour_id, name, status, num_teams = tour
        print(f"ID: {tour_id} | Name: {name} | Status: {status} | Num Teams: {num_teams}")
        
        # Check registered teams
        cur.execute("SELECT team_id FROM tournament_teams WHERE tournament_id = %s;", (tour_id,))
        teams = cur.fetchall()
        print(f"Registered Teams Count: {len(teams)}")
        for t in teams:
            cur.execute("SELECT name FROM teams WHERE id = %s;", (t[0],))
            tname = cur.fetchone()
            print(f"  Team ID: {t[0]} | Name: {tname[0] if tname else 'Unknown'}")
            
            # Check player count in team
            cur.execute("SELECT COUNT(*) FROM team_players WHERE team_id = %s;", (t[0],))
            pcount = cur.fetchone()
            print(f"    Player Count: {pcount[0] if pcount else 0}")
        
        # Check matches
        cur.execute("SELECT id, status, match_date FROM matches WHERE tournament_id = %s;", (tour_id,))
        matches = cur.fetchall()
        print(f"Matches count: {len(matches)}")
        for m in matches:
            print(f"  Match ID: {m[0]} | Status: {m[1]} | Date: {m[2]}")
    else:
        print("No tournament found.")
    cur.close()
    conn.close()
except Exception as e:
    print("Query failed:", e)

