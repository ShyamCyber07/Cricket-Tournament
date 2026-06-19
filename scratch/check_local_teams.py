import urllib.request
import json
import urllib.parse

LOCAL_URL = "http://localhost:8000/api/v1"

def api_call(endpoint, token=None, method="GET", data=None, is_form=False):
    url = f"{LOCAL_URL}{endpoint}"
    req = urllib.request.Request(url, method=method)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if data:
        if is_form:
            req.add_header("Content-Type", "application/x-www-form-urlencoded")
            req_data = urllib.parse.urlencode(data).encode("utf-8")
        else:
            req.add_header("Content-Type", "application/json")
            req_data = json.dumps(data).encode("utf-8")
    else:
        req_data = None
        
    try:
        with urllib.request.urlopen(req, data=req_data) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.read().decode()}")
        raise e
    except Exception as e:
        print(f"Connection failed: {e}")
        raise e

def main():
    try:
        # Login
        print("Logging in to local backend...")
        login_res = api_call("/auth/login", method="POST", data={
            "username": "smoke_996369@gmail.com",
            "password": "Password123!"
        }, is_form=True)
        token = login_res["access_token"]
        print("Logged in successfully!")
        
        # Get teams
        teams = api_call("/teams/", token=token)
        print("\nTeams in Local Backend:")
        for t in teams:
            print(f"ID: {t['id']} | Name: {t['name']} | Logo: {t['logo_url']}")
            
        # Get tournaments
        tournaments = api_call("/tournaments/", token=token)
        print("\nTournaments in Local Backend:")
        for t in tournaments:
            print(f"ID: {t['id']} | Name: {t['name']} | Logo: {t['banner_url']}")
    except Exception:
        pass

if __name__ == "__main__":
    main()
