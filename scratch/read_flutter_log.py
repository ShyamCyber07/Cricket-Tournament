with open(r"C:\Users\praja\.gemini\antigravity-ide\brain\570c5832-ec96-4900-a8dd-d495effc011c\.system_generated\tasks\task-2146.log", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
print(f"Total lines: {len(lines)}")
for line in lines[-200:]:
    print(line.strip())
