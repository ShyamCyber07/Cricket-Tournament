import psycopg2

url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
print("Connecting to PG database...")
try:
    conn = psycopg2.connect(url, connect_timeout=10)
    print("Successfully connected!")
    cur = conn.cursor()
    
    cur.execute("SELECT conname, contype FROM pg_constraint WHERE conrelid = 'team_players'::regclass;")
    print("\nConstraints on team_players:")
    for row in cur.fetchall():
        print(f"Name: {row[0]}, Type: {row[1]}")
        
    cur.close()
    conn.close()
except Exception as e:
    print("Database connection failed:", e)
