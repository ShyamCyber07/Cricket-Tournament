import pytest
from app.core.config import settings

from unittest.mock import patch

def test_debug_env_endpoint_development(client):
    with patch.object(settings, "APP_ENV", "development"), \
         patch.dict("os.environ", {"ENABLE_DEBUG_ENDPOINTS": "true"}):
        response = client.get("/api/v1/debug-env")
        assert response.status_code == 200

def test_debug_env_endpoint_production(client):
    with patch.object(settings, "APP_ENV", "production"):
        response = client.get("/api/v1/debug-env")
        assert response.status_code == 404
