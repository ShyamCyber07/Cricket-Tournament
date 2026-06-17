import pytest
from uuid import UUID

def test_squad_player_duplication_validation(client, auth_headers):
    # 1. Create Players
    player_ids = []
    player_names = ["Virat", "Rohit", "Dhoni", "Bumrah"]
    for name in player_names:
        response = client.post(
            "/api/v1/players/",
            json={
                "name": name,
                "role": "batsman" if name != "Bumrah" else "bowler",
                "batting_style": "right_hand",
                "bowling_style": "right_arm_fast"
            },
            headers=auth_headers
        )
        assert response.status_code == 201
        player_ids.append(response.json()["id"])
        
    p_virat, p_rohit, p_dhoni, p_bumrah = player_ids

    # 2. Create Teams
    res_t1 = client.post(
        "/api/v1/teams/",
        json={"name": "Team Virat", "captain_id": p_virat},
        headers=auth_headers
    )
    assert res_t1.status_code == 201
    team1_id = res_t1.json()["id"]

    res_t2 = client.post(
        "/api/v1/teams/",
        json={"name": "Team Dhoni", "captain_id": p_dhoni},
        headers=auth_headers
    )
    assert res_t2.status_code == 201
    team2_id = res_t2.json()["id"]

    # Add players to teams
    for p in [p_virat, p_rohit]:
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

    # Test Case 1: Submit Team 1 squad with duplicate player IDs inside the same list
    sq1_dup_res = client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team1_id,
            "players": [
                {"player_id": p_virat, "is_captain": True},
                {"player_id": p_virat} # duplicate ID
            ]
        },
        headers=auth_headers
    )
    assert sq1_dup_res.status_code == 400
    assert "Duplicate players found" in sq1_dup_res.json()["detail"]

    # Submit clean Team 1 squad
    sq1_clean_res = client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team1_id,
            "players": [
                {"player_id": p_virat, "is_captain": True},
                {"player_id": p_rohit}
            ]
        },
        headers=auth_headers
    )
    assert sq1_clean_res.status_code == 200

    # Test Case 2: Submit Team 2 squad containing a player already in Team 1 squad (p_virat)
    sq2_overlap_res = client.post(
        f"/api/v1/matches/{match_id}/squads",
        json={
            "team_id": team2_id,
            "players": [
                {"player_id": p_dhoni, "is_captain": True},
                {"player_id": p_virat} # overlapping player
            ]
        },
        headers=auth_headers
    )
    assert sq2_overlap_res.status_code == 400
    assert "already assigned to the opposing team" in sq2_overlap_res.json()["detail"]
    assert "Virat" in sq2_overlap_res.json()["detail"]

    # Test Case 3: Submit clean Team 2 squad with no overlap
    sq2_clean_res = client.post(
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
    assert sq2_clean_res.status_code == 200
    assert sq2_clean_res.json()["match_status"] == "innings1"
