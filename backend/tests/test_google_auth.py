import time
import pytest
from unittest.mock import patch, MagicMock
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from jose import jwk, jwt
from app.models.user import User
from app.models.cricket import Player

# 1. Generate real RSA key pair using cryptography
private_key_obj = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048
)

PRIVATE_KEY_PEM = private_key_obj.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption()
).decode("utf-8")

public_key_obj = private_key_obj.public_key()
PUBLIC_KEY_PEM = public_key_obj.public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo
).decode("utf-8")

# 2. Construct public JWK dict using jose.jwk.construct
jwk_key = jwk.construct(PUBLIC_KEY_PEM, algorithm="RS256")
PUBLIC_JWK = jwk_key.to_dict()
PUBLIC_JWK["kid"] = "test_key_id_1"
PUBLIC_JWK["use"] = "sig"
PUBLIC_JWK["alg"] = "RS256"

MOCK_JWKS = {
    "keys": [PUBLIC_JWK]
}

def get_mock_jwt(payload, headers=None):
    if headers is None:
        headers = {"kid": "test_key_id_1"}
    # Sign using the PEM private key
    return jwt.encode(payload, PRIVATE_KEY_PEM, algorithm="RS256", headers=headers)

@pytest.fixture
def mock_google_certs():
    with patch("httpx.get") as mock_get:
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = MOCK_JWKS
        mock_get.return_value = mock_response
        yield mock_get

def test_google_login_success_cryptographic(client, db, mock_google_certs):
    # Create valid Google payload
    claims = {
        "email": "realgoogle@example.com",
        "name": "Real Google User",
        "picture": "https://example.com/real_photo.png",
        "sub": "real_google_subject_12345",
        "aud": "test_google_client_id",
        "iss": "https://accounts.google.com",
        "exp": int(time.time()) + 3600
    }
    token = get_mock_jwt(claims)

    response = client.post(
        "/api/v1/auth/google",
        json={"token": token}
    )
    assert response.status_code == 200
    res_data = response.json()
    assert "access_token" in res_data
    assert res_data["email_verified"] is True
    assert res_data["profile_completed"] is False

    # Verify user state in DB
    user = db.query(User).filter(User.google_id == "real_google_subject_12345").first()
    assert user is not None
    assert user.email == "realgoogle@example.com"
    assert user.provider == "google"
    assert user.email_verified is True
    assert user.full_name == "Real Google User"
    assert user.profile_photo_url == "https://example.com/real_photo.png"

    player = db.query(Player).filter(Player.user_id == user.id).first()
    assert player is not None
    assert player.name == "Real Google User"
    assert player.role == "all_rounder"

def test_google_login_invalid_signature(client, mock_google_certs):
    claims = {
        "email": "fake@example.com",
        "sub": "fake_sub",
        "aud": "test_google_client_id",
        "iss": "https://accounts.google.com",
        "exp": int(time.time()) + 3600
    }
    valid_token = get_mock_jwt(claims)
    parts = valid_token.split(".")
    parts[2] = parts[2][:-5] + "A" * 5
    invalid_token = ".".join(parts)

    response = client.post(
        "/api/v1/auth/google",
        json={"token": invalid_token}
    )
    assert response.status_code == 400
    assert "verification failed" in response.json()["detail"]

def test_google_login_expired_token(client, mock_google_certs):
    claims = {
        "email": "expired@example.com",
        "sub": "expired_sub",
        "aud": "test_google_client_id",
        "iss": "https://accounts.google.com",
        "exp": int(time.time()) - 3600
    }
    token = get_mock_jwt(claims)

    response = client.post(
        "/api/v1/auth/google",
        json={"token": token}
    )
    assert response.status_code == 400
    assert "verification failed" in response.json()["detail"]
    assert "expired" in response.json()["detail"].lower()

def test_google_login_invalid_audience(client, mock_google_certs):
    claims = {
        "email": "wrong_aud@example.com",
        "sub": "wrong_aud_sub",
        "aud": "wrong_google_client_id",
        "iss": "https://accounts.google.com",
        "exp": int(time.time()) + 3600
    }
    token = get_mock_jwt(claims)

    response = client.post(
        "/api/v1/auth/google",
        json={"token": token}
    )
    assert response.status_code == 400
    assert "verification failed" in response.json()["detail"]
    assert "audience" in response.json()["detail"].lower()

def test_google_login_invalid_issuer(client, mock_google_certs):
    claims = {
        "email": "wrong_iss@example.com",
        "sub": "wrong_iss_sub",
        "aud": "test_google_client_id",
        "iss": "https://wrong-issuer.com",
        "exp": int(time.time()) + 3600
    }
    token = get_mock_jwt(claims)

    response = client.post(
        "/api/v1/auth/google",
        json={"token": token}
    )
    assert response.status_code == 400
    assert "verification failed" in response.json()["detail"]
    assert "issuer" in response.json()["detail"].lower()
