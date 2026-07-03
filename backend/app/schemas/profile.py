from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, ConfigDict
from uuid import UUID

class ProfileResponse(BaseModel):
    id: UUID
    email: EmailStr
    full_name: Optional[str] = None
    username: Optional[str] = None
    display_name: Optional[str] = None
    profile_picture: Optional[str] = None
    profile_photo_url: Optional[str] = None
    bio: Optional[str] = None
    account_type: Optional[str] = None
    joined_at: Optional[datetime] = None
    role: str = "user"
    is_active: bool = True
    
    # New profile fields
    phone_number: Optional[str] = None
    city: Optional[str] = None
    dob: Optional[str] = None
    batting_style: Optional[str] = None
    bowling_style: Optional[str] = None
    player_type: Optional[str] = None
    dominant_hand: Optional[str] = None
    default_jersey_number: Optional[int] = None
    profile_photo_bytes: Optional[bytes] = None
    public_id: Optional[str] = None
    privacy_settings: str = "public"
    current_team: Optional[str] = None
    team_role: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class ProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    username: Optional[str] = None
    bio: Optional[str] = None
    profile_picture: Optional[str] = None
    profile_photo_url: Optional[str] = None
    phone_number: Optional[str] = None
    city: Optional[str] = None
    dob: Optional[str] = None
    batting_style: Optional[str] = None
    bowling_style: Optional[str] = None
    player_type: Optional[str] = None
    dominant_hand: Optional[str] = None
    default_jersey_number: Optional[int] = None
    privacy_settings: Optional[str] = None

class BattingStats(BaseModel):
    matches_played: int = 0
    innings: int = 0
    runs: int = 0
    highest_score: int = 0
    average: float = 0.0
    strike_rate: float = 0.0
    fours: int = 0
    sixes: int = 0
    fifties: int = 0
    hundreds: int = 0
    balls: int = 0
    not_outs: int = 0
    thirties: int = 0
    ducks: int = 0

class BowlingStats(BaseModel):
    wickets: int = 0
    overs_bowled: float = 0.0
    economy: float = 0.0
    best_bowling_figures: str = "0/0"
    maidens: int = 0
    matches: int = 0
    runs: int = 0
    three_wickets: int = 0
    five_wickets: int = 0
    best_bowling: str = "0/0"

class FieldingStats(BaseModel):
    catches: int = 0
    run_outs: int = 0
    stumpings: int = 0

class TournamentStats(BaseModel):
    tournaments_played: int = 0
    tournaments_won: int = 0
    finals_played: int = 0
    win_percentage: float = 0.0

class CareerStatsResponse(BaseModel):
    batting: BattingStats
    bowling: BowlingStats
    fielding: FieldingStats
    tournament: TournamentStats
    recent_performances: List[dict] = []
    awards: List[str] = []

class UserActivityResponse(BaseModel):
    activity_type: str
    description: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class UserAchievementResponse(BaseModel):
    achievement_type: str
    unlocked_at: Optional[datetime] = None
    is_unlocked: bool = False

    model_config = ConfigDict(from_attributes=True)


class PublicProfileResponse(BaseModel):
    public_id: Optional[str] = None
    username: Optional[str] = None
    full_name: Optional[str] = None
    display_name: Optional[str] = None
    profile_picture: Optional[str] = None
    profile_photo_url: Optional[str] = None
    bio: Optional[str] = None
    city: Optional[str] = None
    batting_style: Optional[str] = None
    bowling_style: Optional[str] = None
    player_type: Optional[str] = None
    dominant_hand: Optional[str] = None
    default_jersey_number: Optional[int] = None
    joined_at: Optional[datetime] = None
    privacy_settings: str = "public"
    
    # Custom fields for public view
    current_team: Optional[str] = None
    team_role: Optional[str] = None
    career_stats: Optional[CareerStatsResponse] = None
    achievements: List[UserAchievementResponse] = []

    model_config = ConfigDict(from_attributes=True)
