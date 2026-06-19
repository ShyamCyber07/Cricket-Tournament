import sqlite3

db_path = r"c:\Users\praja\Desktop\Cricket\cricket.db"

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Get matches and join with tournaments if any
query = """
SELECT 
    m.id, 
    m.venue, 
    m.status, 
    m.created_by, 
    m.assigned_scorer_id, 
    m.tournament_id,
    t.name,
    t.organizer_id
FROM matches m
LEFT JOIN tournaments t ON m.tournament_id = t.id;
"""

cursor.execute(query)
print("Matches in DB:")
for r in cursor.fetchall():
    print(f"Match ID: {r[0]}\n  Venue: {r[1]}, Status: {r[2]}\n  Created By: {r[3]}\n  Assigned Scorer: {r[4]}\n  Tournament ID: {r[5]} ({r[6]})\n  Tournament Organizer: {r[7]}\n")

conn.close()
