import os
import pytest
from unittest.mock import patch, MagicMock
from app.core import storage
from app.core.config import settings

def test_upload_image_local_fallback(tmp_path):
    # Set CLOUDINARY_URL to empty to force local fallback
    with patch.object(settings, "CLOUDINARY_URL", ""):
        # Mock os.makedirs and open to avoid cluttering local filesystem, or just let it write to a temp file
        test_bytes = b"fake-image-bytes"
        filename = "test_fallback.jpg"
        
        # Patch the local save folder to be a temp dir
        with patch("os.makedirs") as mock_makedirs, \
             patch("builtins.open", mock_open()) as mock_file:
            url = storage.upload_image(test_bytes, filename)
            
            assert url == f"/static/uploads/{filename}"
            mock_makedirs.assert_called_once_with(os.path.join("static", "uploads"), exist_ok=True)

def test_upload_image_cloudinary_success():
    with patch.object(settings, "CLOUDINARY_URL", "cloudinary://api_key:api_secret@cloud_name"):
        test_bytes = b"fake-image-bytes"
        filename = "test_cloud.jpg"
        
        mock_upload_response = {"secure_url": "https://res.cloudinary.com/cloud_name/image/upload/v123/cricup/test_cloud.jpg"}
        
        with patch("cloudinary.uploader.upload", return_value=mock_upload_response) as mock_upload:
            url = storage.upload_image(test_bytes, filename, folder="cricup")
            
            assert url == "https://res.cloudinary.com/cloud_name/image/upload/v123/cricup/test_cloud.jpg"
            mock_upload.assert_called_once()
            # The first arg is io.BytesIO(test_bytes), check folder, public_id, resource_type
            kwargs = mock_upload.call_args[1]
            assert kwargs["folder"] == "cricup"
            assert kwargs["public_id"] == "test_cloud"
            assert kwargs["resource_type"] == "image"

def test_upload_image_cloudinary_failure_fallback():
    # If Cloudinary fails, it should log the error and fall back to local storage
    with patch.object(settings, "CLOUDINARY_URL", "cloudinary://api_key:api_secret@cloud_name"):
        test_bytes = b"fake-image-bytes"
        filename = "test_failed_cloud.jpg"
        
        with patch("cloudinary.uploader.upload", side_effect=Exception("Cloudinary error")), \
             patch("os.makedirs") as mock_makedirs, \
             patch("builtins.open", mock_open()):
            url = storage.upload_image(test_bytes, filename)
            
            # Should fallback to local path
            assert url == f"/static/uploads/{filename}"
            mock_makedirs.assert_called_once()

def test_delete_image_cloudinary():
    with patch.object(settings, "CLOUDINARY_URL", "cloudinary://api_key:api_secret@cloud_name"):
        url = "https://res.cloudinary.com/cloud_name/image/upload/v12345/cricup/test_cloud.jpg"
        
        mock_destroy_response = {"result": "ok"}
        with patch("cloudinary.uploader.destroy", return_value=mock_destroy_response) as mock_destroy:
            success = storage.delete_image(url)
            assert success is True
            mock_destroy.assert_called_once_with("cricup/test_cloud")

def test_delete_image_local():
    url = "/static/uploads/test_local.jpg"
    
    with patch("os.path.exists", return_value=True), \
         patch("os.remove") as mock_remove:
        success = storage.delete_image(url)
        assert success is True
        mock_remove.assert_called_once_with("static/uploads/test_local.jpg")

# Helper to mock file open
def mock_open():
    from unittest.mock import mock_open as unittest_mock_open
    return unittest_mock_open()
