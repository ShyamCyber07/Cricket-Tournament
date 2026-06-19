from datetime import date, datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict
from uuid import UUID

class TournamentBase(BaseModel):
    name: str
    start_date: date
    end_date: date
    format: str  # League, Knockout, League + Knockout
    num_teams: int = 4
    banner_url: Optional[str] = None

class TournamentCreate(TournamentBase):
    pass

class TournamentResponse(TournamentBase):
    id: UUID
    organizer_id: UUID
    status: str
    winner_id: Optional[UUID] = None
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
    no_result: int = 0
    points: int
    runs_for: int = 0
    runs_against: int = 0
    overs_faced: float = 0.0
    overs_bowled: float = 0.0
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

class TournamentUpdate(BaseModel):
    name: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    format: Optional[str] = None
    num_teams: Optional[int] = None
    banner_url: Optional[str] = None
    status: Optional[str] = None
    winner_id: Optional[UUID] = None

