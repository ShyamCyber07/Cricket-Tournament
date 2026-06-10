from typing import Optional
from pydantic import BaseModel, ConfigDict
from uuid import UUID

class PlayerBase(BaseModel):
    name: str
    role: str  # batsman, bowler, all_rounder, wicket_keeper
    batting_style: str  # right_hand, left_hand
    bowling_style: str  # right_arm_fast, right_arm_spin, etc.
    profile_photo_url: Optional[str] = None

class PlayerCreate(PlayerBase):
    user_id: Optional[UUID] = None

class PlayerResponse(PlayerBase):
    id: UUID
    user_id: Optional[UUID] = None

    model_config = ConfigDict(from_attributes=True)
