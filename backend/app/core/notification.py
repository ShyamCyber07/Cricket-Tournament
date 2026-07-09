import logging
import os
import uuid
import json
import time
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from jose import jwt
import httpx

from app.models.cricket import Notification
from app.models.user import DeviceToken

logger = logging.getLogger(__name__)

# Constants
FCM_SEND_URL_TEMPLATE = "https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
SERVICE_ACCOUNT_FILE = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "firebase-service-account.json")

def get_fcm_access_token() -> str | None:
    """
    Generates a Google OAuth2 access token for FCM using the service account credentials.
    """
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        return None
        
    try:
        with open(SERVICE_ACCOUNT_FILE, "r") as f:
            sa_info = json.load(f)
            
        now = int(time.time())
        claims = {
            "iss": sa_info["client_email"],
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud": "https://oauth2.googleapis.com/token",
            "exp": now + 3600,
            "iat": now
        }
        
        private_key = sa_info["private_key"]
        assertion = jwt.encode(claims, private_key, algorithm="RS256")
        
        token_url = "https://oauth2.googleapis.com/token"
        data = {
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion
        }
        
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(token_url, data=data)
            if resp.status_code == 200:
                return resp.json().get("access_token")
            else:
                logger.error(f"[FCM] Token exchange failed: {resp.text}")
                return None
    except Exception as e:
        logger.error(f"[FCM] Error generating access token: {e}")
        return None

def get_firebase_project_id() -> str | None:
    """
    Reads the project ID from the service account JSON.
    """
    if os.path.exists(SERVICE_ACCOUNT_FILE):
        try:
            with open(SERVICE_ACCOUNT_FILE, "r") as f:
                sa_info = json.load(f)
                return sa_info.get("project_id")
        except Exception:
            pass
    return os.getenv("FIREBASE_PROJECT_ID")

def send_fcm_message(fcm_token: str, title: str, message: str, data: dict = None) -> bool:
    """
    Sends a push notification to a specific FCM token via HTTP v1 REST API.
    """
    project_id = get_firebase_project_id()
    access_token = get_fcm_access_token()
    
    # Fallback to simulation if credentials are not configured
    if not project_id or not access_token:
        print(f"\n[FCM SIMULATION] Sending Push Notification:")
        print(f"  FCM Token: {fcm_token}")
        print(f"  Title:     {title}")
        print(f"  Message:   {message}")
        print(f"  Payload:   {data}\n")
        logger.info(f"[FCM SIMULATION] Push sent to token {fcm_token[:15]}...")
        return True
        
    url = FCM_SEND_URL_TEMPLATE.format(project_id=project_id)
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    
    # Build payload structure
    payload = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": title,
                "body": message
            }
        }
    }
    
    if data:
        # FCM v1 data values must be strings
        string_data = {k: str(v) for k, v in data.items()}
        payload["message"]["data"] = string_data
        
    try:
        with httpx.Client(timeout=15.0) as client:
            resp = client.post(url, headers=headers, json=payload)
            if resp.status_code == 200:
                logger.info(f"[FCM SUCCESS] Message sent to token: {fcm_token[:15]}...")
                return True
            else:
                logger.error(f"[FCM FAILURE] Status: {resp.status_code}, Body: {resp.text}")
                return False
    except Exception as e:
        logger.error(f"[FCM FAILURE] Error: {e}")
        return False

# Reusable DB functions
def saveNotification(db: Session, user_id: uuid.UUID, title: str, message: str, type: str, payload: str = None) -> Notification:
    """
    Saves a notification to the database.
    """
    notif = Notification(
        id=uuid.uuid4(),
        user_id=user_id,
        title=title,
        message=message,
        type=type,
        payload=payload,
        extra_data=payload,  # Support backwards compatibility with extra_data
        is_read=False,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return notif

def sendToUser(db: Session, user_id: uuid.UUID, title: str, message: str, type: str, payload: str = None) -> bool:
    """
    Saves a notification and dispatches a push notification to all active devices registered to the user.
    """
    # 1. Save locally
    saveNotification(db, user_id, title, message, type, payload)
    
    # 2. Get active device tokens
    devices = db.query(DeviceToken).filter(
        DeviceToken.user_id == user_id,
        DeviceToken.is_active == True
    ).all()
    
    if not devices:
        logger.info(f"[Notification Service] No active device tokens found for user {user_id}")
        return True
        
    # Prepare payload data for push
    data = {"type": type}
    if payload:
        try:
            parsed = json.loads(payload)
            if isinstance(parsed, dict):
                data.update(parsed)
        except Exception:
            data["payload"] = payload
            
    success = True
    for device in devices:
        ok = send_fcm_message(device.fcm_token, title, message, data)
        if not ok:
            success = False
            
    return success

def sendToMultipleUsers(db: Session, user_ids: list[uuid.UUID], title: str, message: str, type: str, payload: str = None) -> dict:
    """
    Sends notification to a list of users.
    """
    results = {}
    for uid in user_ids:
        ok = sendToUser(db, uid, title, message, type, payload)
        results[str(uid)] = ok
    return results

def markRead(db: Session, notification_id: uuid.UUID, user_id: uuid.UUID) -> Notification | None:
    """
    Marks a notification as read.
    """
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == user_id
    ).first()
    if notif:
        notif.is_read = True
        notif.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(notif)
    return notif

def markAllRead(db: Session, user_id: uuid.UUID) -> int:
    """
    Marks all unread notifications of a user as read.
    """
    unread = db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read == False
    ).all()
    
    count = 0
    now = datetime.now(timezone.utc)
    for notif in unread:
        notif.is_read = True
        notif.updated_at = now
        count += 1
        
    if count > 0:
        db.commit()
        
    return count

def deleteNotification(db: Session, notification_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    """
    Deletes a notification.
    """
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == user_id
    ).first()
    if notif:
        db.delete(notif)
        db.commit()
        return True
    return False
