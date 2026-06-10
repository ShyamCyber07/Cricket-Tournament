from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.cricket import Tournament, Team, TournamentTeam, Match, Innings
from app.schemas.tournament import TournamentCreate, TournamentResponse, PointsTableEntry, LeaderboardResponse

router = APIRouter()

@router.post("/", response_model=TournamentResponse, status_code=status.HTTP_201_CREATED)
def create_tournament(
    tour_in: TournamentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_tour = Tournament(
        name=tour_in.name,
        start_date=tour_in.start_date,
        end_date=tour_in.end_date,
        format=tour_in.format,
        banner_url=tour_in.banner_url,
        organizer_id=current_user.id,
        created_at=datetime.now(timezone.utc)
    )
    db.add(db_tour)
    db.commit()
    db.refresh(db_tour)
    return db_tour

@router.get("/", response_model=List[TournamentResponse])
def list_tournaments(db: Session = Depends(get_db)):
    return db.query(Tournament).all()

@router.get("/{id}", response_model=TournamentResponse)
def get_tournament(id: UUID, db: Session = Depends(get_db)):
    tour = db.query(Tournament).filter(Tournament.id == id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
    return tour

@router.post("/{id}/teams", status_code=status.HTTP_200_OK)
def register_team_to_tournament(
    id: UUID,
    team_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tour = db.query(Tournament).filter(Tournament.id == id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
        
    if tour.organizer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the organizer can add teams")
        
    team = db.query(Team).filter(Team.id == team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Check if already registered
    exists = db.query(TournamentTeam).filter(
        TournamentTeam.tournament_id == id,
        TournamentTeam.team_id == team_id
    ).first()
    if exists:
        raise HTTPException(status_code=400, detail="Team already registered in this tournament")
        
    assoc = TournamentTeam(tournament_id=id, team_id=team_id)
    db.add(assoc)
    db.commit()
    return {"message": "Team registered successfully"}

@router.get("/{id}/points-table", response_model=List[PointsTableEntry])
def get_points_table(id: UUID, db: Session = Depends(get_db)):
    tour = db.query(Tournament).filter(Tournament.id == id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
        
    # Get all registered teams
    teams = tour.teams
    
    # Get all completed matches in this tournament
    matches = db.query(Match).filter(
        Match.tournament_id == id,
        Match.status == "completed"
    ).all()
    
    # Construct points table rows
    points_table = []
    
    for team in teams:
        played = 0
        won = 0
        lost = 0
        tied = 0
        points = 0
        
        # Net Run Rate calculations
        # NRR = (Total Runs Scored / Total Overs Faced) - (Total Runs Conceded / Total Overs Bowled)
        total_runs_scored = 0
        total_overs_faced = 0.0
        total_runs_conceded = 0
        total_overs_bowled = 0.0
        
        for m in matches:
            if team.id not in [m.team1_id, m.team2_id]:
                continue
                
            played += 1
            if m.winner_id == team.id:
                won += 1
                points += 2
            elif m.winner_id is None:
                tied += 1
                points += 1
            else:
                lost += 1
                
            # Grab innings details for NRR
            for innings in m.innings:
                # Calculate overs as a float representing true fractional overs
                # e.g. 15.4 overs = 15 + 4/6 = 15.666 overs
                overs_int = int(innings.total_overs)
                overs_balls = round((innings.total_overs - overs_int) * 10)
                fractional_overs = overs_int + (overs_balls / 6.0)
                
                if innings.batting_team_id == team.id:
                    total_runs_scored += innings.total_runs
                    total_overs_faced += fractional_overs
                elif innings.bowling_team_id == team.id:
                    total_runs_conceded += innings.total_runs
                    total_overs_bowled += fractional_overs
                    
        # Compute NRR
        nrr = 0.0
        if total_overs_faced > 0 and total_overs_bowled > 0:
            rate_scored = total_runs_scored / total_overs_faced
            rate_conceded = total_runs_conceded / total_overs_bowled
            nrr = round(rate_scored - rate_conceded, 3)
            
        points_table.append(
            PointsTableEntry(
                team_id=team.id,
                team_name=team.name,
                logo_url=team.logo_url,
                played=played,
                won=won,
                lost=lost,
                tied=tied,
                points=points,
                net_run_rate=nrr
            )
        )
        
    # Sort points table by Points (descending), then NRR (descending)
    points_table.sort(key=lambda x: (x.points, x.net_run_rate), reverse=True)
    return points_table
