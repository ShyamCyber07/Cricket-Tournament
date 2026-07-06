import os
import io
import logging
import cloudinary
import cloudinary.uploader
from app.core.config import settings

logger = logging.getLogger(__name__)

# Configure Cloudinary if credentials are provided
if settings.CLOUDINARY_CLOUD_NAME and settings.CLOUDINARY_API_KEY and settings.CLOUDINARY_API_SECRET:
    try:
        cloudinary.config(
            cloud_name=settings.CLOUDINARY_CLOUD_NAME,
            api_key=settings.CLOUDINARY_API_KEY,
            api_secret=settings.CLOUDINARY_API_SECRET,
            secure=True
        )
        logger.info("Cloudinary configured successfully via credentials.")
    except Exception as e:
        logger.error(f"Failed to configure Cloudinary: {e}", exc_info=True)
elif settings.CLOUDINARY_URL:
    try:
        cloudinary.config(cloudinary_url=settings.CLOUDINARY_URL)
        logger.info("Cloudinary configured successfully via CLOUDINARY_URL.")
    except Exception as e:
        logger.error(f"Failed to configure Cloudinary with the provided URL: {e}", exc_info=True)
else:
    logger.warning("Cloudinary credentials and CLOUDINARY_URL not set. Falling back to local storage in development.")

def upload_image(file_bytes: bytes, filename: str, folder: str = "cricup") -> str:
    """
    Uploads an image.
    In production mode: Uploads exclusively to Cloudinary. Raises HTTPException if not configured or failed.
    In development mode: Uploads to Cloudinary if configured, otherwise falls back to local storage.
    """
    from fastapi import HTTPException
    
    is_production = settings.APP_ENV.lower() in ["production", "prod"]
    has_credentials = bool(
        (settings.CLOUDINARY_CLOUD_NAME and settings.CLOUDINARY_API_KEY and settings.CLOUDINARY_API_SECRET)
        or (not is_production and settings.CLOUDINARY_URL)
    )
    
    if is_production:
        # Enforce Cloudinary individual credentials in production
        prod_configured = bool(settings.CLOUDINARY_CLOUD_NAME and settings.CLOUDINARY_API_KEY and settings.CLOUDINARY_API_SECRET)
        if not prod_configured:
            logger.error("Cloudinary configuration missing.")
            raise HTTPException(status_code=500, detail="Cloudinary is not configured.")
        try:
            base_name = os.path.splitext(filename)[0]
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
            else:
                raise Exception("No secure_url returned from Cloudinary.")
        except HTTPException as he:
            raise he
        except Exception as e:
            logger.error(f"Cloudinary upload failed: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=f"Cloudinary upload failed: {str(e)}")
            
    else:
        # Development mode
        if has_credentials:
            try:
                base_name = os.path.splitext(filename)[0]
                res = cloudinary.uploader.upload(
                    io.BytesIO(file_bytes),
                    folder=folder,
                    public_id=base_name,
                    overwrite=True,
                    resource_type="image"
                )
                secure_url = res.get("secure_url")
                if secure_url:
                    logger.info(f"Successfully uploaded to Cloudinary (Dev): {secure_url}")
                    return secure_url
            except Exception as e:
                logger.warning(f"Cloudinary upload failed in Dev, falling back to local: {e}")
                
        # Local Storage Fallback (only in development)
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
        has_credentials = bool(settings.CLOUDINARY_CLOUD_NAME and settings.CLOUDINARY_API_KEY and settings.CLOUDINARY_API_SECRET) or bool(settings.CLOUDINARY_URL)
        if has_credentials:
            try:
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
