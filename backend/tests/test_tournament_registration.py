import pytest
from uuid import UUID

def test_tournament_states_and_registration_flow(client, auth_headers):
    # 1. Create a tournament (should default to status='draft')
    res = client.post(
        "/api/v1/tournaments/",
        json={
            "name": "Phase 3.1 Cup",
            "start_date": "2026-06-15",
            "end_date": "2026-06-25",
            "format": "League",
            "num_teams": 4
        },
        headers=auth_headers
    )
    assert res.status_code == 201
    tour = res.json()
    assert tour["status"] == "draft"
    tour_id = tour["id"]

    # 2. Publish the tournament
    pub_res = client.post(f"/api/v1/tournaments/{tour_id}/publish", headers=auth_headers)
    assert pub_res.status_code == 200
    assert pub_res.json()["status"] == "published"

    # 3. Open registration
    open_res = client.post(f"/api/v1/tournaments/{tour_id}/open-registration", headers=auth_headers)
    assert open_res.status_code == 200
    assert open_res.json()["status"] == "registration_open"

    # 4. Try to request join with an understaffed team (fewer than 5 players)
    team_res = client.post("/api/v1/teams/", json={"name": "Registration Team A"}, headers=auth_headers)
    team_id = team_res.json()["id"]

    req_fail = client.post(f"/api/v1/tournaments/{tour_id}/requests?team_id={team_id}", headers=auth_headers)
    assert req_fail.status_code == 400
    assert "at least 5 registered players" in req_fail.json()["detail"]

    # 5. Add 5 players to satisfy team size validation
    player_ids = []
    for i in range(5):
        p_res = client.post(
            "/api/v1/players/",
            json={"name": f"PlayerA_{i}", "role": "batsman", "batting_style": "right_hand", "bowling_style": "none"},
            headers=auth_headers
        )
        player_ids.append(p_res.json()["id"])
        
    for pid in player_ids:
        # Note: Add them to team via teams router (add player to team)
        client.post(f"/api/v1/teams/{team_id}/players", json={"player_id": pid}, headers=auth_headers)

    # Make current user a captain in the TeamMember association (done automatically on team creation by default)
    # 6. Request to join (should succeed now)
    req_res = client.post(f"/api/v1/tournaments/{tour_id}/requests?team_id={team_id}", headers=auth_headers)
    assert req_res.status_code == 200
    req = req_res.json()
    assert req["status"] == "pending"
    req_id = req["id"]

    # 7. Organizer approves the registration request
    app_res = client.post(f"/api/v1/tournaments/{tour_id}/requests/{req_id}/approve", headers=auth_headers)
    assert app_res.status_code == 200
    assert app_res.json()["status"] == "approved"

    # 8. Check that the team is successfully added to the registered teams list (backward compatibility check)
    tour_details = client.get(f"/api/v1/tournaments/{tour_id}", headers=auth_headers).json()
    # Check points table/standings or registered teams list
    pt_res = client.get(f"/api/v1/tournaments/{tour_id}/points-table", headers=auth_headers)
    assert pt_res.status_code == 200
    teams_registered = [t["team_id"] for t in pt_res.json()]
    assert team_id in teams_registered

    # 9. Logged activities check
    act_res = client.get(f"/api/v1/tournaments/{tour_id}/activities", headers=auth_headers)
    assert act_res.status_code == 200
    actions = [a["action"] for a in act_res.json()]
    assert "created" in actions
    assert "published" in actions
    assert "registration_open" in actions
    assert "join_requested" in actions
    assert "approved" in actions
