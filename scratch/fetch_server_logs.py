import urllib.request
import sys

url = "http://127.0.0.1:8000/api/v1/debug-logs?secret=cricup_e2e_secret_2026"
try:
    print(f"Fetching logs from {url}...")
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=5) as response:
        content = response.read().decode('utf-8')
        with open("scratch/server_logs.txt", "w", encoding="utf-8") as f:
            f.write(content)
        print("Logs successfully written to scratch/server_logs.txt")
except Exception as e:
    print(f"Error fetching logs: {e}")
    sys.exit(1)
