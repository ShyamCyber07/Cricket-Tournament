import sqlite3
import os
import sys

sys.path.insert(0, os.path.abspath("backend"))
from app.core.security import verify_password

db_path = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()
cursor.execute("SELECT email, hashed_password FROM users;")
for email, hp in cursor.fetchall():
    print(f"User: {email}")
    print(f"  Password123  matches: {verify_password('Password123', hp) if hp else False}")
    print(f"  Password123! matches: {verify_password('Password123!', hp) if hp else False}")
conn.close()
