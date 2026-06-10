from datetime import date, datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict
from uuid import UUID

class TournamentBase(BaseModel):
    name: str
    start_date: date
    end_date: date
    format: str  # T20, ODI, Test, Custom
    banner_url: Optional[str] = None

class TournamentCreate(TournamentBase):
    pass

class TournamentResponse(TournamentBase):
    id: UUID
    organizer_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class PointsTableEntry(BaseModel):
    team_id: UUID
    team_name: str
    logo_url: Optional[str] = None
    played: int
    won: int
    lost: int
    tied: int
    points: int
    net_run_rate: float

class PlayerLeaderboardEntry(BaseModel):
    player_id: UUID
    player_name: str
    team_name: str
    profile_photo_url: Optional[str] = None
    metric_value: float  # Runs for batsmen, wickets for bowlers, etc.

class LeaderboardResponse(BaseModel):
    top_batsmen: List[PlayerLeaderboardEntry] = []
    top_bowlers: List[PlayerLeaderboardEntry] = []
