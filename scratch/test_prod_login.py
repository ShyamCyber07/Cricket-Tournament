import urllib.request
import urllib.parse
import json

PROD_URL = "https://cricket-tournament-production.up.railway.app/api/v1"

def test_login():
    print(f"Connecting to production backend: {PROD_URL}...")
    try:
        req = urllib.request.Request(f"{PROD_URL}/auth/me")
        with urllib.request.urlopen(req) as response:
            print(f"Me status: {response.getcode()}")
    except urllib.error.HTTPError as e:
        print(f"Me HTTP error: {e.code} - {e.read().decode('utf-8', errors='ignore')}")
    except Exception as e:
        print(f"Connection error: {e}")

    # Try logging in with the test user we used locally
    login_data = urllib.parse.urlencode({
        "username": "refine_profile@t.com",
        "password": "Password123!"
    }).encode("utf-8")
    
    print("Trying login with refine_profile@t.com...")
    try:
        req = urllib.request.Request(
            f"{PROD_URL}/auth/login",
            data=login_data,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        with urllib.request.urlopen(req) as response:
            print(f"Login Response code: {response.getcode()}")
            print(f"Login Response body: {response.read().decode('utf-8')}")
    except urllib.error.HTTPError as e:
        print(f"Login HTTP error: {e.code} - {e.read().decode('utf-8', errors='ignore')}")
    except Exception as e:
        print(f"Login error: {e}")

if __name__ == "__main__":
    test_login()
