import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Boolean, Integer, ForeignKey, LargeBinary
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String, unique=True, index=True, nullable=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=True)
    google_id = Column(String, unique=True, index=True, nullable=True)
    full_name = Column(String, nullable=True) # Changed to nullable=True to support multi-step signup/onboarding
    display_name = Column(String, nullable=True)
    profile_photo_url = Column(String, nullable=True)
    profile_picture = Column(String, nullable=True)
    email_verified = Column(Boolean, default=False)
    profile_completed = Column(Boolean, default=False)
    provider = Column(String, default="local")
    otp_code = Column(String, nullable=True)
    otp_expiry = Column(DateTime, nullable=True)
    last_login = Column(DateTime, nullable=True)
    failed_login_attempts = Column(Integer, default=0)
    lockout_until = Column(DateTime, nullable=True)
    last_otp_sent_at = Column(DateTime, nullable=True)
    bio = Column(String, nullable=True)
    account_type = Column(String, default="Scorer", nullable=True)
    role = Column(String, default="user", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    is_deleted = Column(Boolean, default=False, nullable=False)
    current_session_id = Column(String, nullable=True)
    joined_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    
    # Persistent user profile fields
    phone_number = Column(String, nullable=True)
    city = Column(String, nullable=True)
    dob = Column(String, nullable=True)
    batting_style = Column(String, nullable=True)
    bowling_style = Column(String, nullable=True)
    player_type = Column(String, nullable=True)
    dominant_hand = Column(String, nullable=True)
    default_jersey_number = Column(Integer, nullable=True)
    profile_photo_bytes = Column(LargeBinary, nullable=True)
    public_id = Column(String, unique=True, index=True, nullable=True)
    privacy_settings = Column(String, default="public", nullable=False)


    # Relationships - Fixed: removed problematic uselist=False
    # Note: Player.user_id is for profile linking, Player.created_by is for ownership
    # Use explicit queries instead of relationships to avoid lazy loading issues
    created_teams = relationship("Team", back_populates="creator", cascade="all, delete-orphan")
    organized_tournaments = relationship("Tournament", back_populates="organizer", foreign_keys="[Tournament.organizer_id]", cascade="all, delete-orphan")
    activities = relationship("UserActivity", back_populates="user", cascade="all, delete-orphan")
    achievements = relationship("UserAchievement", back_populates="user", cascade="all, delete-orphan")

class UserActivity(Base):
    __tablename__ = "user_activities"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    activity_type = Column(String, nullable=False)
    description = Column(String, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="activities")

class UserAchievement(Base):
    __tablename__ = "user_achievements"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    achievement_type = Column(String, nullable=False)
    unlocked_at = Column(DateTime, nullable=True)
    is_unlocked = Column(Boolean, default=False)

    user = relationship("User", back_populates="achievements")

class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    token = Column(String, unique=True, index=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class Report(Base):
    __tablename__ = "reports"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reporter_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    content_type = Column(String, nullable=False) # e.g. "tournament", "match", "team", "player"
    content_id = Column(UUID(as_uuid=True), nullable=False)
    reason = Column(String, nullable=False)
    status = Column(String, default="pending", nullable=False) # pending, resolved, dismissed
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    resolved_at = Column(DateTime, nullable=True)
    resolved_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    reporter = relationship("User", foreign_keys=[reporter_id])
    resolver = relationship("User", foreign_keys=[resolved_by])


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    fcm_token = Column(String, unique=True, index=True, nullable=False)
    device_name = Column(String, nullable=True)
    platform = Column(String, nullable=True)
    last_seen = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    user = relationship("User")

