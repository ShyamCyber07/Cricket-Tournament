import urllib.request
import json
import time

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2MzY4NzYsInN1YiI6IjMxZjkyODllLWZiMGMtNGQ4Ni1iYWEyLTM3MDRkODI3OTZjYiJ9.1jl70ZC2l-Ouj5elNKccxPG34l7wHddZO3HwXGfcQE4"
base_url = "https://cricket-tournament-production.up.railway.app"

endpoints = [
    "/api/v1/admin/users",
    "/api/v1/admin/teams",
    "/api/v1/admin/players",
    "/api/v1/admin/matches",
    "/api/v1/teams/"
]

headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/json"
}

print("Starting verification of live Railway endpoints...")
for ep in endpoints:
    url = f"{base_url}{ep}"
    req = urllib.request.Request(url, headers=headers)
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=10.0) as response:
            code = response.getcode()
            duration = time.time() - start
            print(f"GET {ep:<25} -> {code} ({duration:.2f} seconds)")
            data = json.loads(response.read().decode())
            print(f"  Received {len(data)} items.")
    except Exception as e:
        duration = time.time() - start
        print(f"GET {ep:<25} -> FAILED ({duration:.2f} seconds): {e}")
