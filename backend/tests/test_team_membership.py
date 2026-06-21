import pytest
from app.models.cricket import Team, TeamMember
from app.models.user import User

def test_team_membership_flows(client, db):
    # Register Captain and Player users
    res_cap = client.post("/api/v1/auth/signup", json={
        "username": "captain_user",
        "email": "captain@cricup.com",
        "password": "Password123!",
        "confirm_password": "Password123!"
    })
    res_player1 = client.post("/api/v1/auth/signup", json={
        "username": "player_one",
        "email": "player1@cricup.com",
        "password": "Password123!",
        "confirm_password": "Password123!"
    })
    res_player2 = client.post("/api/v1/auth/signup", json={
        "username": "player_two",
        "email": "player2@cricup.com",
        "password": "Password123!",
        "confirm_password": "Password123!"
    })
    assert res_cap.status_code == 201
    assert res_player1.status_code == 201
    assert res_player2.status_code == 201

    # Verify emails in db
    u_cap = db.query(User).filter(User.email == "captain@cricup.com").first()
    u_p1 = db.query(User).filter(User.email == "player1@cricup.com").first()
    u_p2 = db.query(User).filter(User.email == "player2@cricup.com").first()
    u_cap.email_verified = True
    u_p1.email_verified = True
    u_p2.email_verified = True
    db.commit()

    # Log in all users
    token_cap = client.post("/api/v1/auth/login", data={"username": "captain@cricup.com", "password": "Password123!"}).json()["access_token"]
    token_p1 = client.post("/api/v1/auth/login", data={"username": "player1@cricup.com", "password": "Password123!"}).json()["access_token"]
    token_p2 = client.post("/api/v1/auth/login", data={"username": "player2@cricup.com", "password": "Password123!"}).json()["access_token"]

    headers_cap = {"Authorization": f"Bearer {token_cap}"}
    headers_p1 = {"Authorization": f"Bearer {token_p1}"}
    headers_p2 = {"Authorization": f"Bearer {token_p2}"}

    # 1. Captain creates a team
    res_team = client.post("/api/v1/teams/", json={"name": "Test Membership Team"}, headers=headers_cap)
    assert res_team.status_code == 201
    team_id = res_team.json()["id"]

    # 2. Check if creator is auto-added as Captain in team_members
    import uuid as uuid_pkg
    member_rec = db.query(TeamMember).filter(
        TeamMember.team_id == uuid_pkg.UUID(team_id),
        TeamMember.user_id == u_cap.id
    ).first()
    assert member_rec is not None
    assert member_rec.role == "captain"
    assert member_rec.status == "active"

    # 3. GET /my-teams for captain -> should contain the new team
    res_my_teams = client.get("/api/v1/teams/my-teams", headers=headers_cap)
    assert res_my_teams.status_code == 200
    my_teams = res_my_teams.json()
    assert len(my_teams) == 1
    assert my_teams[0]["team"]["id"] == team_id
    assert my_teams[0]["role"] == "captain"
    assert my_teams[0]["status"] == "active"

    # 4. Player 1 sends a join request -> POST /teams/{id}/join-request
    res_join = client.post(f"/api/v1/teams/{team_id}/join-request", headers=headers_p1)
    assert res_join.status_code == 200
    assert res_join.json()["status"] == "pending"
    assert res_join.json()["role"] == "player"

    # 5. GET /my-teams for Player 1 -> should show the team with status "pending"
    res_my_teams_p1 = client.get("/api/v1/teams/my-teams", headers=headers_p1)
    assert res_my_teams_p1.status_code == 200
    my_teams_p1 = res_my_teams_p1.json()
    assert len(my_teams_p1) == 1
    assert my_teams_p1[0]["status"] == "pending"

    # 6. Player 2 tries to approve Player 1's request -> 403 Forbidden (not captain)
    res_approve_fail = client.post(
        f"/api/v1/teams/{team_id}/approve-request",
        json={"user_id": str(u_p1.id)},
        headers=headers_p2
    )
    assert res_approve_fail.status_code == 403

    # 7. Captain approves Player 1's request -> 200 OK
    res_approve = client.post(
        f"/api/v1/teams/{team_id}/approve-request",
        json={"user_id": str(u_p1.id)},
        headers=headers_cap
    )
    assert res_approve.status_code == 200
    assert res_approve.json()["status"] == "active"

    # 8. Captain adds Player 2 directly -> POST /teams/{id}/members
    res_add_p2 = client.post(
        f"/api/v1/teams/{team_id}/members",
        json={"email": "player2@cricup.com"},
        headers=headers_cap
    )
    assert res_add_p2.status_code == 200
    assert res_add_p2.json()["status"] == "active"
    assert res_add_p2.json()["role"] == "player"

    # 9. GET /teams/{id}/members
    res_members = client.get(f"/api/v1/teams/{team_id}/members", headers=headers_cap)
    assert res_members.status_code == 200
    members = res_members.json()
    assert len(members) == 3  # Captain, Player 1, Player 2
    emails = [m["user_email"] for m in members]
    assert "captain@cricup.com" in emails
    assert "player1@cricup.com" in emails
    assert "player2@cricup.com" in emails

    # 10. Captain removes Player 2 -> DELETE /teams/{id}/members/{user_id}
    res_remove = client.delete(f"/api/v1/teams/{team_id}/members/{u_p2.id}", headers=headers_cap)
    assert res_remove.status_code == 204

    # Verify Player 2 is gone from members list
    res_members_post = client.get(f"/api/v1/teams/{team_id}/members", headers=headers_cap)
    assert len(res_members_post.json()) == 2
