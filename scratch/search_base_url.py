with open("scratch/google_tap_logcat.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines:
    if "APP_ENV" in line or "BASE_URL" in line or "Diagnostic" in line:
        print(line.strip())
