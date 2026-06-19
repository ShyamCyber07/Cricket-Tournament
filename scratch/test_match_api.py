import urllib.request
import urllib.parse
import json

PROD_URL = "https://cricket-tournament-production.up.railway.app/api/v1"

def api_call(endpoint, token=None, method="GET", data=None, is_form=False):
    url = f"{PROD_URL}{endpoint}"
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
    except Exception as e:
        print("API call failed:", e)
        raise e

def main():
    # Login
    login_res = api_call("/auth/login", method="POST", data={
        "username": "cortexclashservice@gmail.com",
        "password": "Password123!"
    }, is_form=True)
    token = login_res["access_token"]
    
    matches = api_call("/matches/", token=token)
    print("Matches for maharamit66@gmail.com:")
    for m in matches:
        print(f"ID: {m['id']} | Teams: {m.get('team1_name')} vs {m.get('team2_name')} | Status: {m['status']} | Date: {m['match_date']}")

if __name__ == "__main__":
    main()
