import pytest
from uuid import UUID

def test_team_registration_and_roster_check(client, auth_headers):
    # 1. Create a tournament
    t_res = client.post(
        "/api/v1/tournaments/",
        json={
            "name": "Validation Cup",
            "start_date": "2026-06-10",
            "end_date": "2026-06-20",
            "format": "League",
            "num_teams": 2
        },
        headers=auth_headers
    )
    assert t_res.status_code == 201
    tour_id = t_res.json()["id"]

    # 2. Create players and team with FEWER than 5 players (4 players)
    player_ids = []
    for i in range(4):
        p_res = client.post(
            "/api/v1/players/",
            json={"name": f"P{i}", "role": "batsman", "batting_style": "right_hand", "bowling_style": "none"},
            headers=auth_headers
        )
        player_ids.append(p_res.json()["id"])
        
    team_res = client.post("/api/v1/teams/", json={"name": "Understaffed FC"}, headers=auth_headers)
    team_id = team_res.json()["id"]

    # Add 4 players
    for p in player_ids:
        client.post(f"/api/v1/teams/{team_id}/players", json={"player_id": p}, headers=auth_headers)

    # Register should FAIL because roster < 5 players
    reg_fail = client.post(f"/api/v1/tournaments/{tour_id}/teams?team_id={team_id}", headers=auth_headers)
    assert reg_fail.status_code == 400
    assert "at least 5 registered players" in reg_fail.json()["detail"]

    # Add a 5th player to satisfy validation
    p5 = client.post(
        "/api/v1/players/",
        json={"name": "P4", "role": "batsman", "batting_style": "right_hand", "bowling_style": "none"},
        headers=auth_headers
    ).json()["id"]
    client.post(f"/api/v1/teams/{team_id}/players", json={"player_id": p5}, headers=auth_headers)

    # Register should now SUCCEED
    reg_ok = client.post(f"/api/v1/tournaments/{tour_id}/teams?team_id={team_id}", headers=auth_headers)
    assert reg_ok.status_code == 200

    # Test deregister
    dereg_res = client.delete(f"/api/v1/tournaments/{tour_id}/teams/{team_id}", headers=auth_headers)
    assert dereg_res.status_code == 200


def test_league_fixtures_and_nrr_math(client, auth_headers):
    # Setup 2 teams, 5 players each
    team_ids = []
    for t_name in ["T1", "T2"]:
        team = client.post("/api/v1/teams/", json={"name": t_name}, headers=auth_headers).json()
        team_ids.append(team["id"])
        for idx in range(5):
            p = client.post("/api/v1/players/", json={"name": f"{t_name}_P{idx}", "role": "batsman", "batting_style": "right", "bowling_style": "none"}, headers=auth_headers).json()
            client.post(f"/api/v1/teams/{team['id']}/players", json={"player_id": p["id"]}, headers=auth_headers)

    t1_id, t2_id = team_ids

    # Create League tournament
    tour = client.post(
        "/api/v1/tournaments/",
        json={"name": "T20 League", "start_date": "2026-06-10", "end_date": "2026-06-12", "format": "League", "num_teams": 2},
        headers=auth_headers
    ).json()
    tour_id = tour["id"]

    # Register teams
    client.post(f"/api/v1/tournaments/{tour_id}/teams?team_id={t1_id}", headers=auth_headers)
    client.post(f"/api/v1/tournaments/{tour_id}/teams?team_id={t2_id}", headers=auth_headers)

    # Generate round robin fixtures
    fig_res = client.post(f"/api/v1/tournaments/{tour_id}/fixtures/generate", json={"home_away": False, "over_limit": 1}, headers=auth_headers)
    assert fig_res.status_code == 201

    pub_res = client.post(f"/api/v1/tournaments/{tour_id}/fixtures/publish", headers=auth_headers)
    assert pub_res.status_code == 200

    # Fetch dashboard to verify upcoming match generated
    dash = client.get(f"/api/v1/tournaments/{tour_id}/dashboard").json()
    assert len(dash["upcoming_matches"]) == 1
    match = dash["upcoming_matches"][0]
    match_id = match["id"]

    # Play the match: T1 bats first, scores 10 runs.
    # T2 chases, gets 11 runs in 3 balls.
    client.post(f"/api/v1/matches/{match_id}/toss", json={"toss_winner_id": t1_id, "toss_decision": "bat"}, headers=auth_headers)
    
    # Register squads
    t1_players = client.get(f"/api/v1/teams/{t1_id}").json()["players"]
    t2_players = client.get(f"/api/v1/teams/{t2_id}").json()["players"]
    client.post(f"/api/v1/matches/{match_id}/squads", json={"team_id": t1_id, "players": [{"player_id": p["id"]} for p in t1_players]}, headers=auth_headers)
    client.post(f"/api/v1/matches/{match_id}/squads", json={"team_id": t2_id, "players": [{"player_id": p["id"]} for p in t2_players]}, headers=auth_headers)

    p_t1_1, p_t1_2 = t1_players[0]["id"], t1_players[1]["id"]
    p_t2_1, p_t2_2 = t2_players[0]["id"], t2_players[1]["id"]

    # Innings 1: T1 scores 10 runs
    # Ball 1-5: 2 runs each
    for _ in range(5):
        client.post(f"/api/v1/matches/{match_id}/balls", json={
            "bowler_id": p_t2_2, "batsman_id": p_t1_1, "non_striker_id": p_t1_2,
            "runs_batsman": 2, "runs_extras": 0, "extra_type": "none", "is_wicket": False
        }, headers=auth_headers)
    # Ball 6: Wicket
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_t2_2, "batsman_id": p_t1_1, "non_striker_id": p_t1_2,
        "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": True,
        "wicket_type": "bowled", "player_dismissed_id": p_t1_1
    }, headers=auth_headers)
    # Innings 1 total = 10 runs, 1 wicket, 1.0 overs.

    # Innings 2: T2 scores 11 runs (6, 4, 1)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_t1_2, "batsman_id": p_t2_1, "non_striker_id": p_t2_2,
        "runs_batsman": 6, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_t1_2, "batsman_id": p_t2_1, "non_striker_id": p_t2_2,
        "runs_batsman": 4, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)
    client.post(f"/api/v1/matches/{match_id}/balls", json={
        "bowler_id": p_t1_2, "batsman_id": p_t2_1, "non_striker_id": p_t2_2,
        "runs_batsman": 1, "runs_extras": 0, "extra_type": "none", "is_wicket": False
    }, headers=auth_headers)
    # Innings 2 total = 11 runs, 0 wickets, 0.3 overs. Match completed. T2 won.

    # Points Table check: T2 has 2 points. NRR calculations:
    # NRR T2: Scored 11 in 0.5 overs (3 balls = 0.5 overs) = 22.0 run rate. Conceded 10 in 1.0 overs = 10.0. NRR = 12.000.
    # NRR T1: Scored 10 in 1.0 overs = 10.0. Conceded 11 in 0.5 overs = 22.0. NRR = -12.000.
    pt = client.get(f"/api/v1/tournaments/{tour_id}/points-table").json()
    t2_entry = next(x for x in pt if x["team_name"] == "T2")
    t1_entry = next(x for x in pt if x["team_name"] == "T1")
    
    assert t2_entry["played"] == 1
    assert t2_entry["won"] == 1
    assert t2_entry["points"] == 2
    assert t2_entry["net_run_rate"] == 12.000

    assert t1_entry["played"] == 1
    assert t1_entry["lost"] == 1
    assert t1_entry["points"] == 0
    assert t1_entry["net_run_rate"] == -12.000

    # Verify Leaderboards
    lb = client.get(f"/api/v1/tournaments/{tour_id}/leaderboards").json()
    assert lb["top_batsmen"][0]["metric_value"] == 11.0
    assert lb["top_bowlers"][0]["metric_value"] == 1.0


def test_hybrid_tournament_progression(client, auth_headers):
    # Create 4 teams with 5 players each
    teams = []
    for idx in range(4):
        t = client.post("/api/v1/teams/", json={"name": f"Team_{idx}"}, headers=auth_headers).json()
        teams.append(t)
        for p_idx in range(5):
            p = client.post("/api/v1/players/", json={"name": f"Team_{idx}_Player_{p_idx}", "role": "batsman", "batting_style": "right", "bowling_style": "none"}, headers=auth_headers).json()
            client.post(f"/api/v1/teams/{t['id']}/players", json={"player_id": p["id"]}, headers=auth_headers)

    tour = client.post(
        "/api/v1/tournaments/",
        json={"name": "World Cup Hybrid", "start_date": "2026-06-10", "end_date": "2026-06-25", "format": "League + Knockout", "num_teams": 4},
        headers=auth_headers
    ).json()
    tour_id = tour["id"]

    for t in teams:
        client.post(f"/api/v1/tournaments/{tour_id}/teams?team_id={t['id']}", headers=auth_headers)

    # Generate league fixtures (6 matches)
    client.post(f"/api/v1/tournaments/{tour_id}/fixtures/generate", json={"home_away": False, "over_limit": 1}, headers=auth_headers)
    client.post(f"/api/v1/tournaments/{tour_id}/fixtures/publish", headers=auth_headers)

    # Let's abandon all matches to complete the league stage quickly
    # (abandoned matches count as completed for progression, both get 1 point)
    dash = client.get(f"/api/v1/tournaments/{tour_id}/dashboard").json()
    for m in dash["upcoming_matches"]:
        # Mark match status as abandoned
        # Wait, matches router does not have a dedicated abandon endpoint, but we can set status to abandoned!
        # Wait, does the backend models/routers support abandoning?
        # Let's check: in backend/app/models/cricket.py:
        #   status = Column(String, default="scheduled") # ... completed, abandoned
        # How do we abandon a match? Can we do it via SQLAdmin or is there an API route?
        # Wait, we can implement a PUT or POST to /matches/{id}/status or update it in conftest/database directly, OR
        # we can just complete the matches by submitting 1 ball and completing them!
        # Completing matches by scoring them is extremely easy! Let's score each match: 1 ball (1 run), then end innings, then end match.
        # Wait, since over_limit is 1, let's write a helper to complete a match:
        pass
        
    # Let's write a helper to complete match `m_id` with `t1` winning
    def play_short_match(m_id, t1, t2):
        client.post(f"/api/v1/matches/{m_id}/toss", json={"toss_winner_id": t1, "toss_decision": "bat"}, headers=auth_headers)
        t1_players = client.get(f"/api/v1/teams/{t1}").json()["players"]
        t2_players = client.get(f"/api/v1/teams/{t2}").json()["players"]
        client.post(f"/api/v1/matches/{m_id}/squads", json={"team_id": t1, "players": [{"player_id": p["id"]} for p in t1_players]}, headers=auth_headers)
        client.post(f"/api/v1/matches/{m_id}/squads", json={"team_id": t2, "players": [{"player_id": p["id"]} for p in t2_players]}, headers=auth_headers)
        
        # Innings 1: 6 runs
        client.post(f"/api/v1/matches/{m_id}/balls", json={
            "bowler_id": t2_players[1]["id"], "batsman_id": t1_players[0]["id"], "non_striker_id": t1_players[1]["id"],
            "runs_batsman": 6, "runs_extras": 0, "extra_type": "none", "is_wicket": False
        }, headers=auth_headers)
        # 6 balls of 0 runs to finish over
        for _ in range(5):
            client.post(f"/api/v1/matches/{m_id}/balls", json={
                "bowler_id": t2_players[1]["id"], "batsman_id": t1_players[0]["id"], "non_striker_id": t1_players[1]["id"],
                "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": False
            }, headers=auth_headers)
        
        # Innings 2: 1 run
        client.post(f"/api/v1/matches/{m_id}/balls", json={
            "bowler_id": t1_players[1]["id"], "batsman_id": t2_players[0]["id"], "non_striker_id": t2_players[1]["id"],
            "runs_batsman": 1, "runs_extras": 0, "extra_type": "none", "is_wicket": False
        }, headers=auth_headers)
        for _ in range(5):
            client.post(f"/api/v1/matches/{m_id}/balls", json={
                "bowler_id": t1_players[1]["id"], "batsman_id": t2_players[0]["id"], "non_striker_id": t2_players[1]["id"],
                "runs_batsman": 0, "runs_extras": 0, "extra_type": "none", "is_wicket": False
            }, headers=auth_headers)

    # Let's play all 6 league matches:
    # Match 1: Team 0 vs Team 1
    # Match 2: Team 0 vs Team 2
    # Match 3: Team 0 vs Team 3
    # Match 4: Team 1 vs Team 2
    # Match 5: Team 1 vs Team 3
    # Match 6: Team 2 vs Team 3
    # This guarantees Team 0 has 3 wins (6 pts), Team 1 has 2 wins (4 pts), Team 2 has 1 win (2 pts), Team 3 has 0 wins (0 pts).
    # Standings will be: T0, T1, T2, T3.
    # Semi Final fixtures generated automatically should be: SF1 (T0 vs T3), SF2 (T1 vs T2).
    dash = client.get(f"/api/v1/tournaments/{tour_id}/dashboard").json()
    for m in dash["upcoming_matches"]:
        t1 = m["team1_id"]
        t2 = m["team2_id"]
        # Make the lower-indexed team win
        winner = t1 if teams.index(next(x for x in teams if x["id"] == t1)) < teams.index(next(x for x in teams if x["id"] == t2)) else t2
        loser = t2 if winner == t1 else t1
        play_short_match(m["id"], winner, loser)

    # Check that semi-final matches are generated automatically
    dash2 = client.get(f"/api/v1/tournaments/{tour_id}/dashboard").json()
    assert len(dash2["upcoming_matches"]) == 2
    assert dash2["upcoming_matches"][0]["tournament_stage"] == "semi_final"
    assert dash2["upcoming_matches"][0]["bracket_code"] == "SF1"
    
    # Play SF1 (winner Team 0) and SF2 (winner Team 1)
    sf1_match = next(m for m in dash2["upcoming_matches"] if m["bracket_code"] == "SF1")
    sf2_match = next(m for m in dash2["upcoming_matches"] if m["bracket_code"] == "SF2")
    play_short_match(sf1_match["id"], sf1_match["team1_id"], sf1_match["team2_id"]) # Team 0 wins
    play_short_match(sf2_match["id"], sf2_match["team1_id"], sf2_match["team2_id"]) # Team 1 wins

    # Check that final match is generated
    dash3 = client.get(f"/api/v1/tournaments/{tour_id}/dashboard").json()
    assert len(dash3["upcoming_matches"]) == 1
    final = dash3["upcoming_matches"][0]
    assert final["tournament_stage"] == "final"
    assert final["bracket_code"] == "F"

    # Play Final (winner Team 0)
    play_short_match(final["id"], final["team1_id"], final["team2_id"])

    # Verify tournament completed and Team 0 is winner
    dash4 = client.get(f"/api/v1/tournaments/{tour_id}/dashboard").json()
    assert dash4["summary"]["status"] == "completed"
    assert dash4["summary"]["winner_name"] == "Team_0"
