import urllib.request
import time
import re

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2MzY4NzYsInN1YiI6IjMxZjkyODllLWZiMGMtNGQ4Ni1iYWEyLTM3MDRkODI3OTZjYiJ9.1jl70ZC2l-Ouj5elNKccxPG34l7wHddZO3HwXGfcQE4"
headers = {"Authorization": f"Bearer {token}"}
url = "https://cricket-tournament-production.up.railway.app/api/v1/admin/system-logs"

print("Polling for new deployment...")
for i in range(30):
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            content = resp.read().decode()
            match = re.search(r"APP_VERSION = ([a-f0-9]+)", content)
            if match:
                version = match.group(1)
                print(f"Attempt {i+1}: Current APP_VERSION = {version}")
                if version.startswith("649d59a"):
                    print("SUCCESS: Deployment completed!")
                    break
            else:
                print(f"Attempt {i+1}: Could not find APP_VERSION in logs.")
    except Exception as e:
        print(f"Attempt {i+1}: Request failed: {e}")
    time.sleep(10)
