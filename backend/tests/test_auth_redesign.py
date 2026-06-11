import pytest
from datetime import datetime, timedelta
from app.models.user import User, RefreshToken
from app.core.security import get_password_hash
from app.routers.auth import get_utc_now

def test_signup_password_complexity(client):
    # Too short
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "shortpwd",
            "email": "short@example.com",
            "password": "Ab1!",
            "confirm_password": "Ab1!"
        }
    )
    assert response.status_code == 422
    assert "at least 8 characters" in response.text

    # No uppercase
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "noupper",
            "email": "noupper@example.com",
            "password": "password123!",
            "confirm_password": "password123!"
        }
    )
    assert response.status_code == 422
    assert "uppercase" in response.text

    # No special character
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "nospec",
            "email": "nospec@example.com",
            "password": "Password123",
            "confirm_password": "Password123"
        }
    )
    assert response.status_code == 422
    assert "special character" in response.text

    # Passwords do not match
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "mismatch",
            "email": "mismatch@example.com",
            "password": "Password123!",
            "confirm_password": "Password1234!"
        }
    )
    assert response.status_code == 422
    assert "do not match" in response.text

def test_successful_signup_and_otp_verification(client, db):
    # Sign up
    response = client.post(
        "/api/v1/auth/signup",
        json={
            "username": "validuser",
            "email": "valid@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!"
        }
    )
    assert response.status_code == 201
    
    # Query OTP from db to bypass email service
    user = db.query(User).filter(User.email == "valid@example.com").first()
    assert user is not None
    assert user.email_verified is False
    assert user.otp_code is not None

    # Try login before verification - should fail
    login_response = client.post(
        "/api/v1/auth/login",
        data={"username": "valid@example.com", "password": "Password123!"}
    )
    assert login_response.status_code == 400
    assert "verified" in login_response.json()["detail"]

    # Verify OTP
    verify_response = client.post(
        "/api/v1/auth/verify-otp",
        json={"email": "valid@example.com", "otp_code": user.otp_code}
    )
    assert verify_response.status_code == 200
    res_data = verify_response.json()
    assert "access_token" in res_data
    assert "refresh_token" in res_data
    assert res_data["email_verified"] is True
    assert res_data["profile_completed"] is False

    # Check database state
    db.refresh(user)
    assert user.email_verified is True
    assert user.otp_code is None

def test_otp_resend_rate_limit(client, db):
    # Signup
    client.post(
        "/api/v1/auth/signup",
        json={
            "username": "ratelimit",
            "email": "ratelimit@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!"
        }
    )

    # Immediately resend OTP - should hit 429
    response = client.post(
        "/api/v1/auth/resend-otp",
        json={"email": "ratelimit@example.com"}
    )
    assert response.status_code == 429
    assert "wait" in response.json()["detail"]

    # Mock time passing (set last_otp_sent_at to 65s ago)
    user = db.query(User).filter(User.email == "ratelimit@example.com").first()
    user.last_otp_sent_at = get_utc_now() - timedelta(seconds=65)
    db.commit()

    # Resend should succeed now
    response = client.post(
        "/api/v1/auth/resend-otp",
        json={"email": "ratelimit@example.com"}
    )
    assert response.status_code == 200
    assert "resent" in response.json()["message"]

def test_brute_force_lockout(client, db):
    # Seed verified user
    user = User(
        email="lockout@example.com",
        username="lockout",
        hashed_password=get_password_hash("Password123!"),
        email_verified=True,
        profile_completed=True
    )
    db.add(user)
    db.commit()

    # Fail login 4 times
    for _ in range(4):
        response = client.post(
            "/api/v1/auth/login",
            data={"username": "lockout@example.com", "password": "WrongPassword!"}
        )
        assert response.status_code == 400

    # Locked out on the 5th attempt
    response = client.post(
        "/api/v1/auth/login",
        data={"username": "lockout@example.com", "password": "WrongPassword!"}
    )
    assert response.status_code == 400 # Still returns 400, but now lockout is set
    
    # 6th attempt should return 403 locked status
    response = client.post(
        "/api/v1/auth/login",
        data={"username": "lockout@example.com", "password": "Password123!"}
    )
    assert response.status_code == 403
    assert "locked" in response.json()["detail"]

    # Mock lockout expiry (lockout_until set in past)
    db.refresh(user)
    user.lockout_until = get_utc_now() - timedelta(seconds=1)
    db.commit()

    # Should log in successfully now
    response = client.post(
        "/api/v1/auth/login",
        data={"username": "lockout@example.com", "password": "Password123!"}
    )
    assert response.status_code == 200
    assert "access_token" in response.json()

def test_password_recovery_and_reset(client, db):
    # Seed user
    user = User(
        email="recover@example.com",
        username="recover",
        hashed_password=get_password_hash("OldPassword123!"),
        email_verified=True,
        profile_completed=True
    )
    db.add(user)
    db.commit()

    # Trigger forgot password
    response = client.post(
        "/api/v1/auth/forgot-password",
        json={"email": "recover@example.com"}
    )
    assert response.status_code == 200

    # Retrieve OTP
    db.refresh(user)
    otp = user.otp_code
    assert otp is not None

    # Reset password with invalid confirm
    response = client.post(
        "/api/v1/auth/reset-password",
        json={
            "email": "recover@example.com",
            "otp_code": otp,
            "new_password": "NewPassword123!",
            "confirm_password": "MismatchPassword!"
        }
    )
    assert response.status_code == 422

    # Reset password successfully
    response = client.post(
        "/api/v1/auth/reset-password",
        json={
            "email": "recover@example.com",
            "otp_code": otp,
            "new_password": "NewPassword123!",
            "confirm_password": "NewPassword123!"
        }
    )
    assert response.status_code == 200

    # Try logging in with new password
    response = client.post(
        "/api/v1/auth/login",
        data={"username": "recover@example.com", "password": "NewPassword123!"}
    )
    assert response.status_code == 200
    assert "access_token" in response.json()

def test_profile_completion(client, db):
    # Seed user needing completion
    user = User(
        email="onboard@example.com",
        username="onboard",
        hashed_password=get_password_hash("Password123!"),
        email_verified=True,
        profile_completed=False
    )
    db.add(user)
    db.commit()

    # Login to get token
    login_response = client.post(
        "/api/v1/auth/login",
        data={"username": "onboard@example.com", "password": "Password123!"}
    )
    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Complete Profile
    response = client.post(
        "/api/v1/auth/complete-profile",
        headers=headers,
        json={
            "full_name": "John Doe",
            "display_name": "JohnnyD",
            "profile_picture": "🏏",
            "country": "Australia",
            "favorite_team": "Melbourne Stars"
        }
    )
    assert response.status_code == 200
    res_data = response.json()
    assert res_data["full_name"] == "John Doe"
    assert res_data["display_name"] == "JohnnyD"
    assert res_data["profile_completed"] is True

    # Check player profile was updated/created
    db.refresh(user)
    assert user.profile_completed is True
    assert user.players is not None

def test_refresh_token_lifecycle(client, db):
    # Seed user
    user = User(
        email="refresh@example.com",
        username="refresh",
        hashed_password=get_password_hash("Password123!"),
        email_verified=True,
        profile_completed=True
    )
    db.add(user)
    db.commit()

    # Login to get refresh token
    login_response = client.post(
        "/api/v1/auth/login",
        data={"username": "refresh@example.com", "password": "Password123!"}
    )
    res_data = login_response.json()
    ref_token = res_data["refresh_token"]

    # Refresh
    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": ref_token}
    )
    assert refresh_response.status_code == 200
    assert "access_token" in refresh_response.json()

    # Logout
    headers = {"Authorization": f"Bearer {refresh_response.json()['access_token']}"}
    logout_response = client.post("/api/v1/auth/logout", headers=headers)
    assert logout_response.status_code == 200

    # Try refreshing after logout - should fail since token is deleted
    refresh_response2 = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": ref_token}
    )
    assert refresh_response2.status_code == 401
