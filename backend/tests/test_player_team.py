import pytest
from uuid import UUID

def test_player_crud_and_validation(client, auth_headers):
    # 1. Create player without jersey number
    res = client.post(
        "/api/v1/players/",
        json={
            "name": "Virat Kohli",
            "role": "batsman",
            "batting_style": "right_hand",
            "bowling_style": "none"
        },
        headers=auth_headers
    )
    assert res.status_code == 201
    player = res.json()
    assert player["name"] == "Virat Kohli"
    assert player["jersey_number"] is None
    p_id = player["id"]

    # 2. Create player with valid jersey number
    res = client.post(
        "/api/v1/players/",
        json={
            "name": "MS Dhoni",
            "role": "wicket_keeper",
            "batting_style": "right_hand",
            "bowling_style": "none",
            "jersey_number": 7
        },
        headers=auth_headers
    )
    assert res.status_code == 201
    assert res.json()["jersey_number"] == 7

    # 3. Create player with invalid jersey number (upper bound)
    res = client.post(
        "/api/v1/players/",
        json={
            "name": "Invalid Player",
            "role": "batsman",
            "batting_style": "right_hand",
            "bowling_style": "none",
            "jersey_number": 1000
        },
        headers=auth_headers
    )
    assert res.status_code == 422  # validation error

    # 4. Create player with invalid jersey number (lower bound)
    res = client.post(
        "/api/v1/players/",
        json={
            "name": "Invalid Player 2",
            "role": "batsman",
            "batting_style": "right_hand",
            "bowling_style": "none",
            "jersey_number": -1
        },
        headers=auth_headers
    )
    assert res.status_code == 422  # validation error

    # 5. Get player
    res = client.get(f"/api/v1/players/{p_id}")
    assert res.status_code == 200
    assert res.json()["name"] == "Virat Kohli"

    # 6. Update player (PUT)
    res = client.put(
        f"/api/v1/players/{p_id}",
        json={
            "name": "King Kohli",
            "jersey_number": 18
        },
        headers=auth_headers
    )
    assert res.status_code == 200
    assert res.json()["name"] == "King Kohli"
    assert res.json()["jersey_number"] == 18

    # 7. Delete player
    res = client.delete(f"/api/v1/players/{p_id}", headers=auth_headers)
    assert res.status_code == 204

    # Verify deleted
    res = client.get(f"/api/v1/players/{p_id}")
    assert res.status_code == 404


def test_team_crud_and_validation(client, auth_headers):
    # 1. Register two players
    res_p1 = client.post(
        "/api/v1/players/",
        json={
            "name": "Player 1",
            "role": "batsman",
            "batting_style": "right_hand",
            "bowling_style": "none"
        },
        headers=auth_headers
    )
    res_p2 = client.post(
        "/api/v1/players/",
        json={
            "name": "Player 2",
            "role": "bowler",
            "batting_style": "right_hand",
            "bowling_style": "right_arm_fast"
        },
        headers=auth_headers
    )
    p1_id = res_p1.json()["id"]
    p2_id = res_p2.json()["id"]

    # 2. Create team
    res_t1 = client.post(
        "/api/v1/teams/",
        json={
            "name": "Royal Challengers"
        },
        headers=auth_headers
    )
    assert res_t1.status_code == 201
    team1 = res_t1.json()
    t1_id = team1["id"]

    # 3. Add player 1 to Team 1
    res = client.post(
        f"/api/v1/teams/{t1_id}/players",
        json={"player_id": p1_id},
        headers=auth_headers
    )
    assert res.status_code == 200
    assert len(res.json()["players"]) == 1

    # 4. Edit team (set captain)
    res = client.put(
        f"/api/v1/teams/{t1_id}",
        json={
            "name": "RCB",
            "captain_id": p1_id
        },
        headers=auth_headers
    )
    assert res.status_code == 200
    assert res.json()["name"] == "RCB"
    assert res.json()["captain_id"] == p1_id

    # 5. Try to set captain to non-member player 2 (should fail)
    res = client.put(
        f"/api/v1/teams/{t1_id}",
        json={
            "captain_id": p2_id
        },
        headers=auth_headers
    )
    assert res.status_code == 400
    assert "Captain must be a member" in res.json()["detail"]

    # 6. Try to add Player 1 to another team (should fail: duplicate active membership check)
    res_t2 = client.post(
        "/api/v1/teams/",
        json={
            "name": "Mumbai Indians"
        },
        headers=auth_headers
    )
    t2_id = res_t2.json()["id"]

    res = client.post(
        f"/api/v1/teams/{t2_id}/players",
        json={"player_id": p1_id},
        headers=auth_headers
    )
    assert res.status_code == 400
    assert "Player already assigned to Team" in res.json()["detail"]

    # 7. Remove Player 1 from RCB (should clear captaincy and succeed)
    res = client.delete(
        f"/api/v1/teams/{t1_id}/players/{p1_id}",
        headers=auth_headers
    )
    assert res.status_code == 200
    assert res.json()["captain_id"] is None
    assert len(res.json()["players"]) == 0

    # 8. Delete team
    res = client.delete(f"/api/v1/teams/{t1_id}", headers=auth_headers)
    assert res.status_code == 204


def test_deletion_blocking_validations(client, auth_headers):
    # 1. Create players and team
    res_p = client.post(
        "/api/v1/players/",
        json={"name": "Star Player", "role": "batsman", "batting_style": "right_hand", "bowling_style": "none"},
        headers=auth_headers
    )
    p_id = res_p.json()["id"]

    res_o = client.post(
        "/api/v1/players/",
        json={"name": "Opponent Player", "role": "batsman", "batting_style": "right_hand", "bowling_style": "none"},
        headers=auth_headers
    )
    o_id = res_o.json()["id"]

    res_t1 = client.post("/api/v1/teams/", json={"name": "Team A"}, headers=auth_headers)
    t1_id = res_t1.json()["id"]
    res_t2 = client.post("/api/v1/teams/", json={"name": "Team B"}, headers=auth_headers)
    t2_id = res_t2.json()["id"]

    client.post(f"/api/v1/teams/{t1_id}/players", json={"player_id": p_id}, headers=auth_headers)
    client.post(f"/api/v1/teams/{t2_id}/players", json={"player_id": o_id}, headers=auth_headers)

    # 2. Create match
    res_m = client.post(
        "/api/v1/matches/",
        json={
            "venue": "Test Oval",
            "match_date": "2026-06-11T12:00:00",
            "match_type": "T20",
            "over_limit": 20,
            "team1_id": t1_id,
            "team2_id": t2_id
        },
        headers=auth_headers
    )
    m_id = res_m.json()["id"]

    # 3. Add to squads (makes them active match squads)
    client.post(
        f"/api/v1/matches/{m_id}/squads",
        json={
            "team_id": t1_id,
            "players": [{"player_id": p_id, "is_playing_xi": True, "is_captain": True, "is_wicketkeeper": False}]
        },
        headers=auth_headers
    )
    
    # 4. Trigger toss / team selection to ensure match is active
    client.post(
        f"/api/v1/matches/{m_id}/toss",
        json={"toss_winner_id": t1_id, "toss_decision": "bat"},
        headers=auth_headers
    )

    # 5. Try to delete player (should fail because player is in active squad)
    res = client.delete(f"/api/v1/players/{p_id}", headers=auth_headers)
    assert res.status_code == 400
    assert "Cannot delete player because they are part of an active match" in res.json()["detail"]

    # 6. Try to remove player from team (should fail because player is in active match squad)
    res = client.delete(f"/api/v1/teams/{t1_id}/players/{p_id}", headers=auth_headers)
    assert res.status_code == 400
    assert "Cannot remove player because they are part of an active match" in res.json()["detail"]

    # 7. Try to delete team (should fail because team has active match)
    res = client.delete(f"/api/v1/teams/{t1_id}", headers=auth_headers)
    assert res.status_code == 400
    assert "Cannot delete team because it has scheduled or active matches" in res.json()["detail"]
