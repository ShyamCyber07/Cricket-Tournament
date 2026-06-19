import urllib.request
import time

logs_url = 'https://cricket-tournament-production.up.railway.app/api/v1/debug-logs?secret=cricup_e2e_secret_2026'
matches_url = 'https://cricket-tournament-production.up.railway.app/api/v1/matches/'
start = time.time()

print("Polling Railway deployment to verify migrations run...")
while time.time() - start < 180:
    try:
        # Check logs
        req = urllib.request.Request(f"{logs_url}&t={int(time.time())}")
        with urllib.request.urlopen(req, timeout=10) as response:
            logs = response.read().decode()
            if "Database migrations upgraded to head successfully" in logs or "Running database migrations from config" in logs:
                print("FOUND LOGS INDICATING MIGRATIONS IN PROGRESS OR DONE!")
                
                # Check if matches endpoint returns successfully now
                try:
                    with urllib.request.urlopen(matches_url, timeout=10) as m_res:
                        print("Matches list returned successfully! Status:", m_res.status)
                        print("Matches body preview:", m_res.read().decode()[:300])
                        exit(0)
                except Exception as ex:
                    print("Matches endpoint failed, but migration logs found. Let's wait a bit...")
                    
            elif "duplicate column name" in logs or "already exists" in logs:
                print("Migrations encountered an error or already applied in logs:", logs[-500:])
                
            else:
                print("Deploying/Starting up... Log lines count:", len(logs.splitlines()))
    except Exception as e:
        print(f"Polling failed: {e}")
        
    time.sleep(5)

print("Timeout waiting for migration verification.")
exit(1)
