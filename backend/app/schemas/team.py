from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict
from uuid import UUID
from app.schemas.player import PlayerResponse

class TeamBase(BaseModel):
    name: str
    logo_url: Optional[str] = None
    description: Optional[str] = None
    home_ground: Optional[str] = None
    city: Optional[str] = None
    team_motto: Optional[str] = None
    founded_year: Optional[int] = None

class TeamCreate(TeamBase):
    captain_id: Optional[UUID] = None

class TeamUpdate(BaseModel):
    name: Optional[str] = None
    captain_id: Optional[UUID] = None
    description: Optional[str] = None
    home_ground: Optional[str] = None
    city: Optional[str] = None
    team_motto: Optional[str] = None
    founded_year: Optional[int] = None

class TeamResponse(TeamBase):
    id: UUID
    captain_id: Optional[UUID] = None
    created_by: UUID
    created_at: Optional[datetime] = None
    is_squad_locked: bool = False
    players: List[PlayerResponse] = []
    team_code: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class AddPlayerRequest(BaseModel):
    player_id: UUID

class TeamStatsResponse(BaseModel):
    team_id: UUID
    team_name: str
    matches_played: int = 0
    matches_won: int = 0
    matches_lost: int = 0
    matches_tied: int = 0
    matches_no_result: int = 0
    win_percentage: float = 0.0
    highest_score: int = 0
    lowest_score: int = 0
    highest_chase: int = 0
    net_run_rate: float = 0.0
    captain_name: Optional[str] = None
    vice_captain_name: Optional[str] = None
    form: List[str] = []
    trophies: List[str] = []

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
    is_playing_xi: bool = True
    is_wicketkeeper: bool = False
    jersey_number: Optional[int] = None
    batting_order: Optional[int] = None
    bowling_order: Optional[int] = None
    is_available: bool = True
    invited_by_id: Optional[UUID] = None
    invited_by_name: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class SquadMemberConfig(BaseModel):
    user_id: UUID
    is_playing_xi: bool
    is_wicketkeeper: bool
    jersey_number: Optional[int] = None
    batting_order: Optional[int] = None
    bowling_order: Optional[int] = None
    is_available: bool


class UpdateSquadConfigRequest(BaseModel):
    members: List[SquadMemberConfig]

class MyTeamsResponse(BaseModel):
    team: TeamResponse
    role: str
    status: str

    model_config = ConfigDict(from_attributes=True)

class AddMemberRequest(BaseModel):
    email: str

class ApproveMemberRequest(BaseModel):
    user_id: UUID

class UpdateMemberRoleRequest(BaseModel):
    role: str

class TeamActivityResponse(BaseModel):
    id: UUID
    team_id: UUID
    user_id: Optional[UUID] = None
    user_name: Optional[str] = None
    action_type: str
    description: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TeamInvitationResponse(BaseModel):
    id: UUID
    team_id: UUID
    user_id: UUID
    user_name: str
    invited_by_id: Optional[UUID] = None
    invited_by_name: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class JoinRequestResponse(BaseModel):
    id: UUID
    team_id: UUID
    user_id: UUID
    user_name: str
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
