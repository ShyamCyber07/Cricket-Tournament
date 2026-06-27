with open("scratch/google_tap_logcat.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()

print(f"Total lines in logcat: {len(lines)}")
for i, line in enumerate(lines):
    if "auth" in line.lower() or "cricup" in line.lower() or "google" in line.lower() or "token" in line.lower() or "signature" in line.lower() or "verification" in line.lower():
        print(f"{i}: {line.strip()}")
