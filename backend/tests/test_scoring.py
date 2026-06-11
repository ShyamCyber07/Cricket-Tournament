import pytest
from uuid import UUID

def test_auth_and_signup(client, db):
    # Signup
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "cricketer",
            "email": "cricketer@example.com",
            "password": "StrongPassword123!",
            "confirm_password": "StrongPassword123!"
        }
    )
    assert response.status_code == 201
    assert response.json()["email"] == "cricketer@example.com"
    assert response.json()["username"] == "cricketer"

    # Verify
    from app.models.user import User
    user = db.query(User).filter(User.email == "cricketer@example.com").first()
    user.email_verified = True
    db.commit()

    # Login
    response = client.post(
        "/api/v1/auth/login",
        data={
            "username": "cricketer@example.com",
            "password": "StrongPassword123!"
        }
    )
    assert response.status_code == 200
    assert "access_token" in response.json()


def test_complete_match_scoring_flow(client, auth_headers):
    # 1. Create Players
    player_ids = []
    player_names = ["Virat", "Rohit", "Dhoni", "Bumrah", "Shami"]
    for name in player_names:
        response = client.post(
            "/api/v1/players/",
            json={
                "name": name,
                "role": "batsman" if name != "Bumrah" and name != "Shami" else "bowler",
                "batting_style": "right_hand",
                "bowling_style": "right_arm_fast"
            },
            headers=auth_headers
        )
        assert response.status_code == 201
        player_ids.append(response.json()["id"])
        
    p_virat, p_rohit, p_dhoni, p_bumrah, p_shami = player_ids

    # 2. Create Teams
    res_t1 = client.post(
        "/api/v1/teams/",
        json={"name": "India A", "captain_id": p_virat},
        headers=auth_headers
    )
    assert res_t1.status_code == 201
    team1_id = res_t1.json()["id"]

    res_t2 = client.post(
        "/api/v1/teams/",
        json={"name": "India B", "captain_id": p_dhoni},
        headers=auth_headers
    )
    assert res_t2.status_code == 201
    team2_id = res_t2.json()["id"]

    # Add players to teams
    # Team 1 players
    for p in [p_virat, p_rohit, p_shami]:
        client.post(f"/api/v1/teams/{team1_id}/players", json={"player_id": p}, headers=auth_headers)
    # Team 2 players
    for p in [p_dhoni, p_bumrah]:
        client.post(f"/api/v1/teams/{team2_id}/players", json={"player_id": p}, headers=auth_headers)

    # 3. Create Match
    match_res = client.post(
        "/api/v1/matches/",
        json={
            "venue": "Wankhede Stadium",
            "match_date": "2026-06-10T15:00:00Z",
            "match_type": "T20",
            "over_limit": 2, # short 2-over match for testing
            "team1_id": team1_id,
            "team2_id": team2_id
        },
        headers=auth_headers
    )
    assert match_res.status_code == 201
    match_id = match_res.json()["id"]
    assert match_res.json()["status"] == "scheduled"

    # 4. Submit Toss
    toss_res = client.post(
        f"/api/v1/matches/{match_id}/toss",
        json={"toss_winner_id": team1_id, "toss_decision": "bat"},
        headers=auth_headers
    )
    assert toss_res.status_code == 200
    assert toss_res.json()["status"] == "team_selection"

    # 5. Submit Squad Selection
    # Team 1 squad
    sq1_res = client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team1_id,
            "players": [
                {"player_id": p_virat, "is_captain": True},
                {"player_id": p_rohit},
                {"player_id": p_shami}
            ]
        },
        headers=auth_headers
    )
    assert sq1_res.status_code == 200
    
    # Team 2 squad -> should trigger transition to 'innings1'
    sq2_res = client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team2_id,
            "players": [
                {"player_id": p_dhoni, "is_captain": True, "is_wicketkeeper": True},
                {"player_id": p_bumrah}
            ]
        },
        headers=auth_headers
    )
    assert sq2_res.status_code == 200
    assert sq2_res.json()["match_status"] == "innings1"

    # 6. Test Scoring a ball
    # Ball 1: 1 Run (strike rotation)
    ball1 = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "bowler_id": p_bumrah,
            "batsman_id": p_virat, # striker
            "non_striker_id": p_rohit, # non striker
            "runs_batsman": 1,
            "runs_extras": 0,
            "extra_type": "none",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert ball1.status_code == 201

    # Check live scoreboard
    live_res = client.get(f"/api/v1/matches/{match_id}/live")
    assert live_res.status_code == 200
    live_state = live_res.json()
    
    assert live_state["current_innings"]["total_runs"] == 1
    assert live_state["current_innings"]["total_overs"] == 0.1
    # Check strike rotation: Rohit should now be the striker, Virat the non-striker
    assert live_state["striker"]["player_id"] == p_rohit
    assert live_state["non_striker"]["player_id"] == p_virat
    assert live_state["striker"]["runs"] == 0
    assert live_state["non_striker"]["runs"] == 1

    # Ball 2: 4 Runs (no rotation)
    ball2 = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "bowler_id": p_bumrah,
            "batsman_id": p_rohit,
            "non_striker_id": p_virat,
            "runs_batsman": 4,
            "runs_extras": 0,
            "extra_type": "none",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert ball2.status_code == 201
    
    live_state = client.get(f"/api/v1/matches/{match_id}/live").json()
    assert live_state["current_innings"]["total_runs"] == 5
    assert live_state["current_innings"]["total_overs"] == 0.2
    assert live_state["striker"]["player_id"] == p_rohit
    assert live_state["striker"]["runs"] == 4
    assert live_state["striker"]["fours"] == 1

    # Ball 3: Wide extra (runs_extras=1, extra_type=wide)
    ball3 = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "bowler_id": p_bumrah,
            "batsman_id": p_rohit,
            "non_striker_id": p_virat,
            "runs_batsman": 0,
            "runs_extras": 1,
            "extra_type": "wide",
            "is_wicket": False
        },
        headers=auth_headers
    )
    assert ball3.status_code == 201

    live_state = client.get(f"/api/v1/matches/{match_id}/live").json()
    assert live_state["current_innings"]["total_runs"] == 6
    # Wide doesn't increment over count! Should still be 0.2 overs
    assert live_state["current_innings"]["total_overs"] == 0.2
    assert live_state["current_innings"]["extras_wides"] == 1

    # 7. Test Wicket
    # Ball 4: Wicket (Virat run out at non-striker end)
    ball4 = client.post(
        f"/api/v1/matches/{match_id}/balls",
        json={
            "bowler_id": p_bumrah,
            "batsman_id": p_rohit,
            "non_striker_id": p_virat,
            "runs_batsman": 0,
            "runs_extras": 0,
            "extra_type": "none",
            "is_wicket": True,
            "wicket_type": "run_out",
            "player_dismissed_id": p_virat
        },
        headers=auth_headers
    )
    assert ball4.status_code == 201

    live_state = client.get(f"/api/v1/matches/{match_id}/live").json()
    assert live_state["current_innings"]["total_wickets"] == 1
    assert live_state["current_innings"]["total_overs"] == 0.3
    # Non-striker is now out (None), striker is still Rohit
    assert live_state["striker"]["player_id"] == p_rohit
    assert live_state["non_striker"] is None

    # 8. Test Undo last ball
    undo_res = client.post(f"/api/v1/matches/{match_id}/undo", headers=auth_headers)
    assert undo_res.status_code == 200

    # Score should revert
    live_state = client.get(f"/api/v1/matches/{match_id}/live").json()
    assert live_state["current_innings"]["total_wickets"] == 0
    assert live_state["current_innings"]["total_overs"] == 0.2
    assert live_state["non_striker"]["player_id"] == p_virat

def test_invalid_uuid_token(client):
    from jose import jwt
    from app.core.config import settings
    
    # Generate token with sub that is not a valid UUID format
    payload = {"exp": 9999999999, "sub": "not-a-valid-uuid-format"}
    invalid_token = jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")
    
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {invalid_token}"}
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Could not validate credentials"

def test_valid_uuid_nonexistent_user(client):
    from jose import jwt
    from app.core.config import settings
    import uuid
    
    # Generate token with sub that is a valid UUID but does not exist in DB
    nonexistent_user_id = str(uuid.uuid4())
    payload = {"exp": 9999999999, "sub": nonexistent_user_id}
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")
    
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Could not validate credentials"


def test_no_ball_scoring_variations(client, auth_headers):
    # 1. Create Players
    player_ids = []
    player_names = ["Virat", "Rohit", "Dhoni", "Bumrah", "Shami"]
    for name in player_names:
        response = client.post(
            "/api/v1/players/",
            json={
                "name": name,
                "role": "batsman" if name != "Bumrah" and name != "Shami" else "bowler",
                "batting_style": "right_hand",
                "bowling_style": "right_arm_fast"
            },
            headers=auth_headers
        )
        assert response.status_code == 201
        player_ids.append(response.json()["id"])
        
    p_virat, p_rohit, p_dhoni, p_bumrah, p_shami = player_ids

    # 2. Create Teams
    res_t1 = client.post(
        "/api/v1/teams/",
        json={"name": "India A", "captain_id": p_virat},
        headers=auth_headers
    )
    assert res_t1.status_code == 201
    team1_id = res_t1.json()["id"]

    res_t2 = client.post(
        "/api/v1/teams/",
        json={"name": "India B", "captain_id": p_dhoni},
        headers=auth_headers
    )
    assert res_t2.status_code == 201
    team2_id = res_t2.json()["id"]

    # Add players to teams
    for p in [p_virat, p_rohit, p_shami]:
        client.post(f"/api/v1/teams/{team1_id}/players", json={"player_id": p}, headers=auth_headers)
    for p in [p_dhoni, p_bumrah]:
        client.post(f"/api/v1/teams/{team2_id}/players", json={"player_id": p}, headers=auth_headers)

    # 3. Create Match
    match_res = client.post(
        "/api/v1/matches/",
        json={
            "venue": "Wankhede Stadium",
            "match_date": "2026-06-10T15:00:00Z",
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
    toss_res = client.post(
        f"/api/v1/matches/{match_id}/toss",
        json={"toss_winner_id": team1_id, "toss_decision": "bat"},
        headers=auth_headers
    )
    assert toss_res.status_code == 200

    # 5. Submit Squad Selection
    client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team1_id,
            "players": [
                {"player_id": p_virat, "is_captain": True},
                {"player_id": p_rohit},
                {"player_id": p_shami}
            ]
        },
        headers=auth_headers
    )
    
    sq2_res = client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team2_id,
            "players": [
                {"player_id": p_dhoni, "is_captain": True, "is_wicketkeeper": True},
                {"player_id": p_bumrah}
            ]
        },
        headers=auth_headers
    )
    assert sq2_res.json()["match_status"] == "innings1"

    # Set initial striker and bowler
    # (FastAPI backend will auto-initialize/sync caches as we post balls)
    
    # 6. Test No Ball combinations from 0 to 6 batsman runs
    # We will submit 7 No Balls, each with batsman runs from 0 to 6
    expected_team_runs = 0
    expected_extras_nb = 0
    expected_batsman_runs = 0

    for bat_runs in range(7):
        ball_res = client.post(
            f"/api/v1/matches/{match_id}/balls",
            json={
                "bowler_id": p_bumrah,
                "batsman_id": p_virat,
                "non_striker_id": p_rohit,
                "runs_batsman": bat_runs,
                "runs_extras": 1, # 1 run penalty for No Ball
                "extra_type": "no_ball",
                "is_wicket": False
            },
            headers=auth_headers
        )
        assert ball_res.status_code == 201
        
        expected_team_runs += (1 + bat_runs)
        expected_extras_nb += 1
        expected_batsman_runs += bat_runs

        # Verify live scoreboard values
        live_state = client.get(f"/api/v1/matches/{match_id}/live").json()
        assert live_state["current_innings"]["total_runs"] == expected_team_runs
        assert live_state["current_innings"]["extras_noballs"] == expected_extras_nb
        
        # Verify batsman runs for Virat (strike rotates on odd runs)
        virat_runs = 0
        if live_state["striker"] and live_state["striker"]["player_id"] == str(p_virat):
            virat_runs = live_state["striker"]["runs"]
        elif live_state["non_striker"] and live_state["non_striker"]["player_id"] == str(p_virat):
            virat_runs = live_state["non_striker"]["runs"]
        assert virat_runs == expected_batsman_runs


    # Verify scorecard batsman details
    scorecard = client.get(f"/api/v1/matches/{match_id}/scorecard").json()
    virat_card = next(b for b in scorecard["innings"][0]["batting"] if b["name"] == "Virat")
    assert virat_card["runs"] == expected_batsman_runs
    assert scorecard["innings"][0]["extras"]["no_balls"] == expected_extras_nb


