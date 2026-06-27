import psycopg2

def check():
    conn = psycopg2.connect('postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway')
    c = conn.cursor()
    c.execute("SELECT id, email, is_active, is_deleted FROM users WHERE email LIKE 'deleted_%'")
    rows = c.fetchall()
    print(f"FOUND {len(rows)} SOFT DELETED USERS:")
    for row in rows:
        print(f"ID: {row[0]}, Email: {row[1]}, Active: {row[2]}, Deleted: {row[3]}")
    conn.close()

if __name__ == '__main__':
    check()
