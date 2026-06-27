import urllib.request
import urllib.parse
import json
import sys

url_login = "https://cricket-tournament-production.up.railway.app/api/v1/auth/login"
base_url = "https://cricket-tournament-production.up.railway.app/api/v1"

# 1. Login as Admin
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
        print("Admin login successful.")
except Exception as e:
    print(f"Admin login failed: {e}")
    sys.exit(1)

headers = {"Authorization": f"Bearer {token}"}

endpoints = [
    ("/admin/analytics", "GET"),
    ("/admin/activity-logs", "GET"),
    ("/admin/system-logs", "GET"),
    ("/admin/users", "GET"),
    ("/admin/teams", "GET"),
    ("/admin/tournaments", "GET"),
    ("/admin/matches", "GET"),
    ("/admin/team-members", "GET")
]

for path, method in endpoints:
    url = base_url + path
    print(f"\nTesting {method} {url}...")
    req = urllib.request.Request(url, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15.0) as resp:
            print(f"Result: {resp.getcode()} OK")
    except urllib.error.HTTPError as e:
        print(f"Result: HTTP {e.code} Error")
        try:
            body = e.read().decode()
            print(f"Response Body: {body}")
        except Exception:
            pass
    except Exception as e:
        print(f"Request failed: {e}")
