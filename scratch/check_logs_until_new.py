import urllib.request
import time

url = 'https://cricket-tournament-production.up.railway.app/api/v1/debug-logs?secret=cricup_e2e_secret_2026'
start = time.time()

print("Waiting for new deploy to come online...")
while time.time() - start < 180:
    try:
        # Prevent caching
        req = urllib.request.Request(f"{url}&t={int(time.time())}")
        with urllib.request.urlopen(req, timeout=10) as response:
            logs = response.read().decode()
            # If the log contains the new startup message or has been restarted
            lines = logs.splitlines()
            # Find if there is a startup after 08:57:59 (e.g. 08:58 or 08:59 or 09:00)
            has_new_startup = False
            for line in lines:
                if "Running database migrations from config" in line:
                    print("FOUND MIGRATION LOG:", line)
                    has_new_startup = True
                if "Database migrations upgraded to head successfully" in line:
                    print("FOUND SUCCESS LOG:", line)
                    has_new_startup = True
                    
            if has_new_startup:
                print("New deployment migrations verified!")
                exit(0)
                
            # If there's an error message about migrations in the logs
            if "Error running database migrations" in line:
                # print the traceback around it
                idx = logs.find("Error running database migrations")
                print("MIGRATION ERROR ENCOUNTERED:")
                print(logs[idx:idx+800])
                exit(1)
                
            print("Still showing old logs. Waiting...")
    except Exception as e:
        print("Backend might be rebuilding/restarting (offline):", e)
    time.sleep(10)

print("Timeout waiting for new deploy.")
exit(1)
