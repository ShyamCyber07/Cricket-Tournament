import sqlite3

db_path = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Get all teams
cursor.execute("SELECT id, name, created_by FROM teams;")
teams = cursor.fetchall()
print("TEAMS IN DATABASE:")
for t in teams:
    print(f"ID: {t[0]} | Name: {t[1]} | CreatedBy: {t[2]}")

# Get all team members
cursor.execute("SELECT team_id, user_id, role, status FROM team_members;")
members = cursor.fetchall()
print("\nTEAM MEMBERS IN DATABASE:")
for m in members:
    print(f"TeamID: {m[0]} | UserID: {m[1]} | Role: {m[2]} | Status: {m[3]}")

# Get all users
cursor.execute("SELECT id, email, role FROM users;")
users = cursor.fetchall()
print("\nUSERS IN DATABASE:")
for u in users:
    print(f"ID: {u[0]} | Email: {u[1]} | Role: {u[2]}")

conn.close()
