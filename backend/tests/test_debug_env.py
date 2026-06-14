import pytest
from app.core.config import settings

def test_debug_env_endpoint_development(client):
    settings.APP_ENV = "development"
    response = client.get("/api/v1/debug-env")
    assert response.status_code == 200

def test_debug_env_endpoint_production(client):
    settings.APP_ENV = "production"
    response = client.get("/api/v1/debug-env")
    assert response.status_code == 404
