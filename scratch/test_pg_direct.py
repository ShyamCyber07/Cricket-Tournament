import psycopg2
import sys

url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@postgres.railway.internal:5432/railway"
print("Connecting to PG database...")
try:
    conn = psycopg2.connect(url, connect_timeout=5)
    print("Successfully connected!")
    cur = conn.cursor()
    cur.execute("SELECT assigned_scorer_id FROM matches LIMIT 1;")
    res = cur.fetchall()
    print("Query results:", res)
    cur.close()
    conn.close()
except Exception as e:
    print("Database connection failed:", e)
