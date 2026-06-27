import urllib.request
import json
import time

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2MzY4NzYsInN1YiI6IjMxZjkyODllLWZiMGMtNGQ4Ni1iYWEyLTM3MDRkODI3OTZjYiJ9.1jl70ZC2l-Ouj5elNKccxPG34l7wHddZO3HwXGfcQE4"
base_url = "https://cricket-tournament-production.up.railway.app"

headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/json"
}

def verify():
    print("1. Verifying GET /api/v1/teams/my-teams ...")
    url_my = f"{base_url}/api/v1/teams/my-teams"
    req_my = urllib.request.Request(url_my, headers=headers)
    try:
        with urllib.request.urlopen(req_my, timeout=10.0) as resp:
            code = resp.getcode()
            print(f"GET /my-teams -> {code}")
            data = json.loads(resp.read().decode())
            print(f"Found {len(data)} joined teams:")
            for item in data:
                print(f"  - Name: {item['team']['name']}, Role: {item['role']}, Status: {item['status']}")
            if len(data) > 0:
                first_team_id = data[0]["team"]["id"]
                print(f"\n2. Verifying GET /api/v1/teams/{first_team_id}/members ...")
                url_mem = f"{base_url}/api/v1/teams/{first_team_id}/members"
                req_mem = urllib.request.Request(url_mem, headers=headers)
                with urllib.request.urlopen(req_mem, timeout=10.0) as resp_mem:
                    code_mem = resp_mem.getcode()
                    print(f"GET /members -> {code_mem}")
                    members = json.loads(resp_mem.read().decode())
                    print(f"Found {len(members)} team members:")
                    for m in members:
                        print(f"  - {m['user_email']} ({m['role']}, status: {m['status']})")
            else:
                print("No teams found for my-teams.")
    except Exception as e:
        print(f"Verification failed: {e}")

if __name__ == "__main__":
    verify()
