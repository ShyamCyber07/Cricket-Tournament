import pytest
from uuid import UUID

def setup_scoring_match(client, auth_headers):
    # 1. Create Players
    player_ids = []
    player_names = ["Virat", "Rohit", "Dhoni", "Bumrah", "Shami", "Hardik"]
    for name in player_names:
        response = client.post(
            "/api/v1/players/",
            json={
                "name": name,
                "role": "batsman" if name not in ["Bumrah", "Shami"] else "bowler",
                "batting_style": "right_hand",
                "bowling_style": "right_arm_fast"
            },
            headers=auth_headers
        )
        assert response.status_code == 201
        player_ids.append(response.json()["id"])
        
    p_virat, p_rohit, p_dhoni, p_bumrah, p_shami, p_hardik = player_ids

    # 2. Create Teams
    res_t1 = client.post(
        "/api/v1/teams/",
        json={"name": "Lions Strategy", "captain_id": p_virat},
        headers=auth_headers
    )
    assert res_t1.status_code == 201
    team1_id = res_t1.json()["id"]

    res_t2 = client.post(
        "/api/v1/teams/",
        json={"name": "Tigers Strategy", "captain_id": p_dhoni},
        headers=auth_headers
    )
    assert res_t2.status_code == 201
    team2_id = res_t2.json()["id"]

    # Add players to teams
    for p in [p_virat, p_rohit, p_hardik]:
        client.post(f"/api/v1/teams/{team1_id}/players", json={"player_id": p}, headers=auth_headers)
    for p in [p_dhoni, p_bumrah, p_shami]:
        client.post(f"/api/v1/teams/{team2_id}/players", json={"player_id": p}, headers=auth_headers)

    # 3. Create Match
    match_res = client.post(
        "/api/v1/matches/",
        json={
            "venue": "Mumbai Ground",
            "match_date": "2026-07-01T15:00:00Z",
            "match_type": "T20",
            "over_limit": 5,
            "team1_id": team1_id,
            "team2_id": team2_id
        },
        headers=auth_headers
    )
    assert match_res.status_code == 201
    match_id = match_res.json()["id"]

    # 4. Submit Toss
    client.post(
        f"/api/v1/matches/{match_id}/toss",
        json={"toss_winner_id": team1_id, "toss_decision": "bat"},
        headers=auth_headers
    )

    # 5. Submit Squad Selection
    client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team1_id,
            "players": [
                {"player_id": p_virat, "is_captain": True, "batting_order": 1},
                {"player_id": p_rohit, "batting_order": 2},
                {"player_id": p_hardik, "batting_order": 3}
            ]
        },
        headers=auth_headers
    )
    
    client.put(
        f"/api/v1/matches/{match_id}",
        json={"umpire_name": "Umpire A", "scorer_name": "Scorer B"},
        headers=auth_headers
    )

    client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team2_id,
            "players": [
                {"player_id": p_dhoni, "is_captain": True, "is_wicketkeeper": True, "bowling_preference": 3},
                {"player_id": p_bumrah, "bowling_preference": 1},
                {"player_id": p_shami, "bowling_preference": 2}
            ]
        },
        headers=auth_headers
    )

    # 6. Start Live Match
    client.post(
        f"/api/v1/matches/{match_id}/start",
        json={
            "striker_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_bumrah
        },
        headers=auth_headers
    )

    return match_id, p_virat, p_rohit, p_hardik, p_dhoni, p_bumrah, p_shami

def test_runs_and_strike_rotation(client, auth_headers):
    match_id, p_virat, p_rohit, p_hardik, p_dhoni, p_bumrah, p_shami = setup_scoring_match(client, auth_headers)

    # Ball 1: Dot ball (no runs, no strike swap)
    res = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "batsman_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_bumrah,
            "runs_batsman": 0,
            "runs_extras": 0,
            "extra_type": "none",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert res.status_code == 201
    
    # Check live state
    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["striker"]["player_id"] == str(p_virat)
    assert live_res.json()["non_striker"]["player_id"] == str(p_rohit)
    assert live_res.json()["current_innings"]["total_runs"] == 0
    assert live_res.json()["current_innings"]["total_overs"] == 0.1

    # Ball 2: 1 Run (strike rotation)
    res = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "batsman_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_bumrah,
            "runs_batsman": 1,
            "runs_extras": 0,
            "extra_type": "none",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert res.status_code == 201
    
    # Check rotation
    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["striker"]["player_id"] == str(p_rohit)
    assert live_res.json()["non_striker"]["player_id"] == str(p_virat)
    assert live_res.json()["current_innings"]["total_runs"] == 1
    assert live_res.json()["current_innings"]["total_overs"] == 0.2

def test_extras_scoring(client, auth_headers):
    match_id, p_virat, p_rohit, p_hardik, p_dhoni, p_bumrah, p_shami = setup_scoring_match(client, auth_headers)

    # Ball 1: Wide (does not count as ball, +1 extra, total overs remains 0.0)
    res = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "batsman_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_bumrah,
            "runs_batsman": 0,
            "runs_extras": 1,
            "extra_type": "wide",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert res.status_code == 201

    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["current_innings"]["total_runs"] == 1
    assert live_res.json()["current_innings"]["extras_wides"] == 1
    assert live_res.json()["current_innings"]["total_overs"] == 0.0

    # Ball 2: No Ball (does not count as ball, +1 extra, total overs remains 0.0)
    res = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "batsman_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_bumrah,
            "runs_batsman": 0,
            "runs_extras": 1,
            "extra_type": "no_ball",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert res.status_code == 201

    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["current_innings"]["total_runs"] == 2
    assert live_res.json()["current_innings"]["extras_noballs"] == 1
    assert live_res.json()["current_innings"]["total_overs"] == 0.0

    # Ball 3: Penalty (does not count as ball, +5 extra runs, total overs remains 0.0)
    res = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "batsman_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_bumrah,
            "runs_batsman": 0,
            "runs_extras": 5,
            "extra_type": "penalty",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert res.status_code == 201

    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["current_innings"]["total_runs"] == 7
    assert live_res.json()["current_innings"]["extras_penalty"] == 5
    assert live_res.json()["current_innings"]["total_overs"] == 0.0

    # Scorecard verification (Bowler runs conceded and batsman balls faced should not include penalties)
    scorecard_res = client.get(f"/api/v1/matches/{match_id}/scorecard", headers=auth_headers)
    india_a_score = scorecard_res.json()["innings"][0]
    assert india_a_score["extras"]["total"] == 7
    assert india_a_score["extras"]["penalties"] == 5

def test_wickets_handling(client, auth_headers):
    match_id, p_virat, p_rohit, p_hardik, p_dhoni, p_bumrah, p_shami = setup_scoring_match(client, auth_headers)

    # Ball 1: Wicket (Bowled Virat)
    res = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "batsman_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_bumrah,
            "runs_batsman": 0,
            "runs_extras": 0,
            "extra_type": "none",
            "is_wicket": True,
            "wicket_type": "bowled",
            "player_dismissed_id": p_virat
        },
        headers=auth_headers
    )
    assert res.status_code == 201

    # Striker should be unset, non-striker remains Rohit
    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["striker"] is None
    assert live_res.json()["non_striker"]["player_id"] == str(p_rohit)
    assert live_res.json()["current_innings"]["total_wickets"] == 1

    # Verify bowler stats in scorecard
    scorecard_res = client.get(f"/api/v1/matches/{match_id}/scorecard", headers=auth_headers)
    bowlers = scorecard_res.json()["innings"][0]["bowling"]
    assert bowlers[0]["wickets"] == 1

def test_consecutive_overs_prevention(client, auth_headers):
    match_id, p_virat, p_rohit, p_hardik, p_dhoni, p_bumrah, p_shami = setup_scoring_match(client, auth_headers)

    # Complete 1st over (6 balls) by Bumrah
    for i in range(6):
        res = client.post(
            f"/api/v1/matches/{match_id}/balls",
            json={
                "batsman_id": p_virat,
                "non_striker_id": p_rohit,
                "bowler_id": p_bumrah,
                "runs_batsman": 0,
                "runs_extras": 0,
                "extra_type": "none",
                "is_wicket": False
            },
            headers=auth_headers
        )
        assert res.status_code == 201

    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["current_innings"]["total_overs"] == 1.0
    # Bowler cache should be reset to None at end of over
    assert live_res.json()["bowler"] is None

    # Try to bowl 1st ball of 2nd over by Bumrah again (consecutive overs) -> should be blocked!
    res = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "batsman_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_bumrah,
            "runs_batsman": 0,
            "runs_extras": 0,
            "extra_type": "none",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert res.status_code == 400
    assert "consecutive overs" in res.json()["detail"]

    # Bowl with Shami instead -> should succeed
    res = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "batsman_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_shami,
            "runs_batsman": 0,
            "runs_extras": 0,
            "extra_type": "none",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert res.status_code == 201

def test_undo_scoring_event(client, auth_headers):
    match_id, p_virat, p_rohit, p_hardik, p_dhoni, p_bumrah, p_shami = setup_scoring_match(client, auth_headers)

    # Ball 1: 4 Runs
    res = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "batsman_id": p_virat,
            "non_striker_id": p_rohit,
            "bowler_id": p_bumrah,
            "runs_batsman": 4,
            "runs_extras": 0,
            "extra_type": "none",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert res.status_code == 201

    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["current_innings"]["total_runs"] == 4

    # Undo
    undo_res = client.post(f"/api/v1/matches/{match_id}/undo", headers=auth_headers)
    assert undo_res.status_code == 200

    # Live stats should reset
    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["current_innings"]["total_runs"] == 0
    assert live_res.json()["current_innings"]["total_overs"] == 0.0

def test_atomic_transaction_integrity(client, auth_headers):
    match_id, p_virat, p_rohit, p_hardik, p_dhoni, p_bumrah, p_shami = setup_scoring_match(client, auth_headers)

    # Force a failure inside submit_ball by setting FORCE_TRANSACTION_ROLLBACK commentary
    with pytest.raises(Exception, match="Simulated DB failure"):
        client.post(
            f"/api/v1/matches/{match_id}/balls",
            json={
                "batsman_id": p_virat,
                "non_striker_id": p_rohit,
                "bowler_id": p_bumrah,
                "runs_batsman": 4,
                "runs_extras": 0,
                "extra_type": "none",
                "is_wicket": False,
                "commentary": "FORCE_TRANSACTION_ROLLBACK"
            },
            headers=auth_headers
        )

    # Verify that the entire transaction rolled back and runs was NOT incremented
    live_res = client.get(f"/api/v1/matches/{match_id}/live", headers=auth_headers)
    assert live_res.json()["current_innings"]["total_runs"] == 0
    assert live_res.json()["current_innings"]["total_overs"] == 0.0
