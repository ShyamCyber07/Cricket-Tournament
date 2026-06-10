from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict
from uuid import UUID
from app.schemas.player import PlayerResponse

class TeamBase(BaseModel):
    name: str
    logo_url: Optional[str] = None

class TeamCreate(TeamBase):
    captain_id: Optional[UUID] = None

class TeamResponse(TeamBase):
    id: UUID
    captain_id: Optional[UUID] = None
    created_by: UUID
    created_at: datetime
    players: List[PlayerResponse] = []

    model_config = ConfigDict(from_attributes=True)

class AddPlayerRequest(BaseModel):
    player_id: UUID

class TeamStatsResponse(BaseModel):
    team_id: UUID
    team_name: str
    matches_played: int
    matches_won: int
    matches_lost: int
    matches_tied: int
    net_run_rate: float
