import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models.user import User
from app.core.security import get_password_hash
from app.core.config import settings

# Force a mock Google Client ID for test runs to prevent local .env leakage
settings.GOOGLE_CLIENT_ID = "test_google_client_id"

from sqlalchemy.pool import StaticPool

# Use isolated SQLite in-memory database for unit tests
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db():
    # Create tables
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def client(db):
    def override_get_db():
        try:
            yield db
        finally:
            pass
            
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()

@pytest.fixture(scope="function")
def auth_headers(client, db):
    # Create seed user
    user = User(
        email="testscorer@example.com",
        username="testscorer",
        hashed_password=get_password_hash("testpassword123"),
        full_name="Test Scorer",
        email_verified=True,
        profile_completed=True
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Login to get token
    response = client.post(
        "/api/v1/auth/login",
        data={"username": "testscorer@example.com", "password": "testpassword123"}
    )
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
