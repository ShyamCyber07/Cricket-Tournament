transcript_path = r"C:\Users\praja\.gemini\antigravity-ide\brain\3251b567-d4c2-4a27-8bf8-5ba1908b9741\.system_generated\logs\transcript.jsonl"

print("Searching transcript.jsonl for migration commands...")
with open(transcript_path, "r", encoding="utf-8") as f:
    for line_num, line in enumerate(f, 1):
        if "migrate_sqlite_to_pg" in line or "pg-url" in line or "alembic" in line:
            print(f"Line {line_num}:")
            # print up to 500 characters of the matching line
            idx = line.find("migrate_sqlite_to_pg")
            if idx == -1:
                idx = line.find("pg-url")
            if idx == -1:
                idx = line.find("alembic")
            print(line[max(0, idx-100):min(len(line), idx+400)])
            print("-" * 50)
