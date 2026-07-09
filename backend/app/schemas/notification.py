from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict
from uuid import UUID

class NotificationResponse(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    message: str
    type: str
    extra_data: Optional[str] = None
    payload: Optional[str] = None
    is_read: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class DeviceTokenRegister(BaseModel):
    fcm_token: str
    device_name: Optional[str] = None
    platform: Optional[str] = None


class DeviceTokenResponse(BaseModel):
    id: UUID
    user_id: UUID
    fcm_token: str
    device_name: Optional[str] = None
    platform: Optional[str] = None
    last_seen: datetime
    is_active: bool

    model_config = ConfigDict(from_attributes=True)
