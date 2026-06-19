import psycopg2

url = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
conn = psycopg2.connect(url)
cur = conn.cursor()

# Get column names and types for team_players
cur.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'team_players';
""")
print("=== Columns of team_players ===")
for col in cur.fetchall():
    print(col)

# Get constraints of team_players
cur.execute("""
    SELECT conname, contype 
    FROM pg_constraint 
    WHERE conrelid = 'team_players'::regclass;
""")
print("\n=== Constraints of team_players ===")
for con in cur.fetchall():
    print(con)

# Get indexes of team_players
cur.execute("""
    SELECT indexname, indexdef 
    FROM pg_indexes 
    WHERE tablename = 'team_players';
""")
print("\n=== Indexes of team_players ===")
for idx in cur.fetchall():
    print(idx)

cur.close()
conn.close()
