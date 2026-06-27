import urllib.request
import json
import traceback

base_url = "https://cricket-tournament-production.up.railway.app/api/v1"
token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2MzY4NzYsInN1YiI6IjMxZjkyODllLWZiMGMtNGQ4Ni1iYWEyLTM3MDRkODI3OTZjYiJ9.1jl70ZC2l-Ouj5elNKccxPG34l7wHddZO3HwXGfcQE4"

headers = {
    "Authorization": f"Bearer {token}"
}

req = urllib.request.Request(f"{base_url}/teams/", headers=headers)
print("Sending request to /teams/...")
try:
    with urllib.request.urlopen(req, timeout=5.0) as response:
        teams = json.loads(response.read().decode())
        print(f"Total teams found: {len(teams)}")
        for team in teams:
            team_id = team['id']
            team_name = team['name']
            print(f"Team: {team_name} ({team_id})")
            
            # Fetch details
            req_detail = urllib.request.Request(f"{base_url}/teams/{team_id}", headers=headers)
            try:
                with urllib.request.urlopen(req_detail, timeout=5.0) as detail_response:
                    team_data = json.loads(detail_response.read().decode())
                    players = team_data.get('players', [])
                    print(f"  Players count: {len(players)}")
            except Exception as inner_e:
                print(f"  Failed for {team_name}: {inner_e}")
except Exception as e:
    print("Failed:")
    traceback.print_exc()
