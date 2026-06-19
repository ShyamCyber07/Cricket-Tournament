import urllib.request
import urllib.parse
import json

base_url = "https://cricket-tournament-production.up.railway.app/api/v1"

# 1. Login
login_url = f"{base_url}/auth/login"
data = urllib.parse.urlencode({
    "username": "cricupservice@gmail.com",
    "password": "Password123!"
}).encode("utf-8")

print("Logging in to production backend...")
try:
    req = urllib.request.Request(login_url, data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with urllib.request.urlopen(req) as response:
        res_data = json.loads(response.read().decode())
        token = res_data.get("access_token")
        print("Login Succeeded! Token retrieved.")
except Exception as e:
    print("Login failed:", e)
    # Let's try to register the user if they don't exist
    signup_url = f"{base_url}/auth/signup"
    signup_data = json.dumps({
        "username": "cricuptester",
        "email": "cricupservice@gmail.com",
        "password": "Password123!"
    }).encode("utf-8")
    print("Trying to signup...")
    try:
        req = urllib.request.Request(signup_url, data=signup_data, method="POST")
        req.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(req) as response:
            print("Signup Succeeded! Try login again...")
            # Login again
            req_login = urllib.request.Request(login_url, data=data, method="POST")
            req_login.add_header("Content-Type", "application/x-www-form-urlencoded")
            with urllib.request.urlopen(req_login) as res_login:
                res_data = json.loads(res_login.read().decode())
                token = res_data.get("access_token")
                print("Login Succeeded after signup!")
    except Exception as ex:
        print("Signup failed:", ex)
        exit(1)

# 2. Call GET /api/v1/matches/
matches_url = f"{base_url}/matches/"
print("Calling GET /api/v1/matches/...")
try:
    req = urllib.request.Request(matches_url, method="GET")
    req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req) as response:
        print("HTTP Status Code:", response.status)
        body = response.read().decode()
        matches_list = json.loads(body)
        print("Matches Count:", len(matches_list))
        print("First Match Preview:", json.dumps(matches_list[0], indent=2) if matches_list else "No matches found")
except Exception as e:
    print("Matches call failed:", e)
    if hasattr(e, 'read'):
        print("Error details:", e.read().decode())
    exit(1)
