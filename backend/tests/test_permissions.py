import pytest
from uuid import UUID
from app.models.user import User
from app.models.cricket import Team, TeamMember
from app.core.security import get_password_hash
from backend.tests.test_team_membership_extended import helper_create_and_login_user

def test_captain_and_vice_captain_permissions(db, client, auth_headers):
    # 1. Create a team with Captain (auth_headers)
    create_res = client.post(
        "/api/v1/teams/",
        json={"name": "Permissions XI"},
        headers=auth_headers
    )
    assert create_res.status_code == 201
    team_id = create_res.json()["id"]

    # 2. Create Vice Captain and Player
    vc_user, vc_headers = helper_create_and_login_user(db, client, "vc@permissions.com", "vc_user")
    player_user, player_headers = helper_create_and_login_user(db, client, "player@permissions.com", "player_user")
    other_user, other_headers = helper_create_and_login_user(db, client, "other@permissions.com", "other_user")

    # 3. Captain invites VC and Player, and they accept
    # Invite VC
    res = client.post(f"/api/v1/teams/{team_id}/members", json={"email": "vc@permissions.com"}, headers=auth_headers)
    assert res.status_code == 200
    res = client.post(f"/api/v1/teams/{team_id}/invitations/accept", headers=vc_headers)
    assert res.status_code == 200

    # Invite Player
    res = client.post(f"/api/v1/teams/{team_id}/members", json={"email": "player@permissions.com"}, headers=auth_headers)
    assert res.status_code == 200
    res = client.post(f"/api/v1/teams/{team_id}/invitations/accept", headers=player_headers)
    assert res.status_code == 200

    # Promote vc_user to vice_captain role
    res = client.put(f"/api/v1/teams/{team_id}/members/{vc_user.id}/role", json={"role": "vice_captain"}, headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["role"] == "vice_captain"

    # --- SQUAD CONFIGURATION TESTS ---
    # 4. Normal Player attempts to update squad config -> 403
    squad_payload = {
        "members": [
            {
                "user_id": str(player_user.id),
                "is_playing_xi": True,
                "is_wicketkeeper": True,
                "jersey_number": 99,
                "batting_order": 3,
                "bowling_order": None,
                "is_available": True
            }
        ]
    }
    res = client.put(f"/api/v1/teams/{team_id}/squad-config", json=squad_payload, headers=player_headers)
    assert res.status_code == 403

    # 5. Vice Captain attempts to update squad config -> 403
    res = client.put(f"/api/v1/teams/{team_id}/squad-config", json=squad_payload, headers=vc_headers)
    assert res.status_code == 403

    # 6. Captain updates squad config -> 200
    res = client.put(f"/api/v1/teams/{team_id}/squad-config", json=squad_payload, headers=auth_headers)
    assert res.status_code == 200
    res_data = res.json()
    assert len(res_data) == 1
    assert res_data[0]["user_id"] == str(player_user.id)
    assert res_data[0]["is_playing_xi"] is True
    assert res_data[0]["is_wicketkeeper"] is True
    assert res_data[0]["jersey_number"] == 99
    assert res_data[0]["batting_order"] == 3
    assert res_data[0]["is_available"] is True

    # --- VICE CAPTAIN OPERATIONS TESTS ---
    # 7. VC invites a player -> 200 (allowed)
    res = client.post(f"/api/v1/teams/{team_id}/members", json={"email": "other@permissions.com"}, headers=vc_headers)
    assert res.status_code == 200
    assert res.json()["status"] == "invited"

    # Revoke invitation by VC (Remove Player who is invited) -> 204 (allowed)
    res = client.delete(f"/api/v1/teams/{team_id}/members/{other_user.id}", headers=vc_headers)
    assert res.status_code == 204

    # 8. Join request flow
    # Send join request as other_user
    res = client.post(f"/api/v1/teams/{team_id}/join-request", headers=other_headers)
    assert res.status_code == 200

    # VC rejects join request -> 204 (allowed)
    res = client.post(f"/api/v1/teams/{team_id}/reject-request", json={"user_id": str(other_user.id)}, headers=vc_headers)
    assert res.status_code == 204

    # Send join request again
    res = client.post(f"/api/v1/teams/{team_id}/join-request", headers=other_headers)
    assert res.status_code == 200

    # VC approves join request -> 200 (allowed)
    res = client.post(f"/api/v1/teams/{team_id}/approve-request", json={"user_id": str(other_user.id)}, headers=vc_headers)
    assert res.status_code == 200

    # 9. VC attempts to remove Captain -> 403 (restricted)
    captain_user_record = db.query(User).filter(User.email == "testscorer@example.com").first()
    res = client.delete(f"/api/v1/teams/{team_id}/members/{captain_user_record.id}", headers=vc_headers)
    assert res.status_code == 403

    # 10. VC attempts to remove another VC (first make other_user a VC)
    # Promote other_user to VC (must be done by Captain)
    res = client.put(f"/api/v1/teams/{team_id}/members/{other_user.id}/role", json={"role": "vice_captain"}, headers=auth_headers)
    assert res.status_code == 200

    # VC attempts to remove other_user VC -> 403 (restricted)
    res = client.delete(f"/api/v1/teams/{team_id}/members/{other_user.id}", headers=vc_headers)
    assert res.status_code == 403

    # VC attempts to remove Player -> 204 (allowed)
    res = client.delete(f"/api/v1/teams/{team_id}/members/{player_user.id}", headers=vc_headers)
    assert res.status_code == 204

    # --- DESTRUCTIVE ACTION RESTRICTIONS ---
    # 11. VC attempts to delete team -> 403 (restricted)
    res = client.delete(f"/api/v1/teams/{team_id}", headers=vc_headers)
    assert res.status_code == 403

    # 12. VC attempts to modify roles (transfer captaincy) -> 403 (restricted)
    res = client.put(f"/api/v1/teams/{team_id}/members/{other_user.id}/role", json={"role": "captain"}, headers=vc_headers)
    assert res.status_code == 403
