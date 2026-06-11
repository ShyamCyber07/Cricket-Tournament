import pytest
from uuid import UUID

def test_scorecard_flow_and_career_stats(client, auth_headers):
    # 1. Register players
    player_names = ["Virat", "Rohit", "Dhoni", "Bumrah", "Shami"]
    player_ids = []
    for name in player_names:
        res = client.post(
            "/api/v1/players/",
            json={
                "name": name,
                "role": "batsman" if name not in ["Bumrah", "Shami"] else "bowler",
                "batting_style": "right_hand",
                "bowling_style": "right_arm_fast"
            },
            headers=auth_headers
        )
        assert res.status_code == 201
        player_ids.append(res.json()["id"])
        
    p_virat, p_rohit, p_dhoni, p_bumrah, p_shami = player_ids

    # 2. Register teams
    t1_res = client.post("/api/v1/teams/", json={"name": "Team Virat", "captain_id": p_virat}, headers=auth_headers)
    team1_id = t1_res.json()["id"]
    t2_res = client.post("/api/v1/teams/", json={"name": "Team Dhoni", "captain_id": p_dhoni}, headers=auth_headers)
    team2_id = t2_res.json()["id"]

    # Add players to teams
    for p in [p_virat, p_rohit, p_shami]:
        client.post(f"/api/v1/teams/{team1_id}/players", json={"player_id": p}, headers=auth_headers)
    for p in [p_dhoni, p_bumrah]:
        client.post(f"/api/v1/teams/{team2_id}/players", json={"player_id": p}, headers=auth_headers)

    # 3. Create a 1-over match (short match for testing)
    match_res = client.post(
        "/api/v1/matches/",
        json={
            "venue": "MCG",
            "match_date": "2026-06-10T15:00:00Z",
            "match_type": "T20",
            "over_limit": 1,
            "team1_id": team1_id,
            "team2_id": team2_id
        },
        headers=auth_headers
    )
    match_id = match_res.json()["id"]

    # submit toss
    client.post(f"/api/v1/matches/{match_id}/toss", json={"toss_winner_id": team1_id, "toss_decision": "bat"}, headers=auth_headers)

    # submit squads
    client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team1_id,
            "players": [{"player_id": p_virat, "is_captain": True}, {"player_id": p_rohit}, {"player_id": p_shami}]
        },
        headers=auth_headers
    )
    client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team2_id,
            "players": [{"player_id": p_dhoni, "is_captain": True}, {"player_id": p_bumrah}]
        },
        headers=auth_headers
    )

    # --- INNINGS 1 ---
    # Virat & Rohit batting, Bumrah bowling. 1 over (6 balls).
    # Ball 1: 1 run (striker Virat, non-striker Rohit) -> rotation
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_bumrah, "batsman_id": p_virat, "non_striker_id": p_rohit,
        "runs_batsman": 1, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 2: 4 runs (striker Rohit, non-striker Virat)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_bumrah, "batsman_id": p_rohit, "non_striker_id": p_virat,
        "runs_batsman": 4, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 3: 0 runs (striker Rohit, non-striker Virat)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_bumrah, "batsman_id": p_rohit, "non_striker_id": p_virat,
        "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 4: 1 run (striker Rohit, non-striker Virat) -> rotation
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_bumrah, "batsman_id": p_rohit, "non_striker_id": p_virat,
        "runs_batsman": 1, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 5: 2 runs (striker Virat, non-striker Rohit)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_bumrah, "batsman_id": p_virat, "non_striker_id": p_rohit,
        "runs_batsman": 2, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 6: 0 runs (striker Virat, non-striker Rohit)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_bumrah, "batsman_id": p_virat, "non_striker_id": p_rohit,
        "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)
    # Innings 1 ends. Total runs = 8. (Virat: 3 runs in 3 balls, Rohit: 5 runs in 3 balls)

    # --- INNINGS 2 ---
    # Dhoni & Bumrah batting, Shami bowling.
    # Ball 1: 2 runs (striker Dhoni, non-striker Bumrah)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_shami, "batsman_id": p_dhoni, "non_striker_id": p_bumrah,
        "runs_batsman": 2, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 2: 1 run (striker Dhoni, non-striker Bumrah) -> rotation
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_shami, "batsman_id": p_dhoni, "non_striker_id": p_bumrah,
        "runs_batsman": 1, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 3: 4 runs (striker Bumrah, non-striker Dhoni)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_shami, "batsman_id": p_bumrah, "non_striker_id": p_dhoni,
        "runs_batsman": 4, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 4: 0 runs (striker Bumrah, non-striker Dhoni)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_shami, "batsman_id": p_bumrah, "non_striker_id": p_dhoni,
        "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 5: 1 run (striker Bumrah, non-striker Dhoni) -> rotation
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_shami, "batsman_id": p_bumrah, "non_striker_id": p_dhoni,
        "runs_batsman": 1, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 6: 0 runs (striker Dhoni, non-striker Bumrah)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_shami, "batsman_id": p_dhoni, "non_striker_id": p_bumrah,
        "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)
    # Innings 2 ends. Total runs = 8. Match completed. Tie match!

    # 4. Fetch Scorecard and Verify
    sc_res = client.get(f"/api/v1/matches/{match_id}/scorecard")
    assert sc_res.status_code == 200
    sc = sc_res.json()

    assert sc["match_summary"]["win_margin_text"] == "Match Tied"
    assert len(sc["innings"]) == 2
    
    # Verify Innings 1
    inn1 = sc["innings"][0]
    assert inn1["innings_number"] == 1
    assert inn1["total_runs"] == 8
    assert inn1["total_wickets"] == 0
    assert inn1["total_overs"] == 1.0
    # Virat batting
    virat_bat = next(p for p in inn1["batting"] if p["name"] == "Virat")
    assert virat_bat["runs"] == 3
    assert virat_bat["balls"] == 3
    assert virat_bat["fours"] == 0
    assert virat_bat["sixes"] == 0
    assert virat_bat["strike_rate"] == 100.0
    assert virat_bat["dismissal_info"] == "not out"
    # Rohit batting
    rohit_bat = next(p for p in inn1["batting"] if p["name"] == "Rohit")
    assert rohit_bat["runs"] == 5
    assert rohit_bat["balls"] == 3
    assert rohit_bat["fours"] == 1
    assert rohit_bat["strike_rate"] == 166.67

    # Verify Career Stats update in DB (e.g. Virat stats)
    v_stats = client.get(f"/api/v1/players/{p_virat}").json()
    assert v_stats["career_runs"] == 3
    assert v_stats["matches_played"] == 1
    assert v_stats["batting_average"] == 3.0
    assert v_stats["strike_rate"] == 100.0


def test_scorecard_wickets_and_extras(client, auth_headers):
    # Register players and teams
    player_names = ["KL Rahul", "Shreyas", "Pant", "Siraj", "Hardik"]
    player_ids = []
    for name in player_names:
        res = client.post(
            "/api/v1/players/",
            json={"name": name, "role": "batsman" if name != "Siraj" else "bowler", "batting_style": "right_hand", "bowling_style": "right_arm_fast"},
            headers=auth_headers
        )
        player_ids.append(res.json()["id"])
    p_rahul, p_shreyas, p_pant, p_siraj, p_hardik = player_ids

    t1_res = client.post("/api/v1/teams/", json={"name": "Team Rahul", "captain_id": p_rahul}, headers=auth_headers)
    team1_id = t1_res.json()["id"]
    t2_res = client.post("/api/v1/teams/", json={"name": "Team Hardik", "captain_id": p_hardik}, headers=auth_headers)
    team2_id = t2_res.json()["id"]

    for p in [p_rahul, p_shreyas, p_pant]:
        client.post(f"/api/v1/teams/{team1_id}/players", json={"player_id": p}, headers=auth_headers)
    for p in [p_siraj, p_hardik]:
        client.post(f"/api/v1/teams/{team2_id}/players", json={"player_id": p}, headers=auth_headers)

    # Create 2-over match
    match_res = client.post(
        "/api/v1/matches/",
        json={"venue": "Lords", "match_date": "2026-06-10T15:00:00Z", "match_type": "T20", "over_limit": 2, "team1_id": team1_id, "team2_id": team2_id},
        headers=auth_headers
    )
    match_id = match_res.json()["id"]

    client.post(f"/api/v1/matches/{match_id}/toss", json={"toss_winner_id": team1_id, "toss_decision": "bat"}, headers=auth_headers)
    client.post(f"/api/v1/matches/{match_id}/squads", json={"team_id": team1_id, "players": [{"player_id": p_rahul}, {"player_id": p_shreyas}, {"player_id": p_pant}]}, headers=auth_headers)
    client.post(f"/api/v1/matches/{match_id}/squads", json={"team_id": team2_id, "players": [{"player_id": p_siraj}, {"player_id": p_hardik}]}, headers=auth_headers)

    # Ball 1: Wide extra (striker Rahul, non-striker Shreyas, bowler Siraj) -> runs_extras=1
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_siraj, "batsman_id": p_rahul, "non_striker_id": p_shreyas,
        "runs_batsman": 0, "runs_extras": 1, "extra_type": "wide", "is_wicket": False
    }, headers=auth_headers)

    # Ball 2: Wicket (striker Rahul dismissed - caught, bowler Siraj, fielder Hardik)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_siraj, "batsman_id": p_rahul, "non_striker_id": p_shreyas,
        "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": True,
        "wicket_type": "caught", "player_dismissed_id": p_rahul, "fielder_id": p_hardik
    }, headers=auth_headers)
    
    # Striker Rahul is out. Pant enters as striker.
    # Ball 3: 4 runs (striker Pant, non-striker Shreyas)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_siraj, "batsman_id": p_pant, "non_striker_id": p_shreyas,
        "runs_batsman": 4, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Ball 4: Leg bye extra (runs_extras=1, type=leg_bye) -> no strike rotation because 1 extra run is a leg-bye, wait, leg-bye rotates strike on odd runs
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_siraj, "batsman_id": p_pant, "non_striker_id": p_shreyas,
        "runs_batsman": 0, "runs_extras": 1, "extra_type": "leg_bye", "is_wicket": False
    }, headers=auth_headers)
    # 1 leg-bye run rotates strike. Striker is now Shreyas.

    # Ball 5: Wicket (striker Shreyas dismissed - bowled)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_siraj, "batsman_id": p_shreyas, "non_striker_id": p_pant,
        "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": True,
        "wicket_type": "bowled", "player_dismissed_id": p_shreyas
    }, headers=auth_headers)
    
    # Since squad size is 3, 2 wickets means Team Rahul is all out! Innings 1 completed!
    # Let's check scorecard
    sc = client.get(f"/api/v1/matches/{match_id}/scorecard").json()
    inn1 = sc["innings"][0]
    
    assert inn1["total_runs"] == 6 # 1 wide + 4 runs + 1 leg-bye
    assert inn1["total_wickets"] == 2
    assert inn1["extras"]["wides"] == 1
    assert inn1["extras"]["leg_byes"] == 1
    assert inn1["extras"]["total"] == 2
    
    # Fall of Wickets verification
    fow = inn1["fall_of_wickets"]
    assert len(fow) == 2
    assert fow[0]["score"] == "1/1" # wide runs = 1, first wicket
    assert fow[0]["player_name"] == "KL Rahul"
    assert fow[0]["over"] == "0.1" # fell on Ball 2 (the caught ball, 1st legit ball)
    
    assert fow[1]["score"] == "6/2"
    assert fow[1]["player_name"] == "Shreyas"
    assert fow[1]["over"] == "0.4" # fell on Ball 5 (the bowled ball, 4th legit ball)


def test_scorecard_chase_completed_early(client, auth_headers):
    # Register players, teams
    player_names = ["PlayerA", "PlayerB", "PlayerC", "PlayerD"]
    player_ids = []
    for name in player_names:
        res = client.post(
            "/api/v1/players/",
            json={"name": name, "role": "batsman", "batting_style": "right_hand", "bowling_style": "right_arm_fast"},
            headers=auth_headers
        )
        player_ids.append(res.json()["id"])
    p_a, p_b, p_c, p_d = player_ids

    t1_res = client.post("/api/v1/teams/", json={"name": "Team A", "captain_id": p_a}, headers=auth_headers)
    team1_id = t1_res.json()["id"]
    t2_res = client.post("/api/v1/teams/", json={"name": "Team B", "captain_id": p_c}, headers=auth_headers)
    team2_id = t2_res.json()["id"]

    client.post(f"/api/v1/teams/{team1_id}/players", json={"player_id": p_a}, headers=auth_headers)
    client.post(f"/api/v1/teams/{team1_id}/players", json={"player_id": p_b}, headers=auth_headers)
    client.post(f"/api/v1/teams/{team2_id}/players", json={"player_id": p_c}, headers=auth_headers)
    client.post(f"/api/v1/teams/{team2_id}/players", json={"player_id": p_d}, headers=auth_headers)

    # 1-over match
    match_res = client.post(
        "/api/v1/matches/",
        json={"venue": "Oval", "match_date": "2026-06-10T15:00:00Z", "match_type": "T20", "over_limit": 1, "team1_id": team1_id, "team2_id": team2_id},
        headers=auth_headers
    )
    match_id = match_res.json()["id"]

    client.post(f"/api/v1/matches/{match_id}/toss", json={"toss_winner_id": team1_id, "toss_decision": "bat"}, headers=auth_headers)
    client.post(f"/api/v1/matches/{match_id}/squads", json={"team_id": team1_id, "players": [{"player_id": p_a}, {"player_id": p_b}]}, headers=auth_headers)
    client.post(f"/api/v1/matches/{match_id}/squads", json={"team_id": team2_id, "players": [{"player_id": p_c}, {"player_id": p_d}]}, headers=auth_headers)

    # --- INNINGS 1 ---
    # Team A scores 3 runs total on 6 balls
    for _ in range(3):
        client.post(f"/api/v1/matches/{match_id}/balls", json={
            "bowler_id": p_c, "batsman_id": p_a, "non_striker_id": p_b,
            "runs_batsman": 1, "runs_extras": 0, "extra_type": "none", "is_wicket": False
        }, headers=auth_headers)
    for _ in range(3):
         client.post(f"/api/v1/matches/{match_id}/balls", json={
            "bowler_id": p_c, "batsman_id": p_b, "non_striker_id": p_a,
            "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": False
        }, headers=auth_headers)
    # Innings 1 ends. Target is 4 runs.

    # --- INNINGS 2 ---
    # Team B hits a six on the first ball to chase it down early!
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_a, "batsman_id": p_c, "non_striker_id": p_d,
        "runs_batsman": 6, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)

    # Match should complete and Team B should win by 10 wickets (since squad size for Team B batting was 2, which is represented as 10 wickets in standard winner mapping, or 2 wickets? Wait!
    # Let's check: in backend/app/routers/matches.py:
    #   match.win_margin_wickets = 10 - innings.total_wickets
    # So it is always 10 - wickets).
    sc = client.get(f"/api/v1/matches/{match_id}/scorecard").json()
    assert sc["match_summary"]["winner_name"] == "Team B"
    assert sc["match_summary"]["win_margin_wickets"] == 10
    assert sc["match_summary"]["win_margin_text"] == "Team B won by 10 wickets"
    assert sc["innings"][1]["total_overs"] == 0.1
