import psycopg2

def repair():
    db_uri = 'postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway'
    conn = psycopg2.connect(db_uri)
    c = conn.cursor()
    
    # Select all users whose email starts with 'deleted_'
    c.execute("SELECT id, email, is_active, is_deleted FROM users WHERE email LIKE 'deleted_%'")
    rows = c.fetchall()
    print(f"Found {len(rows)} users with 'deleted_' email prefix.")
    
    for row in rows:
        user_id = row[0]
        old_email = row[1]
        new_email = f"deleted_{user_id}@cricup.local"
        new_username = f"deleted_{user_id[:8]}"
        
        print(f"Updating user {user_id}:")
        print(f"  Old Email: {old_email}")
        print(f"  New Email: {new_email}")
        
        c.execute(
            """
            UPDATE users 
            SET email = %s, username = %s, is_deleted = True, is_active = False 
            WHERE id = %s
            """,
            (new_email, new_username, user_id)
        )
    
    conn.commit()
    print("Database updates committed successfully.")
    
    # Verify
    c.execute("SELECT id, email, is_active, is_deleted FROM users WHERE email LIKE 'deleted_%'")
    updated_rows = c.fetchall()
    print(f"\nVerification - users with 'deleted_' email prefix after repair:")
    for row in updated_rows:
        print(f"ID: {row[0]}, Email: {row[1]}, Active: {row[2]}, Deleted: {row[3]}")
        
    conn.close()

if __name__ == '__main__':
    repair()
