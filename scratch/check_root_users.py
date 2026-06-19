import sqlite3

db_path = r"C:\Users\praja\Desktop\Cricket\cricket.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

cursor.execute("SELECT id, email, full_name, username, display_name FROM users;")
print("Users in Root DB:")
for r in cursor.fetchall():
    print(r)

print("\nTeams in Root DB:")
cursor.execute("SELECT id, name FROM teams;")
for r in cursor.fetchall():
    print(r)
    
print("\nTournaments in Root DB:")
cursor.execute("SELECT id, name FROM tournaments;")
for r in cursor.fetchall():
    print(r)

conn.close()
