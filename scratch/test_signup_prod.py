import urllib.request
import urllib.error
import json
import time

url = "https://cricket-tournament-production.up.railway.app/api/v1/auth/signup"
data = {
    "username": "tester_debug",
    "email": "tester_debug@example.com",
    "password": "Password123!",
    "confirm_password": "Password123!"
}
headers = {
    "Content-Type": "application/json",
    "User-Agent": "Mozilla/5.0"
}
req = urllib.request.Request(
    url,
    data=json.dumps(data).encode("utf-8"),
    headers=headers
)

print("Sending signup request to production backend...")
start_time = time.time()
try:
    with urllib.request.urlopen(req, timeout=60) as res:
        elapsed = time.time() - start_time
        print(f"Success in {elapsed:.2f} seconds!")
        print("Status code:", res.getcode())
        print("Response:", res.read().decode())
except urllib.error.HTTPError as e:
    elapsed = time.time() - start_time
    print(f"HTTP Error {e.code} in {elapsed:.2f} seconds:")
    print(e.read().decode())
except Exception as ex:
    elapsed = time.time() - start_time
    print(f"Exception after {elapsed:.2f} seconds: {ex}")
