import urllib.request
import json

base_url = "https://cricket-tournament-production.up.railway.app/api/v1"

try:
    with urllib.request.urlopen(f"{base_url}/teams/") as response:
        teams = json.loads(response.read().decode())
        print(f"Total teams found: {len(teams)}")

        for team in teams:
            team_id = team['id']
            team_name = team['name']
            print(f"\nTeam: {team_name} ({team_id})")
            
            with urllib.request.urlopen(f"{base_url}/teams/{team_id}") as team_response:
                team_data = json.loads(team_response.read().decode())
                players = team_data.get('players', [])
                print(f"  Players count from API: {len(players)}")
                for p in players:
                    print(f"    - {p['name']} ({p['id']})")
except Exception as e:
    print("Failed to fetch teams:", e)
