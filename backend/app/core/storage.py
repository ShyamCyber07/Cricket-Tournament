import os
import io
import logging
import cloudinary
import cloudinary.uploader
from app.core.config import settings

logger = logging.getLogger(__name__)

# Initialize Cloudinary if URL is provided
if settings.CLOUDINARY_URL:
    try:
        cloudinary.config(cloudinary_url=settings.CLOUDINARY_URL)
        logger.info("Cloudinary configured successfully.")
    except Exception as e:
        logger.error(f"Failed to configure Cloudinary with the provided URL: {e}", exc_info=True)
else:
    logger.warning("CLOUDINARY_URL not set. Falling back to local storage.")

def upload_image(file_bytes: bytes, filename: str, folder: str = "cricup") -> str:
    """
    Uploads an image. If CLOUDINARY_URL is configured, uploads to Cloudinary.
    Otherwise, saves to the local static/uploads directory as a fallback.
    """
    if settings.CLOUDINARY_URL:
        try:
            # Extract public_id without extension
            base_name = os.path.splitext(filename)[0]
            
            # Upload file directly from bytes
            res = cloudinary.uploader.upload(
                io.BytesIO(file_bytes),
                folder=folder,
                public_id=base_name,
                overwrite=True,
                resource_type="image"
            )
            secure_url = res.get("secure_url")
            if secure_url:
                logger.info(f"Successfully uploaded to Cloudinary: {secure_url}")
                return secure_url
        except Exception as e:
            logger.error(f"Cloudinary upload failed: {e}. Falling back to local storage.", exc_info=True)
            # Fall through to local storage if Cloudinary fails
            
    # Local Storage Fallback
    os.makedirs(os.path.join("static", "uploads"), exist_ok=True)
    filepath = os.path.join("static", "uploads", filename)
    with open(filepath, "wb") as buffer:
        buffer.write(file_bytes)
    logger.info(f"Saved file locally: {filepath}")
    return f"/static/uploads/{filename}"

def delete_image(image_url: str) -> bool:
    """
    Deletes an image from Cloudinary or local storage.
    """
    if not image_url:
        return False
        
    if "cloudinary.com" in image_url:
        if settings.CLOUDINARY_URL:
            try:
                # Extract public ID from the Cloudinary URL
                # Example: https://res.cloudinary.com/cloud_name/image/upload/v12345/folder/public_id.jpg
                parts = image_url.split("/")
                if "upload" in parts:
                    idx = parts.index("upload")
                    path_parts = parts[idx + 1:]
                    if path_parts and path_parts[0].startswith("v") and path_parts[0][1:].isdigit():
                        path_parts = path_parts[1:]
                    public_id = "/".join(path_parts)
                    public_id = os.path.splitext(public_id)[0]
                    
                    res = cloudinary.uploader.destroy(public_id)
                    success = res.get("result") == "ok"
                    logger.info(f"Cloudinary delete result for {public_id}: {res.get('result')}")
                    return success
            except Exception as e:
                logger.error(f"Cloudinary delete failed: {e}", exc_info=True)
        return False
        
    # Local Storage deletion fallback
    if image_url.startswith("/static/"):
        relative_path = image_url.lstrip("/")
        if os.path.exists(relative_path):
            try:
                os.remove(relative_path)
                logger.info(f"Deleted local file: {relative_path}")
                return True
            except Exception as e:
                logger.error(f"Local file deletion failed: {e}", exc_info=True)
        return False
        
    return False
