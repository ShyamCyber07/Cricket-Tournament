import urllib.request
import json
import time

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODIyOTI3MDUsInN1YiI6ImIzNGJhYWJiLWU3OTktNGNmNi05MjllLWQ4YjM4YjdlYTg4OSJ9.6nHfo0jlepKBVT2BVd4y7d_lTVOShZtop9-B42AbkpU"
base_url = "https://cricket-tournament-production.up.railway.app/api/v1"

def api_call(endpoint, method="GET", data=None):
    url = f"{base_url}{endpoint}"
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    if data:
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

# 1. Create Team A
t = int(time.time())
team1 = api_call("/teams/", method="POST", data={
    "name": f"Mumbai Indians {t}",
    "logo_url": None,
    "captain_id": None
})
team1_id = team1["id"]
print("Created Team A:", team1["name"], "ID:", team1_id)

# 2. Create Team B
team2 = api_call("/teams/", method="POST", data={
    "name": f"Chennai Super Kings {t}",
    "logo_url": None,
    "captain_id": None
})
team2_id = team2["id"]
print("Created Team B:", team2["name"], "ID:", team2_id)

# 3. Create 11 players for Team A and add them
team1_players = []
for i in range(11):
    p = api_call("/players/", method="POST", data={
        "name": f"MI Batter {i+1}",
        "role": "batsman" if i < 6 else "bowler",
        "batting_style": "right_hand",
        "bowling_style": "right_arm_spin",
        "jersey_number": i+1,
        "user_id": None,
        "profile_photo_url": None
    })
    team1_players.append(p["id"])
    # Assign to Team A
    api_call(f"/teams/{team1_id}/players", method="POST", data={
        "player_id": p["id"]
    })
print("Created and assigned 11 players to Team A.")

# 4. Create 11 players for Team B and add them
team2_players = []
for i in range(11):
    p = api_call("/players/", method="POST", data={
        "name": f"CSK Bowler {i+1}",
        "role": "batsman" if i < 6 else "bowler",
        "batting_style": "left_hand",
        "bowling_style": "left_arm_fast",
        "jersey_number": i+1,
        "user_id": None,
        "profile_photo_url": None
    })
    team2_players.append(p["id"])
    # Assign to Team B
    api_call(f"/teams/{team2_id}/players", method="POST", data={
        "player_id": p["id"]
    })
print("Created and assigned 11 players to Team B.")

# 5. Create a Match
match = api_call("/matches/", method="POST", data={
    "venue": "Wankhede Stadium",
    "match_date": "2026-06-17T14:40:00",
    "match_type": "T20",
    "over_limit": 2,
    "team1_id": team1_id,
    "team2_id": team2_id,
    "tournament_id": None,
    "assigned_scorer_id": None
})
match_id = match["id"]
print("Created Match! ID:", match_id)
print("CSK Name:", match.get("team1_name"), "RCB Name:", match.get("team2_name"))

# Save configuration
with open("scratch/match_test_config.json", "w") as f:
    json.dump({
        "match_id": match_id,
        "team1_id": team1_id,
        "team2_id": team2_id,
        "team1_players": team1_players,
        "team2_players": team2_players
    }, f, indent=2)
print("Saved configurations to scratch/match_test_config.json")
