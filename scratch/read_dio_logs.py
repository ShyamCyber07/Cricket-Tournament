with open("scratch/google_tap_logcat.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines:
    if "[Dio Request]" in line or "[Dio Response]" in line or "DioException" in line or "DIAGNOSTICS" in line or "CLASSIFIED" in line:
        print(line.strip())
