with open("scratch/logcat.log", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()

print(f"Total lines: {len(lines)}")
matches = 0
for i, line in enumerate(lines):
    if "cricup" in line.lower() or "flutter" in line.lower() or "dio" in line.lower():
        matches += 1
        if matches <= 100:
            print(f"{i+1}: {line.strip()}")

print(f"Total matches: {matches}")
