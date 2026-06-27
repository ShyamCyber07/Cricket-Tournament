with open("scratch/google_tap_logcat.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "flutter" in line or "Dio" in line or "cricup" in line:
        print(f"{i}: {line.strip()}")
