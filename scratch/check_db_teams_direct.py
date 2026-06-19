import psycopg2

url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
print("Connecting to PG database...")
try:
    conn = psycopg2.connect(url, connect_timeout=10)
    print("Successfully connected!")
    cur = conn.cursor()
    
    cur.execute("SELECT id, name, created_by, created_at FROM teams ORDER BY created_at DESC LIMIT 10;")
    print("\nRecent teams in Database:")
    for row in cur.fetchall():
        print(f"ID: {row[0]} | Name: {row[1]} | CreatedBy: {row[2]} | CreatedAt: {row[3]}")
        
    cur.close()
    conn.close()
except Exception as e:
    print("Database connection failed:", e)
