import urllib.request
import urllib.parse
import json

PROD_URL = "https://cricket-tournament-production.up.railway.app/api/v1"

def api_call(endpoint, token=None, method="GET", data=None, is_form=False):
    url = f"{PROD_URL}{endpoint}"
    req = urllib.request.Request(url, method=method)
    
    print(f"\n--- [API Request] ---")
    print(f"URL: {url}")
    print(f"Method: {method}")
    
    if token:
        req.add_header("Authorization", f"Bearer {token}")
        print(f"Headers: Authorization: Bearer <token>")
    
    if data:
        if is_form:
            req.add_header("Content-Type", "application/x-www-form-urlencoded")
            req_data = urllib.parse.urlencode(data).encode("utf-8")
            print(f"Content-Type: application/x-www-form-urlencoded")
            print(f"Body: {data}")
        else:
            req.add_header("Content-Type", "application/json")
            req_data = json.dumps(data).encode("utf-8")
            print(f"Content-Type: application/json")
            print(f"Body: {json.dumps(data)}")
    else:
        req_data = None
        print("Body: None")
        
    try:
        with urllib.request.urlopen(req, data=req_data) as response:
            res_body = response.read().decode()
            print(f"\n--- [API Response] ---")
            print(f"Status Code: {response.status}")
            print(f"Body: {res_body}")
            return json.loads(res_body)
    except urllib.error.HTTPError as e:
        print(f"\n--- [API Error Response] ---")
        print(f"Status Code: {e.code}")
        print(f"Headers: {e.headers}")
        print(f"Body: {e.read().decode()}")
        raise e
    except Exception as e:
        print(f"\n--- [Connection/Other Error] ---")
        print(f"Error: {e}")
        raise e

def main():
    # Login
    print("Logging in to production backend...")
    login_res = api_call("/auth/login", method="POST", data={
        "username": "smoke_996369@gmail.com",
        "password": "Password123!"
    }, is_form=True)
    token = login_res["access_token"]
    
    # Try creating a new team
    import uuid
    unique_team_name = f"Test_Team_{uuid.uuid4().hex[:6]}"
    print(f"\nAttempting to create team: {unique_team_name}")
    try:
        api_call("/teams/", token=token, method="POST", data={
            "name": unique_team_name,
            "logo_url": None,
            "captain_id": None
        })
    except Exception as e:
        print("\nTeam creation failed in script.")

if __name__ == "__main__":
    main()
