from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import UUID
from datetime import datetime, timezone

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User, DeviceToken
from app.models.cricket import Notification
from app.schemas.notification import NotificationResponse, DeviceTokenRegister, DeviceTokenResponse

router = APIRouter()

@router.get("/", response_model=List[NotificationResponse])
def list_notifications(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Fetch user's notifications sorted by newest first
    return db.query(Notification).filter(
        Notification.user_id == current_user.id
    ).order_by(Notification.created_at.desc()).offset(skip).limit(limit).all()

@router.post("/{id}/read", response_model=NotificationResponse)
def mark_notification_read(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    notif = db.query(Notification).filter(
        Notification.id == id,
        Notification.user_id == current_user.id
    ).first()
    
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
        
    notif.is_read = True
    notif.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(notif)
    return notif

@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
def mark_all_notifications_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    now = datetime.now(timezone.utc)
    db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False
    ).update({"is_read": True, "updated_at": now}, synchronize_session=False)
    db.commit()
    return None

@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_notification(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    notif = db.query(Notification).filter(
        Notification.id == id,
        Notification.user_id == current_user.id
    ).first()
    
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
        
    db.delete(notif)
    db.commit()
    return None

@router.post("/devices/register", response_model=DeviceTokenResponse)
def register_device(
    payload: DeviceTokenRegister,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Check if this token is already registered (anywhere)
    device = db.query(DeviceToken).filter(
        DeviceToken.fcm_token == payload.fcm_token
    ).first()
    
    now = datetime.now(timezone.utc)
    if device:
        # Re-assign or update existing
        device.user_id = current_user.id
        device.device_name = payload.device_name
        device.platform = payload.platform
        device.is_active = True
        device.last_seen = now
    else:
        # Register new
        device = DeviceToken(
            user_id=current_user.id,
            fcm_token=payload.fcm_token,
            device_name=payload.device_name,
            platform=payload.platform,
            is_active=True,
            last_seen=now
        )
        db.add(device)
        
    db.commit()
    db.refresh(device)
    return device

@router.post("/devices/unregister", status_code=status.HTTP_204_NO_CONTENT)
def unregister_device(
    payload: DeviceTokenRegister,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    device = db.query(DeviceToken).filter(
        DeviceToken.fcm_token == payload.fcm_token,
        DeviceToken.user_id == current_user.id
    ).first()
    
    if device:
        device.is_active = False
        device.last_seen = datetime.now(timezone.utc)
        db.commit()
        
    return None

