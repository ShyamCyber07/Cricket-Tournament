import pytest
from app.models.cricket import Team, Player, Match

def test_data_isolation_teams_and_players(client, db):
    # Create two users via signup
    res_u1 = client.post("/api/v1/auth/signup", json={"email": "usera@example.com", "password": "password123", "full_name": "User A"})
    res_u2 = client.post("/api/v1/auth/signup", json={"email": "userb@example.com", "password": "password123", "full_name": "User B"})
    assert res_u1.status_code == 201
    assert res_u2.status_code == 201

    # Login User A
    res_login_a = client.post("/api/v1/auth/login", data={"username": "usera@example.com", "password": "password123"})
    token_a = res_login_a.json()["access_token"]
    headers_a = {"Authorization": f"Bearer {token_a}"}

    # Login User B
    res_login_b = client.post("/api/v1/auth/login", data={"username": "userb@example.com", "password": "password123"})
    token_b = res_login_b.json()["access_token"]
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # 1. User A creates a team
    res_team_a = client.post("/api/v1/teams/", json={"name": "Team A Owned"}, headers=headers_a)
    assert res_team_a.status_code == 201
    team_a_id = res_team_a.json()["id"]

    # 2. User B lists teams -> should be empty (or at least not contain Team A)
    res_list_b = client.get("/api/v1/teams/", headers=headers_b)
    assert res_list_b.status_code == 200
    team_ids_b = [t["id"] for t in res_list_b.json()]
    assert team_a_id not in team_ids_b

    # 3. User B tries to update User A's team -> 403
    res_update = client.put(f"/api/v1/teams/{team_a_id}", json={"name": "Hacked Team"}, headers=headers_b)
    assert res_update.status_code == 403

    # 4. User B tries to delete User A's team -> 403
    res_delete = client.delete(f"/api/v1/teams/{team_a_id}", headers=headers_b)
    assert res_delete.status_code == 403

    # 5. User A creates a player
    res_player_a = client.post("/api/v1/players/", json={
        "name": "Player A Owned",
        "role": "batsman",
        "batting_style": "right_hand",
        "bowling_style": "none"
    }, headers=headers_a)
    assert res_player_a.status_code == 201
    player_a_id = res_player_a.json()["id"]

    # 6. User B lists players -> should not contain Player A
    res_players_b = client.get("/api/v1/players/", headers=headers_b)
    assert res_players_b.status_code == 200
    player_ids_b = [p["id"] for p in res_players_b.json()]
    assert player_a_id not in player_ids_b

    # 7. User B tries to update/delete Player A -> 403
    res_player_update = client.put(f"/api/v1/players/{player_a_id}", json={"name": "Hacked Name"}, headers=headers_b)
    assert res_player_update.status_code == 403

    res_player_delete = client.delete(f"/api/v1/players/{player_a_id}", headers=headers_b)
    assert res_player_delete.status_code == 403


def test_bulk_player_assignment_and_validation(client):
    # Login existing user A (we can use User A created before, or register fresh one)
    res_u = client.post("/api/v1/auth/signup", json={"email": "userc@example.com", "password": "password123", "full_name": "User C"})
    token = client.post("/api/v1/auth/login", data={"username": "userc@example.com", "password": "password123"}).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create two teams
    t1_id = client.post("/api/v1/teams/", json={"name": "Team 1 C"}, headers=headers).json()["id"]
    t2_id = client.post("/api/v1/teams/", json={"name": "Team 2 C"}, headers=headers).json()["id"]

    # Create three players
    p1_id = client.post("/api/v1/players/", json={"name": "P1", "role": "batsman", "batting_style": "right_hand", "bowling_style": "none"}, headers=headers).json()["id"]
    p2_id = client.post("/api/v1/players/", json={"name": "P2", "role": "batsman", "batting_style": "right_hand", "bowling_style": "none"}, headers=headers).json()["id"]
    p3_id = client.post("/api/v1/players/", json={"name": "P3", "role": "batsman", "batting_style": "right_hand", "bowling_style": "none"}, headers=headers).json()["id"]

    # 1. Bulk assign P1 and P2 to Team 1
    res_bulk = client.post(f"/api/v1/teams/{t1_id}/players/bulk", json={"player_ids": [p1_id, p2_id]}, headers=headers)
    assert res_bulk.status_code == 200
    players_in_t1 = [p["id"] for p in res_bulk.json()["players"]]
    assert p1_id in players_in_t1
    assert p2_id in players_in_t1

    # 2. Try to bulk assign P2 and P3 to Team 2 -> should fail because P2 is already in Team 1
    res_bulk_fail = client.post(f"/api/v1/teams/{t2_id}/players/bulk", json={"player_ids": [p2_id, p3_id]}, headers=headers)
    assert res_bulk_fail.status_code == 400
    assert "Player already assigned to Team Team 1 C" in res_bulk_fail.json()["detail"]


def test_match_ownership_scoring(client):
    # Signup and login User D (Owner) and User E (Viewer)
    client.post("/api/v1/auth/signup", json={"email": "userd@example.com", "password": "password123", "full_name": "User D"})
    token_d = client.post("/api/v1/auth/login", data={"username": "userd@example.com", "password": "password123"}).json()["access_token"]
    headers_d = {"Authorization": f"Bearer {token_d}"}

    client.post("/api/v1/auth/signup", json={"email": "usere@example.com", "password": "password123", "full_name": "User E"})
    token_e = client.post("/api/v1/auth/login", data={"username": "usere@example.com", "password": "password123"}).json()["access_token"]
    headers_e = {"Authorization": f"Bearer {token_e}"}

    # User D creates teams, players and a match
    t1_id = client.post("/api/v1/teams/", json={"name": "Team D1"}, headers=headers_d).json()["id"]
    t2_id = client.post("/api/v1/teams/", json={"name": "Team D2"}, headers=headers_d).json()["id"]
    
    match_id = client.post("/api/v1/matches/", json={
        "venue": "Gaddafi Stadium",
        "match_date": "2026-06-12T10:00:00Z",
        "match_type": "T20",
        "over_limit": 20,
        "team1_id": t1_id,
        "team2_id": t2_id
    }, headers=headers_d).json()["id"]

    # 1. User E (viewer) tries to submit toss -> 403 Forbidden
    res_toss_viewer = client.post(f"/api/v1/matches/{match_id}/toss", json={
        "toss_winner_id": t1_id,
        "toss_decision": "bat"
    }, headers=headers_e)
    assert res_toss_viewer.status_code == 403

    # 2. User D (owner) submits toss -> 200 OK
    res_toss_owner = client.post(f"/api/v1/matches/{match_id}/toss", json={
        "toss_winner_id": t1_id,
        "toss_decision": "bat"
    }, headers=headers_d)
    assert res_toss_owner.status_code == 200
