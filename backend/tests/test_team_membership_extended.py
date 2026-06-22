import pytest
from uuid import UUID
from app.models.user import User
from app.models.cricket import Team, TeamMember, Notification
from app.core.security import get_password_hash

def helper_create_and_login_user(db, client, email, username, password="Password123!"):
    # 1. Create user in DB
    user = User(
        email=email,
        username=username,
        hashed_password=get_password_hash(password),
        full_name=f"Full {username}",
        email_verified=True,
        profile_completed=True
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # 2. Login to get token
    response = client.post(
        "/api/v1/auth/login",
        data={"username": email, "password": password}
    )
    assert response.status_code == 200, f"Failed to login user {email}: {response.text}"
    token = response.json()["access_token"]
    return user, {"Authorization": f"Bearer {token}"}

def test_invitation_flow(db, client, auth_headers):
    # 1. Create a team with the captain (auth_headers is testscorer@example.com)
    # The team creation automatically adds the creator as a captain in team_members
    create_response = client.post(
        "/api/v1/teams/",
        json={"name": "Invitors XI"},
        headers=auth_headers
    )
    assert create_response.status_code == 201
    team_id = create_response.json()["id"]

    # 2. Create and login user to invite
    invitee_user, invitee_headers = helper_create_and_login_user(db, client, "invitee@example.com", "invitee")

    # 3. Captain invites user
    invite_response = client.post(
        f"/api/v1/teams/{team_id}/members",
        json={"email": "invitee@example.com"},
        headers=auth_headers
    )
    assert invite_response.status_code == 200
    invite_data = invite_response.json()
    assert invite_data["status"] == "invited"

    # 4. Verify user has notification
    notif_response = client.get("/api/v1/notifications/", headers=invitee_headers)
    assert notif_response.status_code == 200
    notifications = notif_response.json()
    assert len(notifications) == 1
    assert notifications[0]["type"] == "invitation_received"
    assert "invited to join team" in notifications[0]["message"]
    notif_id = notifications[0]["id"]

    # 5. List invitations for the invitee
    my_invitations_response = client.get("/api/v1/teams/my-invitations", headers=invitee_headers)
    assert my_invitations_response.status_code == 200
    invitations = my_invitations_response.json()
    assert len(invitations) == 1
    assert invitations[0]["team"]["id"] == team_id
    assert invitations[0]["status"] == "invited"

    # 6. Mark notification as read
    read_response = client.post(f"/api/v1/notifications/{notif_id}/read", headers=invitee_headers)
    assert read_response.status_code == 200
    assert read_response.json()["is_read"] is True

    # 7. Invitee accepts invitation
    accept_response = client.post(
        f"/api/v1/teams/{team_id}/invitations/accept",
        headers=invitee_headers
    )
    assert accept_response.status_code == 200
    assert accept_response.json()["status"] == "active"

    # 8. Verify captain received a notification of acceptance
    captain_notif_response = client.get("/api/v1/notifications/", headers=auth_headers)
    assert captain_notif_response.status_code == 200
    captain_notifications = captain_notif_response.json()
    assert len(captain_notifications) == 1
    assert captain_notifications[0]["type"] == "invitation_accepted"

def test_invitation_rejection_flow(db, client, auth_headers):
    # 1. Create a team
    create_response = client.post(
        "/api/v1/teams/",
        json={"name": "Rejection XI"},
        headers=auth_headers
    )
    assert create_response.status_code == 201
    team_id = create_response.json()["id"]

    # 2. Create and login user to invite
    invitee_user, invitee_headers = helper_create_and_login_user(db, client, "reject_invitee@example.com", "reject_invitee")

    # 3. Captain invites user
    invite_response = client.post(
        f"/api/v1/teams/{team_id}/members",
        json={"email": "reject_invitee@example.com"},
        headers=auth_headers
    )
    assert invite_response.status_code == 200

    # 4. Invitee rejects invitation
    reject_response = client.post(
        f"/api/v1/teams/{team_id}/invitations/reject",
        headers=invitee_headers
    )
    assert reject_response.status_code == 204

    # 5. Verify TeamMember record deleted
    member_record = db.query(TeamMember).filter(
        TeamMember.team_id == UUID(team_id),
        TeamMember.user_id == invitee_user.id
    ).first()
    assert member_record is None

    # 6. Verify captain received a notification of rejection
    captain_notif_response = client.get("/api/v1/notifications/", headers=auth_headers)
    assert captain_notif_response.status_code == 200
    captain_notifications = captain_notif_response.json()
    assert len(captain_notifications) == 1
    assert captain_notifications[0]["type"] == "invitation_rejected"

def test_join_request_rejection_flow(db, client, auth_headers):
    # 1. Create a team
    create_response = client.post(
        "/api/v1/teams/",
        json={"name": "Join Request XI"},
        headers=auth_headers
    )
    assert create_response.status_code == 201
    team_id = create_response.json()["id"]

    # 2. Create and login user who wants to join
    requester, requester_headers = helper_create_and_login_user(db, client, "requester@example.com", "requester")

    # 3. User requests to join
    join_req_response = client.post(
        f"/api/v1/teams/{team_id}/join-request",
        headers=requester_headers
    )
    assert join_req_response.status_code == 200
    assert join_req_response.json()["status"] == "pending"

    # 4. Captain rejects join request
    reject_req_response = client.post(
        f"/api/v1/teams/{team_id}/reject-request",
        json={"user_id": str(requester.id)},
        headers=auth_headers
    )
    assert reject_req_response.status_code == 204

    # 5. Verify TeamMember record deleted
    member_record = db.query(TeamMember).filter(
        TeamMember.team_id == UUID(team_id),
        TeamMember.user_id == requester.id
    ).first()
    assert member_record is None

    # 6. Verify requester received notification of rejection
    notif_response = client.get("/api/v1/notifications/", headers=requester_headers)
    assert notif_response.status_code == 200
    notifications = notif_response.json()
    assert len(notifications) == 1
    assert notifications[0]["type"] == "request_rejected"

def test_captain_management_and_permission_checks(db, client, auth_headers):
    # 1. Create team as Captain (creator user)
    create_response = client.post(
        "/api/v1/teams/",
        json={"name": "Captain XI", "description": "Original description"},
        headers=auth_headers
    )
    assert create_response.status_code == 201
    team_id = create_response.json()["id"]

    # Check initially saved description
    assert create_response.json()["description"] == "Original description"

    # 2. Create and login a player user
    player_user, player_headers = helper_create_and_login_user(db, client, "player@example.com", "player")

    # Make the player a member of the team
    member_assoc = TeamMember(
        team_id=UUID(team_id),
        user_id=player_user.id,
        role="player",
        status="active"
    )
    db.add(member_assoc)
    db.commit()

    # 3. Attempt editing team as player -> should return 403
    edit_by_player_response = client.put(
        f"/api/v1/teams/{team_id}",
        json={"name": "Player Hack Team", "description": "Hacked"},
        headers=player_headers
    )
    assert edit_by_player_response.status_code == 403

    # 4. Attempt deleting team as player -> should return 403
    delete_by_player_response = client.delete(
        f"/api/v1/teams/{team_id}",
        headers=player_headers
    )
    assert delete_by_player_response.status_code == 403

    # 5. Edit team as Captain -> should return 200
    edit_by_captain_response = client.put(
        f"/api/v1/teams/{team_id}",
        json={"name": "Captain XI Updated", "description": "Updated description"},
        headers=auth_headers
    )
    assert edit_by_captain_response.status_code == 200
    assert edit_by_captain_response.json()["name"] == "Captain XI Updated"
    assert edit_by_captain_response.json()["description"] == "Updated description"

    # 6. Delete team as Captain -> should return 204
    delete_by_captain_response = client.delete(
        f"/api/v1/teams/{team_id}",
        headers=auth_headers
    )
    assert delete_by_captain_response.status_code == 204

    # Verify team is deleted
    get_response = client.get(f"/api/v1/teams/{team_id}", headers=auth_headers)
    assert get_response.status_code == 404

def test_notifications_read_all(db, client, auth_headers):
    # Create multiple notifications for current user (via seed user from auth_headers)
    # Get current user from db
    user = db.query(User).filter(User.email == "testscorer@example.com").first()
    assert user is not None

    notif1 = Notification(user_id=user.id, title="Title 1", message="Msg 1", type="type1", is_read=False)
    notif2 = Notification(user_id=user.id, title="Title 2", message="Msg 2", type="type2", is_read=False)
    db.add(notif1)
    db.add(notif2)
    db.commit()

    # Verify notifications exist
    notif_response = client.get("/api/v1/notifications/", headers=auth_headers)
    assert notif_response.status_code == 200
    assert len(notif_response.json()) == 2
    assert notif_response.json()[0]["is_read"] is False

    # Mark all read
    read_all_response = client.post("/api/v1/notifications/read-all", headers=auth_headers)
    assert read_all_response.status_code == 204

    # Verify notifications are now marked read
    notif_response_after = client.get("/api/v1/notifications/", headers=auth_headers)
    assert notif_response_after.status_code == 200
    assert len(notif_response_after.json()) == 2
    assert notif_response_after.json()[0]["is_read"] is True
    assert notif_response_after.json()[1]["is_read"] is True
