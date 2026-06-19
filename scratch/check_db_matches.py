import psycopg2

url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
conn = psycopg2.connect(url)
cur = conn.cursor()

cur.execute("""
    SELECT m.id, t1.name, t2.name, m.status, m.created_by, m.created_at
    FROM matches m
    JOIN teams t1 ON m.team1_id = t1.id
    JOIN teams t2 ON m.team2_id = t2.id
    ORDER BY m.created_at DESC LIMIT 15;
""")
print("=== Matches in DB ===")
for r in cur.fetchall():
    print(f"ID: {r[0]} | Teams: {r[1]} vs {r[2]} | Status: {r[3]} | CreatedBy: {r[4]} | CreatedAt: {r[5]}")

cur.close()
conn.close()
