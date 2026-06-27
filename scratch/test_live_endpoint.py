import urllib.request
import json
import time

url = "https://cricket-tournament-production.up.railway.app/api/v1/teams/"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2MzY4NzYsInN1YiI6IjMxZjkyODllLWZiMGMtNGQ4Ni1iYWEyLTM3MDRkODI3OTZjYiJ9.1jl70ZC2l-Ouj5elNKccxPG34l7wHddZO3HwXGfcQE4"

headers = {
    "Authorization": f"Bearer {token}"
}

print("Testing live endpoint:", url)
start_time = time.time()
req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req, timeout=8.0) as response:
        code = response.getcode()
        duration = time.time() - start_time
        print(f"Status Code: {code}")
        print(f"Duration: {duration:.2f} seconds")
        data = json.loads(response.read().decode())
        print(f"Total Teams: {len(data)}")
except Exception as e:
    duration = time.time() - start_time
    print(f"Failed after {duration:.2f} seconds: {e}")
