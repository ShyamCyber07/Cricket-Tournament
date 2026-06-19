import sqlite3

db_path = r"c:\Users\praja\Desktop\Cricket\cricket.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

query = """
UPDATE matches 
SET created_by = '1adb472a8bc9443d87dcedeb6d6eb671' 
WHERE id = 'd7356ac63a01477f998eddcc2f8695d6';
"""

cursor.execute(query)
conn.commit()
print("Match owner reverted successfully!")
conn.close()
