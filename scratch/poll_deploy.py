import urllib.request
import time

url = 'https://cricket-tournament-production.up.railway.app/api/v1/debug-db-url?secret=cricup_e2e_secret_2026'
start = time.time()

print("Polling Railway for deployment of debug-db-url...")
while time.time() - start < 180:
    try:
        # Avoid caching or intermediate gateways by setting a unique header or parameter
        req = urllib.request.Request(f"{url}&t={int(time.time())}")
        with urllib.request.urlopen(req, timeout=10) as response:
            res = response.read().decode().strip()
            if res.startswith('postgresql') or res.startswith('postgres'):
                print("DATABASE_URL_RETRIEVED:", res)
                # Write it to a temporary file locally so we can reference it easily
                with open('scratch/db_url.txt', 'w') as f:
                    f.write(res)
                exit(0)
            else:
                print(f"Response (unexpected): {res}")
    except Exception as e:
        print(f"Polling check failed: {e}")
    time.sleep(5)

print("Timeout waiting for deployment.")
exit(1)
