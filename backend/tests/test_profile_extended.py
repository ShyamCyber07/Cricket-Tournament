import pytest
from app.models.user import User
from app.models.cricket import Team, TeamMember

def test_public_id_and_privacy_defaults(client, db):
    # Verify that a new user gets a default public_id and privacy_settings
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "tester_profile",
            "email": "tester_profile@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!"
        }
    )
    assert response.status_code == 201
    res_data = response.json()
    assert "public_id" in res_data
    assert res_data["public_id"].startswith("CU-")
    assert res_data["privacy_settings"] == "public"


def test_update_privacy_settings(client, auth_headers):
    # Retrieve current profile
    response = client.get("/api/v1/profile/", headers=auth_headers)
    assert response.status_code == 200
    
    # Update privacy settings to private
    response = client.put(
        "/api/v1/profile/",
        headers=auth_headers,
        json={"privacy_settings": "private"}
    )
    assert response.status_code == 200
    assert response.json()["privacy_settings"] == "private"


def test_public_profile_access_control(client, db, auth_headers):
    # Create a private user
    user_a = User(
        email="user_a@example.com",
        username="usera",
        public_id="CU-USERAA",
        privacy_settings="private",
        email_verified=True,
        profile_completed=True
    )
    db.add(user_a)
    db.commit()

    # The caller (testscorer@example.com via auth_headers) tries to view User A's private profile -> expect 403
    response = client.get(f"/api/v1/profile/public/CU-USERAA", headers=auth_headers)
    assert response.status_code == 403

    # Switch User A to public
    user_a.privacy_settings = "public"
    db.add(user_a)
    db.commit()

    # Caller tries to view User A's profile now -> expect 200
    response = client.get(f"/api/v1/profile/public/CU-USERAA", headers=auth_headers)
    assert response.status_code == 200


def test_search_players(client, db, auth_headers):
    # Add a user to search for
    user_s = User(
        email="searchme@example.com",
        username="search_unique_name",
        public_id="CU-SRCH01",
        full_name="Unique Search Name",
        privacy_settings="public",
        email_verified=True,
        profile_completed=True
    )
    db.add(user_s)
    db.commit()

    response = client.get("/api/v1/profile/search?query=unique", headers=auth_headers)
    assert response.status_code == 200
    res_data = response.json()
    assert len(res_data) > 0
    assert res_data[0]["username"] == "search_unique_name"


def test_team_code_and_join(client, db, auth_headers):
    # Fetch active user from db to get their id
    user = db.query(User).filter(User.email == "testscorer@example.com").first()
    
    # Create a team owned by someone else
    other_user = User(
        email="otherowner@example.com",
        username="otherowner",
        email_verified=True,
        profile_completed=True
    )
    db.add(other_user)
    db.commit()
    
    team = Team(
        name="Opposition CC",
        created_by=other_user.id,
        team_code="TC-OPP123"
    )
    db.add(team)
    db.commit()

    # User joins the team by code
    response = client.post(
        "/api/v1/teams/join-by-code",
        headers=auth_headers,
        json={"team_code": "TC-OPP123"}
    )
    assert response.status_code == 200
    assert response.json()["role"] == "player"
    assert response.json()["status"] == "active"


def test_username_validation_constraints(client, db):
    # Test reserved username
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "admin",
            "email": "admin@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!"
        }
    )
    assert response.status_code == 400
    assert "reserved" in response.json()["detail"].lower()

    # Test short username
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "ab",
            "email": "ab@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!"
        }
    )
    assert response.status_code == 400
    assert "characters" in response.json()["detail"]

    # Test invalid chars
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "user@name",
            "email": "username@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!"
        }
    )
    assert response.status_code == 400


def test_team_code_regeneration(client, db, auth_headers):
    # Get testscorer user
    user = db.query(User).filter(User.email == "testscorer@example.com").first()
    
    # Create team owned by caller
    team = Team(
        name="Scorers XI",
        created_by=user.id,
        team_code="TC-SC0001"
    )
    db.add(team)
    db.commit()
    
    # Regenerate team code
    response = client.post(
        f"/api/v1/teams/{team.id}/regenerate-code",
        headers=auth_headers
    )
    assert response.status_code == 200
    new_code = response.json()["team_code"]
    assert new_code != "TC-SC0001"
    assert new_code.startswith("TC-")

    # Verify old code is invalid
    response_join = client.post(
        "/api/v1/teams/join-by-code",
        headers=auth_headers,
        json={"team_code": "TC-SC0001"}
    )
    assert response_join.status_code == 404
