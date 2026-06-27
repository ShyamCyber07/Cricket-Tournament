with open("scratch/google_tap_logcat.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "[Dio Request]" in line or "[Dio Response]" in line:
        print(f"--- Line {i} ---")
        for j in range(max(0, i-2), min(len(lines), i+15)):
            marker = ">> " if j == i else "   "
            print(f"{marker}{j}: {lines[j].strip()}")
