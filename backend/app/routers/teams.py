from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.cricket import Team, Player, TeamPlayer, Match, Tournament, TournamentTeam, MatchSquad
from app.schemas.team import TeamCreate, TeamResponse, AddPlayerRequest, TeamStatsResponse, TeamUpdate, BulkAddPlayersRequest

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
    return db.query(Team).filter(Team.created_by == current_user.id).all()

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

    # Check player ownership
    if player.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this player")

    # Check if player is already assigned to any team (duplicate active membership prevention)
    existing_membership = db.query(TeamPlayer).filter(TeamPlayer.player_id == req.player_id).first()
    if existing_membership:
        assigned_team = db.query(Team).filter(Team.id == existing_membership.team_id).first()
        team_name = assigned_team.name if assigned_team else "another team"
        if existing_membership.team_id == id:
            raise HTTPException(status_code=400, detail="Player already in this team")
        else:
            raise HTTPException(
                status_code=400,
                detail=f"Player already assigned to Team {team_name}"
            )

    assoc = TeamPlayer(team_id=id, player_id=req.player_id)
    db.add(assoc)
    db.commit()
    db.refresh(team)
    return team

@router.post("/{id}/players/bulk", response_model=TeamResponse)
def add_players_to_team_bulk(
    id: UUID,
    req: BulkAddPlayersRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Check authorization (only creator can add players)
    if team.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Validate all player IDs first
    for p_id in req.player_ids:
        player = db.query(Player).filter(Player.id == p_id).first()
        if not player:
            raise HTTPException(status_code=404, detail=f"Player {p_id} not found")

        # Check player ownership
        if player.created_by != current_user.id:
            raise HTTPException(status_code=403, detail=f"Not authorized to manage player {player.name}")

        # Check duplicate assignment
        existing_membership = db.query(TeamPlayer).filter(TeamPlayer.player_id == p_id).first()
        if existing_membership:
            assigned_team = db.query(Team).filter(Team.id == existing_membership.team_id).first()
            team_name = assigned_team.name if assigned_team else "another team"
            if existing_membership.team_id == id:
                raise HTTPException(status_code=400, detail=f"Player {player.name} already in this team")
            else:
                raise HTTPException(
                    status_code=400,
                    detail=f"Player already assigned to Team {team_name}"
                )

    # All validations passed, insert associations
    for p_id in req.player_ids:
        assoc = TeamPlayer(team_id=id, player_id=p_id)
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


@router.put("/{id}", response_model=TeamResponse)
def update_team(
    id: UUID,
    team_in: TeamUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    # Check authorization (only creator can edit)
    if team.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Update name if provided and verify uniqueness
    if team_in.name is not None and team_in.name != team.name:
        existing = db.query(Team).filter(Team.name == team_in.name, Team.id != id).first()
        if existing:
            raise HTTPException(status_code=400, detail="Team name already taken")
        team.name = team_in.name

    # Update captain if provided and check membership
    if team_in.captain_id is not None:
        if team_in.captain_id == UUID(int=0):  # Handle clearing captain (e.g. empty or null)
            team.captain_id = None
        else:
            # Check if captain player is in the team
            member = db.query(TeamPlayer).filter(
                TeamPlayer.team_id == id,
                TeamPlayer.player_id == team_in.captain_id
            ).first()
            if not member:
                raise HTTPException(status_code=400, detail="Captain must be a member of the team")
            team.captain_id = team_in.captain_id

    db.add(team)
    db.commit()
    db.refresh(team)
    return team


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_team(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    # Check authorization
    if team.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Block deletion if team belongs to active tournament (status == ongoing)
    active_tour = db.query(Tournament).join(TournamentTeam).filter(
        TournamentTeam.team_id == id,
        Tournament.status == "ongoing"
    ).first()
    if active_tour:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete team because it is registered in an active tournament: {active_tour.name}."
        )

    # Block deletion if team has scheduled/ongoing matches (status not in completed/abandoned)
    active_match = db.query(Match).filter(
        ((Match.team1_id == id) | (Match.team2_id == id)),
        ~Match.status.in_(["completed", "abandoned"])
    ).first()
    if active_match:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete team because it has scheduled or active matches: {active_match.team1.name} vs {active_match.team2.name}."
        )

    db.delete(team)
    db.commit()
    return None


@router.delete("/{id}/players/{player_id}", response_model=TeamResponse)
def remove_player_from_team(
    id: UUID,
    player_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    # Check authorization
    if team.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Check if player is a member
    assoc = db.query(TeamPlayer).filter(
        TeamPlayer.team_id == id,
        TeamPlayer.player_id == player_id
    ).first()
    if not assoc:
        raise HTTPException(status_code=404, detail="Player is not a member of this team")

    # Block removal if player is in an active (non-completed/non-abandoned) match squad of this team
    active_squad = db.query(Match).join(MatchSquad).filter(
        MatchSquad.player_id == player_id,
        MatchSquad.team_id == id,
        ~Match.status.in_(["completed", "abandoned"])
    ).first()
    if active_squad:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot remove player because they are part of an active match squad: {active_squad.team1.name} vs {active_squad.team2.name}."
        )

    # Delete membership relation
    db.delete(assoc)

    # Set captain_id to None if the removed player was the captain
    if team.captain_id == player_id:
        team.captain_id = None

    db.add(team)
    db.commit()
    db.refresh(team)
    return team
