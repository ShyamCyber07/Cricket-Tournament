import sqlite3

db_path = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# List users table structure and rows
cursor.execute("PRAGMA table_info(users);")
print("User Columns:", [col[1] for col in cursor.fetchall()])

cursor.execute("SELECT id, email, full_name, username, display_name FROM users;")
print("Users in DB:")
for r in cursor.fetchall():
    print(r)

conn.close()
