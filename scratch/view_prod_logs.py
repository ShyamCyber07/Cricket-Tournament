import urllib.request
import json

url = "https://cricket-tournament-production.up.railway.app/api/v1/debug-logs?secret=cricup_e2e_secret_2026"

try:
    with urllib.request.urlopen(url) as response:
        logs = json.loads(response.read().decode())
        print("Backend Logs (last 50 lines):")
        for line in logs[-50:]:
            print(line)
except Exception as e:
    print("Error fetching logs:", e)
