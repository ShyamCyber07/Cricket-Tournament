import psycopg2

url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
conn = psycopg2.connect(url)
cur = conn.cursor()

# Get all teams
cur.execute("SELECT id, name FROM teams;")
teams = cur.fetchall()
print("=== Teams ===")
for t in teams:
    print(f"Team ID: {t[0]} | Name: {t[1]}")

# Get all team_players relations
cur.execute("SELECT team_id, player_id FROM team_players;")
relations = cur.fetchall()
print("\n=== Team Player Relations ===")
for r in relations:
    print(f"Team ID: {r[0]} | Player ID: {r[1]}")

# Get all players
cur.execute("SELECT id, name FROM players LIMIT 50;")
players = cur.fetchall()
print("\n=== Players ===")
for p in players:
    print(f"Player ID: {p[0]} | Name: {p[1]}")

cur.close()
conn.close()
