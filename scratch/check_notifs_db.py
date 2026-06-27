import psycopg2
from psycopg2.extras import RealDictCursor

prod_db_url = 'postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway'

conn = psycopg2.connect(prod_db_url)
try:
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM notifications ORDER BY created_at DESC LIMIT 15")
        rows = cur.fetchall()
        print("--- RECENT NOTIFICATIONS ---")
        for r in rows:
            print(f"ID: {r['id']} | UserID: {r['user_id']} | Title: {r['title']} | Msg: {r['message']} | Type: {r['type']} | Read: {r['is_read']} | Extra: {r['extra_data']}")
            
        cur.execute("SELECT * FROM team_members LIMIT 10")
        m_rows = cur.fetchall()
        print("\n--- TEAM MEMBERS ---")
        for m in m_rows:
            print(f"TeamID: {m['team_id']} | UserID: {m['user_id']} | Role: {m['role']} | Status: {m['status']}")
            
        cur.execute("SELECT id, email, role FROM users LIMIT 10")
        u_rows = cur.fetchall()
        print("\n--- USERS ---")
        for u in u_rows:
            print(f"ID: {u['id']} | Email: {u['email']} | Role: {u['role']}")
finally:
    conn.close()
