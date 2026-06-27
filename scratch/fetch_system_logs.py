import urllib.request
import time

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2MzY4NzYsInN1YiI6IjMxZjkyODllLWZiMGMtNGQ4Ni1iYWEyLTM3MDRkODI3OTZjYiJ9.1jl70ZC2l-Ouj5elNKccxPG34l7wHddZO3HwXGfcQE4"
url = "https://cricket-tournament-production.up.railway.app/api/v1/admin/system-logs"

headers = {
    "Authorization": f"Bearer {token}"
}

print("Fetching system logs from live Railway deployment...")
req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req, timeout=15.0) as response:
        code = response.getcode()
        print(f"Status Code: {code}")
        logs = response.read().decode()
        print("--- SYSTEM LOGS START ---")
        print(logs)
        print("--- SYSTEM LOGS END ---")
except Exception as e:
    print(f"Failed to fetch logs: {e}")
