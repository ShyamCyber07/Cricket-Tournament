import psycopg2

url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
conn = psycopg2.connect(url)
cur = conn.cursor()
cur.execute("SELECT id, email, username FROM users;")
print("Users in DB:")
for r in cur.fetchall():
    print(f"ID: {r[0]} | Email: {r[1]} | Username: {r[2]}")
cur.close()
conn.close()
