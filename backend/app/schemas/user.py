from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, ConfigDict, field_validator, model_validator
from uuid import UUID

class EmailNormalizedModel(BaseModel):
    @field_validator('email', mode='before', check_fields=False)
    @classmethod
    def normalize_email(cls, v: str) -> str:
        if isinstance(v, str):
            return v.strip().lower()
        return v

class UserBase(EmailNormalizedModel):
    email: EmailStr
    full_name: Optional[str] = None

class UserSignup(EmailNormalizedModel):
    username: str
    email: EmailStr
    password: str
    confirm_password: str

    @field_validator('password')
    @classmethod
    def password_complexity(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        special_chars = "!@#$%^&*(),.?\":{}|<>"
        if not any(c in special_chars for c in v):
            raise ValueError('Password must contain at least one special character')
        return v

    @model_validator(mode='after')
    def verify_passwords_match(self) -> 'UserSignup':
        if self.password != self.confirm_password:
            raise ValueError("Passwords do not match")
        return self

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: UUID
    username: Optional[str] = None
    display_name: Optional[str] = None
    profile_photo_url: Optional[str] = None
    profile_picture: Optional[str] = None
    email_verified: bool
    profile_completed: bool
    provider: Optional[str] = "local"
    role: str = "user"
    is_active: bool = True
    created_at: Optional[datetime] = None
    
    # New profile fields
    phone_number: Optional[str] = None
    city: Optional[str] = None
    dob: Optional[str] = None
    batting_style: Optional[str] = None
    bowling_style: Optional[str] = None
    player_type: Optional[str] = None
    dominant_hand: Optional[str] = None
    default_jersey_number: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    email_verified: bool
    profile_completed: bool

class TokenData(BaseModel):
    sub: Optional[str] = None

class TokenRefreshRequest(BaseModel):
    refresh_token: str

class GoogleLoginRequest(BaseModel):
    token: str

class VerifyOTPRequest(EmailNormalizedModel):
    email: EmailStr
    otp_code: str

class ResendOTPRequest(EmailNormalizedModel):
    email: EmailStr

class CompleteProfileRequest(BaseModel):
    full_name: str
    display_name: str
    username: Optional[str] = None
    role: Optional[str] = None
    profile_picture: Optional[str] = None
    country: Optional[str] = None
    favorite_team: Optional[str] = None

class ForgotPasswordRequest(EmailNormalizedModel):
    email: EmailStr

class VerifyResetOTPRequest(EmailNormalizedModel):
    email: EmailStr
    otp_code: str

class ResetPasswordRequest(EmailNormalizedModel):
    email: EmailStr
    otp_code: str
    new_password: str
    confirm_password: str

    @field_validator('new_password')
    @classmethod
    def password_complexity(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        special_chars = "!@#$%^&*(),.?\":{}|<>"
        if not any(c in special_chars for c in v):
            raise ValueError('Password must contain at least one special character')
        return v

    @model_validator(mode='after')
    def verify_passwords_match(self) -> 'ResetPasswordRequest':
        if self.new_password != self.confirm_password:
            raise ValueError("Passwords do not match")
        return self
