with open("scratch/server_logs.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()

print("Recent API calls in server logs:")
for line in lines:
    # Filter for lines containing '2026-06-25 16:5' and 'GET' or 'POST'
    if "16:5" in line and ("GET" in line or "POST" in line):
        print(line.strip())
