from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.cricket import Team, Player, TeamPlayer, Match
from app.schemas.team import TeamCreate, TeamResponse, AddPlayerRequest, TeamStatsResponse

router = APIRouter()

@router.post("/", response_model=TeamResponse, status_code=status.HTTP_201_CREATED)
def create_team(
    team_in: TeamCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Check if team name exists
    existing = db.query(Team).filter(Team.name == team_in.name).first()
    if existing:
        return existing

    # If captain_id is provided, check if player exists
    if team_in.captain_id:
        captain = db.query(Player).filter(Player.id == team_in.captain_id).first()
        if not captain:
            raise HTTPException(status_code=404, detail="Captain player not found")

    db_team = Team(
        name=team_in.name,
        logo_url=team_in.logo_url,
        captain_id=team_in.captain_id,
        created_by=current_user.id
    )
    db.add(db_team)
    db.commit()
    db.refresh(db_team)
        
    return db_team

@router.get("/", response_model=List[TeamResponse])
def list_teams(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Team).all()

@router.get("/{id}", response_model=TeamResponse)
def get_team(id: UUID, db: Session = Depends(get_db)):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    return team

@router.post("/{id}/players", response_model=TeamResponse)
def add_player_to_team(
    id: UUID,
    req: AddPlayerRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Check authorization (only creator can add players)
    if team.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Check if player exists
    player = db.query(Player).filter(Player.id == req.player_id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")

    # Check if already in team
    exists = db.query(TeamPlayer).filter(
        TeamPlayer.team_id == id,
        TeamPlayer.player_id == req.player_id
    ).first()
    
    if exists:
        raise HTTPException(status_code=400, detail="Player already in this team")

    assoc = TeamPlayer(team_id=id, player_id=req.player_id)
    db.add(assoc)
    db.commit()
    db.refresh(team)
    return team

@router.get("/{id}/stats", response_model=TeamStatsResponse)
def get_team_stats(id: UUID, db: Session = Depends(get_db)):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    # Match count
    matches = db.query(Match).filter(
        (Match.team1_id == id) | (Match.team2_id == id)
    ).all()

    played = 0
    won = 0
    lost = 0
    tied = 0

    for m in matches:
        if m.status == "completed":
            played += 1
            if m.winner_id == id:
                won += 1
            elif m.winner_id is None:
                # No winner -> tie or no result (tied)
                tied += 1
            else:
                lost += 1

    return TeamStatsResponse(
        team_id=id,
        team_name=team.name,
        matches_played=played,
        matches_won=won,
        matches_lost=lost,
        matches_tied=tied,
        net_run_rate=0.0  # Optional NRR placeholder
    )
