from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict
from uuid import UUID

class MatchBase(BaseModel):
    venue: str
    match_date: datetime
    match_type: str  # T20, ODI, Test, Custom
    over_limit: int
    tournament_stage: Optional[str] = None
    match_number: Optional[int] = None

class MatchCreate(MatchBase):
    team1_id: UUID
    team2_id: UUID
    tournament_id: Optional[UUID] = None
    assigned_scorer_id: Optional[UUID] = None

class MatchResponse(MatchBase):
    id: UUID
    team1_id: UUID
    team2_id: UUID
    team1_name: Optional[str] = None
    team2_name: Optional[str] = None
    team1_logo_url: Optional[str] = None
    team2_logo_url: Optional[str] = None
    tournament_id: Optional[UUID] = None
    status: str
    toss_winner_id: Optional[UUID] = None
    toss_decision: Optional[str] = None
    winner_id: Optional[UUID] = None
    win_margin_runs: Optional[int] = None
    win_margin_wickets: Optional[int] = None
    current_striker_id: Optional[UUID] = None
    current_non_striker_id: Optional[UUID] = None
    current_bowler_id: Optional[UUID] = None
    umpire_name: Optional[str] = None
    umpire2_name: Optional[str] = None
    scorer_name: Optional[str] = None
    team1_squad_locked: bool = False
    team2_squad_locked: bool = False
    created_by: Optional[UUID] = None
    assigned_scorer_id: Optional[UUID] = None
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

class TossSubmit(BaseModel):
    toss_winner_id: UUID
    toss_decision: str  # bat, bowl

class SquadPlayerInfo(BaseModel):
    player_id: UUID
    is_captain: bool = False
    is_wicketkeeper: bool = False
    is_playing_xi: bool = True
    batting_order: Optional[int] = None
    bowling_preference: Optional[int] = None

class SquadSubmit(BaseModel):
    team_id: UUID
    players: List[SquadPlayerInfo]

class BallCreate(BaseModel):
    bowler_id: UUID
    batsman_id: UUID
    non_striker_id: UUID
    runs_batsman: int
    runs_extras: int
    extra_type: str  # wide, no_ball, bye, leg_bye, none
    is_wicket: bool
    wicket_type: Optional[str] = None  # bowled, caught, lbw, run_out, stumped, hit_wicket, retired_hurt, none
    player_dismissed_id: Optional[UUID] = None
    fielder_id: Optional[UUID] = None
    commentary: Optional[str] = None

# Real-time state schemas
class StrikerState(BaseModel):
    player_id: UUID
    name: str
    runs: int = 0
    balls: int = 0
    fours: int = 0
    sixes: int = 0
    strike_rate: float = 0.0

class BowlerState(BaseModel):
    player_id: UUID
    name: str
    overs: float = 0.0  # e.g., 2.4 overs
    runs: int = 0
    wickets: int = 0
    maidens: int = 0
    economy: float = 0.0

class InningsSummarySchema(BaseModel):
    innings_number: int
    batting_team_name: str
    batting_team_id: UUID
    bowling_team_id: UUID
    total_runs: int
    total_wickets: int
    total_overs: float
    extras_wides: int
    extras_noballs: int
    extras_byes: int
    extras_legbyes: int
    extras_penalty: int = 0
    is_completed: bool
    dismissed_player_ids: List[UUID] = []
    last_bowler_id: Optional[UUID] = None

class RecentBallSchema(BaseModel):
    ball_label: str  # "0", "1", "Wd", "Nb+4", "W", etc.
    runs: int
    extra_type: str
    is_wicket: bool
    over_ball_coord: Optional[str] = None
    over_number: Optional[int] = None

class OverSummarySchema(BaseModel):
    over_number: int
    runs: int
    wickets: int
    is_completed: bool

class ActivePartnershipSchema(BaseModel):
    runs: int
    balls: int
    player1_id: UUID
    player1_name: str
    player1_runs: int
    player1_balls: int
    player2_id: UUID
    player2_name: str
    player2_runs: int
    player2_balls: int

class BatterBowlerStatsSchema(BaseModel):
    runs: int
    balls: int

class LiveMatchState(BaseModel):
    match_id: UUID
    status: str
    venue: str
    match_type: str
    over_limit: int
    team1_name: str
    team2_name: str
    team1_id: UUID
    team2_id: UUID
    current_innings_number: int
    target: Optional[int] = None
    created_by: Optional[UUID] = None
    assigned_scorer_id: Optional[UUID] = None
    tournament_organizer_id: Optional[UUID] = None
    team1_squad_locked: bool = False
    team2_squad_locked: bool = False
    
    tournament_name: Optional[str] = None
    tournament_logo_url: Optional[str] = None
    tournament_stage: Optional[str] = None
    match_number: Optional[int] = None
    toss_winner_name: Optional[str] = None
    toss_winner_id: Optional[UUID] = None
    toss_decision: Optional[str] = None
    team1_logo_url: Optional[str] = None
    team2_logo_url: Optional[str] = None
    
    umpire_name: Optional[str] = None
    scorer_name: Optional[str] = None
    
    striker: Optional[StrikerState] = None
    non_striker: Optional[StrikerState] = None
    bowler: Optional[BowlerState] = None
    
    current_innings: Optional[InningsSummarySchema] = None
    previous_innings: Optional[InningsSummarySchema] = None
    recent_balls: List[RecentBallSchema] = []
    
    # Live stats fields
    recent_overs: List[OverSummarySchema] = []
    active_partnership: Optional[ActivePartnershipSchema] = None
    striker_vs_bowler: Optional[BatterBowlerStatsSchema] = None

# Scorecard response schemas
class BatsmanScorecardEntry(BaseModel):
    name: str
    runs: int
    balls: int
    fours: int
    sixes: int
    strike_rate: float
    dismissal_info: str

class BowlerScorecardEntry(BaseModel):
    name: str
    overs: float
    maidens: int
    runs_conceded: int
    wickets: int
    economy: float

class ExtrasBreakdownSchema(BaseModel):
    wides: int
    no_balls: int
    byes: int
    leg_byes: int
    penalties: int = 0
    total: int

class FallOfWicketEntry(BaseModel):
    score: str
    player_name: str
    over: str

class PartnershipEntry(BaseModel):
    player1_name: str
    player2_name: str
    runs: int
    balls: int

class InningsScorecardSchema(BaseModel):
    innings_number: int
    batting_team_name: str
    total_runs: int
    total_wickets: int
    total_overs: float
    run_rate: float
    extras: ExtrasBreakdownSchema
    batting: List[BatsmanScorecardEntry]
    bowling: List[BowlerScorecardEntry]
    fall_of_wickets: List[FallOfWicketEntry]
    partnerships: List[PartnershipEntry]

class MatchSummaryCardSchema(BaseModel):
    match_id: UUID
    venue: str
    match_type: str
    date: datetime
    team1_name: str
    team2_name: str
    toss_winner_name: Optional[str] = None
    toss_decision: Optional[str] = None
    winner_name: Optional[str] = None
    win_margin_runs: Optional[int] = None
    win_margin_wickets: Optional[int] = None
    win_margin_text: str

class MatchScorecardResponse(BaseModel):
    match_summary: MatchSummaryCardSchema
    innings: List[InningsScorecardSchema]

class MatchUpdate(BaseModel):
    team1_id: Optional[UUID] = None
    team2_id: Optional[UUID] = None
    venue: Optional[str] = None
    match_date: Optional[datetime] = None
    match_type: Optional[str] = None
    over_limit: Optional[int] = None
    status: Optional[str] = None
    toss_winner_id: Optional[UUID] = None
    toss_decision: Optional[str] = None
    winner_id: Optional[UUID] = None
    win_margin_runs: Optional[int] = None
    win_margin_wickets: Optional[int] = None
    assigned_scorer_id: Optional[UUID] = None
    umpire_name: Optional[str] = None
    umpire2_name: Optional[str] = None
    scorer_name: Optional[str] = None
    team1_squad_locked: Optional[bool] = None
    team2_squad_locked: Optional[bool] = None
    tournament_stage: Optional[str] = None
    bracket_code: Optional[str] = None


class MatchActivityResponse(BaseModel):
    id: UUID
    match_id: UUID
    user_id: Optional[UUID] = None
    action_type: str
    description: str
    created_at: datetime
    user_name: Optional[str] = None

    class Config:
        from_attributes = True


class TossDecisionRequest(BaseModel):
    toss_decision: str  # bat, bowl


class MatchStartRequest(BaseModel):
    striker_id: UUID
    non_striker_id: UUID
    bowler_id: UUID



