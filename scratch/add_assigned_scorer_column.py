import sqlite3

db_path = r"c:\Users\praja\Desktop\Cricket\cricket.db"

def inspect_and_alter():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 1. Print existing columns in matches
    cursor.execute("PRAGMA table_info(matches);")
    columns = cursor.fetchall()
    col_names = [col[1] for col in columns]
    print("Columns before alter:", col_names)
    
    # 2. Alter table if assigned_scorer_id doesn't exist
    if 'assigned_scorer_id' not in col_names:
        print("Adding column assigned_scorer_id to matches table...")
        try:
            cursor.execute("ALTER TABLE matches ADD COLUMN assigned_scorer_id CHAR(32) REFERENCES users(id) ON DELETE SET NULL;")
            conn.commit()
            print("Column added successfully!")
        except Exception as e:
            print("Error altering table matches:", e)
    else:
        print("Column assigned_scorer_id already exists in matches table.")
        
    # 3. Print columns after alter
    cursor.execute("PRAGMA table_info(matches);")
    columns = cursor.fetchall()
    print("Columns after alter:", [col[1] for col in columns])
    
    conn.close()

if __name__ == "__main__":
    inspect_and_alter()
