import sqlite3

db_path = r"c:\Users\praja\Desktop\Cricket\cricket.db"

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Update created_by to another user (Shyam's ID)
query = """
UPDATE matches 
SET created_by = '1600e0f2b73b46de91db6e6b74ff833b' 
WHERE id = 'd7356ac63a01477f998eddcc2f8695d6';
"""

cursor.execute(query)
conn.commit()
print("Match owner updated to Shyam's ID successfully!")

conn.close()
