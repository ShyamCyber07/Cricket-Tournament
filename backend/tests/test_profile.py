import pytest
from app.models.user import User, UserActivity, UserAchievement
from app.models.cricket import Player

def test_get_profile(client, auth_headers, db):
    response = client.get("/api/v1/profile/", headers=auth_headers)
    assert response.status_code == 200
    res_data = response.json()
    assert res_data["email"] == "testscorer@example.com"
    assert res_data["username"] == "testscorer"
    assert "joined_at" in res_data

def test_update_profile_success(client, auth_headers, db):
    response = client.put(
        "/api/v1/profile/",
        headers=auth_headers,
        json={
            "full_name": "Updated Scorer",
            "bio": "Expert scorer",
            "profile_picture": "🏏"
        }
    )
    assert response.status_code == 200
    res_data = response.json()
    assert res_data["full_name"] == "Updated Scorer"
    assert res_data["bio"] == "Expert scorer"
    assert res_data["profile_picture"] == "🏏"
    
    # Verify unique username constraint
    clash_user = User(
        email="clash@example.com",
        username="clashusername",
        hashed_password="somepassword"
    )
    db.add(clash_user)
    db.commit()
    
    response = client.put(
        "/api/v1/profile/",
        headers=auth_headers,
        json={"username": "clashusername"}
    )
    assert response.status_code == 400
    assert "Username is already taken" in response.json()["detail"]

def test_get_profile_stats_default(client, auth_headers, db):
    response = client.get("/api/v1/profile/stats", headers=auth_headers)
    assert response.status_code == 200
    res_data = response.json()
    assert res_data["batting"]["runs"] == 0
    assert res_data["bowling"]["wickets"] == 0

def test_get_profile_activity_and_achievements(client, auth_headers, db):
    response = client.get("/api/v1/profile/activity", headers=auth_headers)
    assert response.status_code == 200
    activities = response.json()
    assert len(activities) > 0
    
    response = client.get("/api/v1/profile/achievements", headers=auth_headers)
    assert response.status_code == 200
    achievements = response.json()
    assert len(achievements) == 6
    # All locked initially as no matches are played
    for ach in achievements:
        assert ach["is_unlocked"] is False
