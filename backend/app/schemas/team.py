from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict
from uuid import UUID
from app.schemas.player import PlayerResponse

class TeamBase(BaseModel):
    name: str
    logo_url: Optional[str] = None
    description: Optional[str] = None

class TeamCreate(TeamBase):
    captain_id: Optional[UUID] = None

class TeamUpdate(BaseModel):
    name: Optional[str] = None
    captain_id: Optional[UUID] = None
    description: Optional[str] = None

class TeamResponse(TeamBase):
    id: UUID
    captain_id: Optional[UUID] = None
    created_by: UUID
    created_at: Optional[datetime] = None
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

class BulkAddPlayersRequest(BaseModel):
    player_ids: List[UUID]

class TeamMemberResponse(BaseModel):
    id: UUID
    team_id: UUID
    user_id: UUID
    user_email: str
    user_full_name: Optional[str] = None
    role: str
    status: str
    joined_at: datetime

    model_config = ConfigDict(from_attributes=True)

class MyTeamsResponse(BaseModel):
    team: TeamResponse
    role: str
    status: str

    model_config = ConfigDict(from_attributes=True)

class AddMemberRequest(BaseModel):
    email: str

class ApproveMemberRequest(BaseModel):
    user_id: UUID
