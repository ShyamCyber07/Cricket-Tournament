import urllib.request
import json
import time

url = 'https://cricket-tournament-production.up.railway.app/api/v1/debug-query?secret=cricup_e2e_secret_2026'
start = time.time()

print("Waiting for new deploy & verifying SELECT assigned_scorer_id FROM matches LIMIT 1...")
while time.time() - start < 180:
    try:
        req = urllib.request.Request(f"{url}&t={int(time.time())}")
        with urllib.request.urlopen(req, timeout=10) as response:
            res_data = json.loads(response.read().decode())
            if res_data.get("status") == "success":
                print("VERIFICATION_SUCCESSFUL:", res_data)
                exit(0)
            elif res_data.get("status") == "error":
                print("VERIFICATION_FAILED_WITH_DB_ERROR:", res_data.get("error"))
                print(res_data.get("traceback"))
                exit(1)
            else:
                print("Unexpected response schema:", res_data)
    except Exception as e:
        print("Waiting for deployment (endpoint not ready):", e)
        
    time.sleep(10)

print("Timeout waiting for verification.")
exit(1)
