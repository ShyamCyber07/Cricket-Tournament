import pytest

def test_matches_endpoint_team_names(client, auth_headers):
    # 1. Create Players
    player_ids = []
    for name in ["Virat", "Dhoni"]:
        response = client.post(
            "/api/v1/players/",
            json={
                "name": name,
                "role": "batsman",
                "batting_style": "right_hand",
                "bowling_style": "right_arm_fast"
            },
            headers=auth_headers
        )
        assert response.status_code == 201
        player_ids.append(response.json()["id"])
        
    p_virat, p_dhoni = player_ids

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

    # 4. Get Matches List
    get_res = client.get("/api/v1/matches/", headers=auth_headers)
    assert get_res.status_code == 200
    
    matches_list = get_res.json()
    print("\nAPI Response matches list:")
    import json
    print(json.dumps(matches_list, indent=2))
    
    assert len(matches_list) > 0
    match = matches_list[0]
    
    # Assert team names are present in the response
    assert "team1_name" in match
    assert "team2_name" in match
    assert match["team1_name"] == "Team Virat"
    assert match["team2_name"] == "Team Dhoni"
