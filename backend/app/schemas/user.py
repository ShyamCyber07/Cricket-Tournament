from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, ConfigDict
from uuid import UUID

class UserBase(BaseModel):
    email: EmailStr
    full_name: str

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: UUID
    profile_photo_url: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    sub: Optional[str] = None

class GoogleLoginRequest(BaseModel):
    token: str
