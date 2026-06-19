import sqlite3
import os

db_path = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

cursor.execute("SELECT id, name, logo_url FROM teams;")
print("Teams in DB:")
for r in cursor.fetchall():
    print(r)

conn.close()
