import sqlite3
import os

db_path = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"
if not os.path.exists(db_path):
    print("Database does not exist.")
    exit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("Deleting all teams and team memberships...")
cursor.execute("DELETE FROM team_members;")
cursor.execute("DELETE FROM teams;")

cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
print("Tables in SQLite database:", [row[0] for row in cursor.fetchall()])

conn.commit()
print("Database cleaned successfully!")
conn.close()
