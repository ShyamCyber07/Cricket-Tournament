import pytest
from uuid import UUID

def test_toss_and_timeline_flow(client, auth_headers):
    # 1. Create Teams
    t1_res = client.post("/api/v1/teams/", json={"name": "Timeline T1", "slogan": "Go T1"}, headers=auth_headers)
    t2_res = client.post("/api/v1/teams/", json={"name": "Timeline T2", "slogan": "Go T2"}, headers=auth_headers)
    assert t1_res.status_code == 201
    assert t2_res.status_code == 201
    t1_id = t1_res.json()["id"]
    t2_id = t2_res.json()["id"]

    # 2. Create Match
    match_res = client.post(
        "/api/v1/matches/",
        json={
            "venue": "Timeline Arena",
            "match_date": "2026-06-12T10:00:00Z",
            "match_type": "T20",
            "over_limit": 20,
            "team1_id": t1_id,
            "team2_id": t2_id
        },
        headers=auth_headers
    )
    assert match_res.status_code == 201
    match_id = match_res.json()["id"]
    assert match_res.json()["status"] == "scheduled"
    assert match_res.json()["toss_winner_id"] is None
    assert match_res.json()["toss_decision"] is None

    # 3. Initiate Toss (Authorized Scorer/Creator)
    initiate_res = client.post(f"/api/v1/matches/{match_id}/toss/initiate", headers=auth_headers)
    assert initiate_res.status_code == 200
    initiate_data = initiate_res.json()
    assert initiate_data["status"] == "toss"
    toss_winner_id = initiate_data["toss_winner_id"]
    assert toss_winner_id in [t1_id, t2_id]
    assert initiate_data["toss_decision"] is None

    # 4. Attempt Duplicate Toss Initiation -> Should fail (HTTP 400)
    dup_res = client.post(f"/api/v1/matches/{match_id}/toss/initiate", headers=auth_headers)
    assert dup_res.status_code == 400
    assert "already been executed" in dup_res.json()["detail"]

    # 5. Check Match Activity Log for Toss Initiation
    act_res = client.get(f"/api/v1/matches/{match_id}/activities", headers=auth_headers)
    assert act_res.status_code == 200
    activities = act_res.json()
    assert len(activities) == 1
    assert activities[0]["action_type"] == "toss_initiated"
    assert "Secure backend selected winner" in activities[0]["description"]

    # 6. Submit Toss Decision
    decision_res = client.post(
        f"/api/v1/matches/{match_id}/toss/decision",
        json={"toss_decision": "bowl"},
        headers=auth_headers
    )
    assert decision_res.status_code == 200
    dec_data = decision_res.json()
    assert dec_data["status"] == "team_selection"
    assert dec_data["toss_decision"] == "bowl"

    # 7. Check Match Activity Log for Toss Decision
    act_res = client.get(f"/api/v1/matches/{match_id}/activities", headers=auth_headers)
    assert act_res.status_code == 200
    activities = act_res.json()
    assert len(activities) == 2
    assert activities[1]["action_type"] == "toss_decision"
    assert "won the toss and elected to bowl first" in activities[1]["description"]

    # 8. Reset Toss (Authorized Organizer/Admin - Creator acts as organizer since tournament is None, but let's check reset permission)
    reset_res = client.post(f"/api/v1/matches/{match_id}/toss/reset", headers=auth_headers)
    assert reset_res.status_code == 200
    reset_data = reset_res.json()
    assert reset_data["status"] == "scheduled"
    assert reset_data["toss_winner_id"] is None
    assert reset_data["toss_decision"] is None

    # 9. Verify Reset Log in activities
    act_res = client.get(f"/api/v1/matches/{match_id}/activities", headers=auth_headers)
    assert act_res.status_code == 200
    activities = act_res.json()
    assert len(activities) == 3
    assert activities[2]["action_type"] == "toss_reset"
    assert "Toss reset" in activities[2]["description"]


def test_toss_reset_unauthorized(client, auth_headers, db):
    # Setup second user
    signup_res = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "othercaptain",
            "email": "other@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!"
        }
    )
    assert signup_res.status_code == 201
    
    # Verify second user email
    from app.models.user import User
    user = db.query(User).filter(User.email == "other@example.com").first()
    user.email_verified = True
    db.commit()

    # Login second user
    login_res = client.post(
        "/api/v1/auth/login",
        data={"username": "other@example.com", "password": "Password123!"}
    )
    assert login_res.status_code == 200
    other_token = login_res.json()["access_token"]
    other_headers = {"Authorization": f"Bearer {other_token}"}

    # First user creates a team and match
    t1_res = client.post("/api/v1/teams/", json={"name": "Perm Team 1", "slogan": "S1"}, headers=auth_headers)
    t2_res = client.post("/api/v1/teams/", json={"name": "Perm Team 2", "slogan": "S2"}, headers=auth_headers)
    t1_id = t1_res.json()["id"]
    t2_id = t2_res.json()["id"]

    match_res = client.post(
        "/api/v1/matches/",
        json={
            "venue": "Perm Ground",
            "match_date": "2026-06-12T10:00:00Z",
            "match_type": "T20",
            "over_limit": 20,
            "team1_id": t1_id,
            "team2_id": t2_id
        },
        headers=auth_headers
    )
    match_id = match_res.json()["id"]

    # First user initiates toss
    client.post(f"/api/v1/matches/{match_id}/toss/initiate", headers=auth_headers)

    # Second user attempts to reset toss -> Should fail (HTTP 403)
    reset_res = client.post(f"/api/v1/matches/{match_id}/toss/reset", headers=other_headers)
    assert reset_res.status_code == 403
