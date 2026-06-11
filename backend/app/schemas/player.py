from typing import Optional
from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID

class PlayerBase(BaseModel):
    name: str
    role: str  # batsman, bowler, all_rounder, wicket_keeper
    batting_style: str  # right_hand, left_hand
    bowling_style: str  # right_arm_fast, right_arm_spin, etc.
    profile_photo_url: Optional[str] = None
    jersey_number: Optional[int] = Field(None, ge=0, le=999)

class PlayerCreate(PlayerBase):
    user_id: Optional[UUID] = None

class PlayerUpdate(BaseModel):
    name: Optional[str] = None
    role: Optional[str] = None
    batting_style: Optional[str] = None
    bowling_style: Optional[str] = None
    profile_photo_url: Optional[str] = None
    jersey_number: Optional[int] = Field(None, ge=0, le=999)

class PlayerResponse(PlayerBase):
    id: UUID
    user_id: Optional[UUID] = None
    career_runs: Optional[int] = 0
    career_wickets: Optional[int] = 0
    matches_played: Optional[int] = 0
    batting_average: Optional[float] = 0.0
    strike_rate: Optional[float] = 0.0
    economy: Optional[float] = 0.0
    highest_score: Optional[int] = 0
    best_bowling_figures: Optional[str] = ""

    model_config = ConfigDict(from_attributes=True)
