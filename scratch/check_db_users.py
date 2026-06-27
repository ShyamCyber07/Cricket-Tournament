import psycopg2
from psycopg2.extras import RealDictCursor

prod_db_url = 'postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway'

def check_users():
    conn = psycopg2.connect(prod_db_url)
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT id, email, username, is_active, is_deleted, email_verified, failed_login_attempts, lockout_until 
                FROM users 
                WHERE email IN ('player@cricup.com', 'captain@cricup.com', 'cricupservice@gmail.com')
            """)
            users = cur.fetchall()
            for u in users:
                print(u)
    finally:
        conn.close()

if __name__ == '__main__':
    check_users()
