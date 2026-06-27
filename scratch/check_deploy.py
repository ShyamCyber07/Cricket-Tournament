import urllib.request
import urllib.parse
import json
import re
import time
import sys

url_login = "https://cricket-tournament-production.up.railway.app/api/v1/auth/login"
url_logs = "https://cricket-tournament-production.up.railway.app/api/v1/admin/system-logs"
target_sha = "b11634d"

print(f"Target commit SHA prefix: {target_sha}")

# 1. Login to get fresh access token
try:
    data = urllib.parse.urlencode({
        "username": "cricupservice@gmail.com",
        "password": "Password123!"
    }).encode("utf-8")
    
    req = urllib.request.Request(
        url_login,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        res_json = json.loads(resp.read().decode())
        token = res_json["access_token"]
        print("Successfully authenticated as admin.")
except Exception as e:
    print(f"Authentication failed: {e}")
    sys.exit(1)

headers = {"Authorization": f"Bearer {token}"}

# 2. Poll the system logs endpoint for target version
for i in range(1, 41):
    try:
        req = urllib.request.Request(url_logs, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read().decode()
            
            # Look for APP_VERSION pattern in the logs
            matches = re.findall(r"APP_VERSION\s*=\s*([a-f0-9]+|unknown)", content)
            if matches:
                # Get the last logged APP_VERSION
                version = matches[-1]
                print(f"Attempt {i}: Current deployed APP_VERSION = {version}")
                if version.startswith(target_sha):
                    print("SUCCESS: New deployment completed and active on Railway!")
                    sys.exit(0)
            else:
                print(f"Attempt {i}: APP_VERSION not found in logs yet.")
    except Exception as e:
        print(f"Attempt {i}: Request to system logs failed: {e}")
        
    print("Waiting 15 seconds before next poll...")
    time.sleep(15)

print("TIMEOUT: Deployed version does not match target SHA yet.")
sys.exit(1)
