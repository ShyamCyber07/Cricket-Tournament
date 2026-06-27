import sys
import os
import sqlite3
import uuid
import datetime

# Add backend to path to import security
sys.path.append(os.path.abspath('backend'))
from app.core.security import get_password_hash

def main():
    pwd_hash = get_password_hash("Password123!")
    db_path = 'backend/cricket.db'
    
    print(f"Connecting to database at {db_path}...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Delete old test user if exists
    cursor.execute("DELETE FROM users WHERE email='testuser@cricup.com'")
    
    user_id = uuid.uuid4().hex
    now_str = str(datetime.datetime.utcnow())
    
    print("Inserting test user...")
    cursor.execute("""
        INSERT INTO users (
            id, username, email, hashed_password, full_name, display_name,
            email_verified, profile_completed, provider, is_active, is_deleted,
            created_at, joined_at, role
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        user_id, 'testuser', 'testuser@cricup.com', pwd_hash, 'Test User', 'Test User',
        1, 1, 'local', 1, 0,
        now_str, now_str, 'scorer'
    ))
    
    conn.commit()
    conn.close()
    print("Created test user testuser@cricup.com with password 'Password123!' successfully!")

if __name__ == "__main__":
    main()
