import logging
from datetime import datetime, timezone, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, or_, and_
from uuid import UUID
import uuid

logger = logging.getLogger(__name__)

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User, Report, UserActivity
from app.models.cricket import Team, Player, Tournament, Match, TournamentTeam, MatchSquad, TeamPlayer
from app.schemas.user import UserResponse
from app.schemas.report import ReportCreate, ReportResponse

router = APIRouter()

def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        logger.error("403 REASON = ROLE_CHECK_FAILED")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required"
        )
    return current_user

def log_admin_action(db: Session, admin_id: UUID, action: str, entity_type: str, entity_id: UUID, details: str = None):
    """Log admin action to activity table"""
    activity = UserActivity(
        user_id=admin_id,
        activity_type=f"admin_{action}",
        description=f"Admin {action} {entity_type}: {entity_id}" + (f" - {details}" if details else "")
    )
    db.add(activity)
    db.commit()

# --- Public/User Report Endpoint ---

@router.post("/reports", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
def create_report(
    report_in: ReportCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Optional validation of content_type and existence of content_id
    if report_in.content_type == "tournament":
        content = db.query(Tournament).filter(Tournament.id == report_in.content_id).first()
    elif report_in.content_type == "match":
        content = db.query(Match).filter(Match.id == report_in.content_id).first()
    elif report_in.content_type == "team":
        content = db.query(Team).filter(Team.id == report_in.content_id).first()
    elif report_in.content_type == "player":
        content = db.query(Player).filter(Player.id == report_in.content_id).first()
    else:
        raise HTTPException(status_code=400, detail="Invalid content type")

    if not content:
        raise HTTPException(status_code=404, detail="Reported content not found")

    db_report = Report(
        reporter_id=current_user.id,
        content_type=report_in.content_type,
        content_id=report_in.content_id,
        reason=report_in.reason,
        status="pending",
        created_at=datetime.now(timezone.utc)
    )
    db.add(db_report)
    db.commit()
    db.refresh(db_report)
    return db_report

# --- Admin Analytics ---

@router.get("/admin/analytics", status_code=status.HTTP_200_OK)
def get_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    try:
        # Count total users - exclude deleted if column exists
        total_users_query = db.query(User)
        try:
            total_users_query = total_users_query.filter(User.is_deleted != True)
        except Exception:
            pass  # Column doesn't exist yet
        total_users = total_users_query.count()

        # Count active users (last 30 days) - handle NULL created_at
        thirty_days_ago = datetime.now(timezone.utc) - timedelta(days=30)
        active_users_query = db.query(User).filter(
            User.created_at != None,
            User.created_at >= thirty_days_ago
        )
        try:
            active_users_query = active_users_query.filter(User.is_deleted != True)
        except Exception:
            pass
        active_users = active_users_query.count()

        # Count live matches
        live_matches = db.query(Match).filter(Match.status == "live").count()

        return {
            "total_users": total_users,
            "total_teams": db.query(Team).count(),
            "total_players": db.query(Player).count(),
            "total_tournaments": db.query(Tournament).count(),
            "total_matches": db.query(Match).count(),
            "live_matches": live_matches,
            "active_users_30_days": active_users
        }
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=f"Analytics error: {str(e)}\n{traceback.format_exc()}")

# --- Admin Activity Logs ---

@router.get("/admin/activity-logs", status_code=status.HTTP_200_OK)
def get_admin_activity_logs(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """Get admin activity logs"""
    logs = db.query(UserActivity).filter(
        UserActivity.activity_type.like("admin_%")
    ).order_by(UserActivity.created_at.desc()).limit(limit).all()

    return [{
        "id": str(log.id),
        "user_id": str(log.user_id),
        "activity_type": log.activity_type,
        "description": log.description,
        "created_at": log.created_at.isoformat() if log.created_at else None
    } for log in logs]

# --- Admin System Logs (Secure) ---

@router.get("/admin/system-logs", status_code=status.HTTP_200_OK)
def get_system_logs(
    current_user: User = Depends(require_admin)
):
    """Retrieve live in-memory and request logs (admin only)"""
    from fastapi.responses import PlainTextResponse
    from app.main import memory_handler
    import os
    
    logs = memory_handler.get_logs()
    
    req_logs = ""
    if os.path.exists("static/requests.log"):
        try:
            with open("static/requests.log", "r") as f:
                req_logs = f.read()
        except Exception as e:
            req_logs = f"Error reading requests.log: {e}"
            
    combined = f"--- STARTUP & CONSOLE LOGS ---\n{logs}\n\n--- HTTP REQUEST LOGS ---\n{req_logs}"
    return PlainTextResponse(combined)

# --- User Management ---

@router.get("/admin/users", response_model=List[UserResponse])
def get_users(
    search: Optional[str] = Query(None),
    include_deleted: bool = Query(False, description="Include deleted users"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    query = db.query(User)

    # Exclude deleted users by default
    if not include_deleted:
        # Handle case where is_deleted column might not exist yet
        try:
            query = query.filter(User.is_deleted == False)
        except Exception:
            pass  # Column doesn't exist yet, continue without filter

    if search:
        search_term = f"%{search}%"
        query = query.filter(
            or_(
                User.username.ilike(search_term),
                User.email.ilike(search_term),
                User.full_name.ilike(search_term)
            )
        )
    return query.all()

@router.get("/admin/users/{id}", status_code=status.HTTP_200_OK)
def get_user_details(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """Get user details with their created teams, tournaments, and matches"""
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Get user's created teams
    teams = db.query(Team).filter(Team.created_by == id).all()

    # Get user's organized tournaments
    tournaments = db.query(Tournament).filter(Tournament.organizer_id == id).all()

    # Get user's matches (as organizer)
    matches = db.query(Match).filter(Match.created_by == id).all()

    return {
        "user": user,
        "created_teams": [{
            "id": str(t.id),
            "name": t.name,
            "player_count": len(t.players) if hasattr(t, 'players') else 0,
            "created_at": t.created_at.isoformat() if t.created_at else None
        } for t in teams],
        "organized_tournaments": [{
            "id": str(t.id),
            "name": t.name,
            "status": t.status,
            "created_at": t.created_at.isoformat() if t.created_at else None
        } for t in tournaments],
        "organized_matches": [{
            "id": str(m.id),
            "title": f"{m.team1_name} vs {m.team2_name}",
            "status": m.status,
            "created_at": m.created_at.isoformat() if m.created_at else None
        } for m in matches]
    }

@router.put("/admin/users/{id}/toggle-active", response_model=UserResponse)
def toggle_user_active(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    if id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot disable your own admin account"
        )
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.is_active = not user.is_active
    db.commit()
    db.refresh(user)

    log_admin_action(db, current_user.id, "toggle_active", "user", id, f"Set is_active to {user.is_active}")
    return user

@router.put("/admin/users/{id}/ban", response_model=UserResponse)
def ban_user(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    if id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot ban your own admin account"
        )
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.is_active = False
    user.role = "banned"
    db.commit()
    db.refresh(user)

    log_admin_action(db, current_user.id, "ban", "user", id)
    return user

@router.put("/admin/users/{id}/unban", response_model=UserResponse)
def unban_user(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.is_active = True
    user.role = "user"
    db.commit()
    db.refresh(user)

    log_admin_action(db, current_user.id, "unban", "user", id)
    return user

@router.delete("/admin/users/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    if id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot delete your own admin account"
        )
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Check if already deleted (idempotent check)
    if getattr(user, 'is_deleted', False):
        raise HTTPException(
            status_code=400,
            detail="User already deleted"
        )

    try:
        # Soft delete using is_deleted flag
        user.is_deleted = True
        user.is_active = False
        db.commit()

        log_admin_action(db, current_user.id, "delete", "user", id)
        return None
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete user: {str(e)}")

# --- Team Management ---

@router.get("/admin/teams", status_code=status.HTTP_200_OK)
def get_all_teams(
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    query = db.query(Team)
    if search:
        search_term = f"%{search}%"
        query = query.filter(Team.name.ilike(search_term))
    teams = query.all()

    result = []
    for t in teams:
        # Get creator name with explicit query
        creator_name = None
        creator = db.query(User).filter(User.id == t.created_by).first()
        creator_name = creator.full_name if creator else None

        # Get player count from team_players table
        player_count = db.query(TeamPlayer).filter(TeamPlayer.team_id == t.id).count()

        result.append({
            "id": str(t.id),
            "name": t.name,
            "captain_id": str(t.captain_id) if t.captain_id else None,
            "created_by": str(t.created_by),
            "creator_name": creator_name,
            "player_count": player_count,
            "created_at": t.created_at.isoformat() if t.created_at else None
        })
    return result

@router.get("/admin/teams/{id}", status_code=status.HTTP_200_OK)
def get_team_details(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    # Get players in team
    players = db.query(Player).join(TeamPlayer).filter(TeamPlayer.team_id == id).all()

    return {
        "id": str(team.id),
        "name": team.name,
        "logo_url": team.logo_url,
        "captain_id": str(team.captain_id) if team.captain_id else None,
        "created_by": str(team.created_by),
        "creator_name": team.creator.full_name if team.creator else None,
        "players": [{
            "id": str(p.id),
            "name": p.name,
            "role": p.role,
            "jersey_number": p.jersey_number
        } for p in players],
        "created_at": team.created_at.isoformat() if team.created_at else None
    }

@router.put("/admin/teams/{id}", status_code=status.HTTP_200_OK)
def update_team(
    id: UUID,
    name: Optional[str] = None,
    captain_id: Optional[UUID] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    if name:
        team.name = name
    if captain_id:
        team.captain_id = captain_id

    db.commit()
    db.refresh(team)

    log_admin_action(db, current_user.id, "update", "team", id, f"name={name}")
    return team

@router.delete("/admin/teams/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_team(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    db.delete(team)
    db.commit()

    log_admin_action(db, current_user.id, "delete", "team", id)
    return None

# --- Player Management ---

@router.get("/admin/players", status_code=status.HTTP_200_OK)
def get_all_players(
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    query = db.query(Player)
    if search:
        search_term = f"%{search}%"
        query = query.filter(Player.name.ilike(search_term))
    players = query.all()

    result = []
    for p in players:
        # Check if player is assigned to any team
        team_player = db.query(TeamPlayer).filter(TeamPlayer.player_id == p.id).first()
        team_name = None
        if team_player:
            team = db.query(Team).filter(Team.id == team_player.team_id).first()
            team_name = team.name if team else None

        result.append({
            "id": str(p.id),
            "name": p.name,
            "role": p.role,
            "jersey_number": p.jersey_number,
            "created_by": str(p.created_by) if p.created_by else None,
            "assigned_team": team_name,
            "created_at": p.created_at.isoformat() if hasattr(p, 'created_at') and p.created_at else None
        })

    return result

@router.get("/admin/players/{id}", status_code=status.HTTP_200_OK)
def get_player_details(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    player = db.query(Player).filter(Player.id == id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")

    # Check if player is assigned to any team
    team_player = db.query(TeamPlayer).filter(TeamPlayer.player_id == id).first()
    team_name = None
    team_id = None
    if team_player:
        team = db.query(Team).filter(Team.id == team_player.team_id).first()
        team_name = team.name if team else None
        team_id = str(team.id) if team else None

    return {
        "id": str(player.id),
        "name": player.name,
        "role": player.role,
        "batting_style": player.batting_style,
        "bowling_style": player.bowling_style,
        "jersey_number": player.jersey_number,
        "career_runs": player.career_runs,
        "career_wickets": player.career_wickets,
        "matches_played": player.matches_played,
        "created_by": str(player.created_by) if player.created_by else None,
        "assigned_team_id": team_id,
        "assigned_team_name": team_name
    }

@router.put("/admin/players/{id}", status_code=status.HTTP_200_OK)
def update_player(
    id: UUID,
    name: Optional[str] = None,
    role: Optional[str] = None,
    batting_style: Optional[str] = None,
    bowling_style: Optional[str] = None,
    jersey_number: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    player = db.query(Player).filter(Player.id == id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")

    if name:
        player.name = name
    if role:
        player.role = role
    if batting_style:
        player.batting_style = batting_style
    if bowling_style:
        player.bowling_style = bowling_style
    if jersey_number is not None:
        player.jersey_number = jersey_number

    db.commit()
    db.refresh(player)

    log_admin_action(db, current_user.id, "update", "player", id)
    return player

@router.delete("/admin/players/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_player(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    player = db.query(Player).filter(Player.id == id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")

    db.delete(player)
    db.commit()

    log_admin_action(db, current_user.id, "delete", "player", id)
    return None

# --- Tournament Management ---

@router.get("/admin/tournaments", status_code=status.HTTP_200_OK)
def get_all_tournaments(
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    query = db.query(Tournament)
    if search:
        search_term = f"%{search}%"
        query = query.filter(Tournament.name.ilike(search_term))
    tournaments = query.all()

    result = []
    for t in tournaments:
        # Count teams in tournament
        team_count = db.query(TournamentTeam).filter(TournamentTeam.tournament_id == t.id).count()

        # Get organizer name with explicit query instead of lazy loading
        organizer_name = None
        if t.organizer_id:
            organizer = db.query(User).filter(User.id == t.organizer_id).first()
            organizer_name = organizer.full_name if organizer else None

        result.append({
            "id": str(t.id),
            "name": t.name,
            "format": t.format,
            "status": t.status,
            "organizer_id": str(t.organizer_id) if t.organizer_id else None,
            "organizer_name": organizer_name,
            "team_count": team_count,
            "created_at": t.created_at.isoformat() if t.created_at else None
        })

    return result

@router.get("/admin/tournaments/{id}", status_code=status.HTTP_200_OK)
def get_tournament_details(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    tournament = db.query(Tournament).filter(Tournament.id == id).first()
    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    # Get participating teams
    tournament_teams = db.query(TournamentTeam).filter(TournamentTeam.tournament_id == id).all()
    teams = []
    for tt in tournament_teams:
        team = db.query(Team).filter(Team.id == tt.team_id).first()
        if team:
            teams.append({
                "id": str(team.id),
                "name": team.name
            })

    # Get organizer name with explicit query
    organizer_name = None
    if tournament.organizer_id:
        organizer = db.query(User).filter(User.id == tournament.organizer_id).first()
        organizer_name = organizer.full_name if organizer else None

    return {
        "id": str(tournament.id),
        "name": tournament.name,
        "format": tournament.format,
        "status": tournament.status,
        "start_date": tournament.start_date.isoformat() if tournament.start_date else None,
        "end_date": tournament.end_date.isoformat() if tournament.end_date else None,
        "organizer_id": str(tournament.organizer_id) if tournament.organizer_id else None,
        "organizer_name": organizer_name,
        "teams": teams
    }

@router.put("/admin/tournaments/{id}", status_code=status.HTTP_200_OK)
def update_tournament(
    id: UUID,
    name: Optional[str] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    tournament = db.query(Tournament).filter(Tournament.id == id).first()
    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    if name:
        tournament.name = name
    if status:
        tournament.status = status

    db.commit()
    db.refresh(tournament)

    log_admin_action(db, current_user.id, "update", "tournament", id)
    return tournament

@router.delete("/admin/tournaments/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_tournament(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    tournament = db.query(Tournament).filter(Tournament.id == id).first()
    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    db.delete(tournament)
    db.commit()

    log_admin_action(db, current_user.id, "delete", "tournament", id)
    return None

# --- Match Management ---

@router.get("/admin/matches", status_code=status.HTTP_200_OK)
def get_all_matches(
    search: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    query = db.query(Match)
    if search:
        search_term = f"%{search}%"
        query = query.filter(Match.venue.ilike(search_term))
    if status_filter:
        query = query.filter(Match.status == status_filter)

    matches = query.order_by(Match.created_at.desc()).all()

    result = []
    for m in matches:
        # Get team names
        team1_name = None
        team2_name = None
        if m.team1_id:
            team1 = db.query(Team).filter(Team.id == m.team1_id).first()
            team1_name = team1.name if team1 else None
        if m.team2_id:
            team2 = db.query(Team).filter(Team.id == m.team2_id).first()
            team2_name = team2.name if team2 else None

        winner_name = m.winner.name if (m.status == "completed" and m.winner) else None
        result_text = f"Won by {winner_name}" if winner_name else m.status

        result.append({
            "id": str(m.id),
            "title": f"{team1_name or 'Team 1'} vs {team2_name or 'Team 2'}",
            "team1_name": team1_name,
            "team2_name": team2_name,
            "status": m.status,
            "result": result_text,
            "organizer_id": str(m.created_by) if m.created_by else None,
            "created_at": m.created_at.isoformat() if m.created_at else None
        })

    return result

@router.get("/admin/matches/{id}", status_code=status.HTTP_200_OK)
def get_match_details(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    # Get team details
    team1 = db.query(Team).filter(Team.id == match.team1_id).first() if match.team1_id else None
    team2 = db.query(Team).filter(Team.id == match.team2_id).first() if match.team2_id else None

    winner_name = match.winner.name if (match.status == "completed" and match.winner) else None
    result_text = f"Won by {winner_name}" if winner_name else match.status

    return {
        "id": str(match.id),
        "title": f"{team1.name if team1 else 'Team 1'} vs {team2.name if team2 else 'Team 2'}",
        "team1_id": str(match.team1_id) if match.team1_id else None,
        "team1_name": team1.name if team1 else None,
        "team2_id": str(match.team2_id) if match.team2_id else None,
        "team2_name": team2.name if team2 else None,
        "status": match.status,
        "toss_winner": match.toss_winner.name if (match.toss_winner_id and match.toss_winner) else None,
        "toss_decision": match.toss_decision,
        "result": result_text,
        "winner_id": str(match.winner_id) if match.winner_id else None,
        "overs": match.over_limit,
        "umpire_id": None,
        "organizer_id": str(match.created_by) if match.created_by else None,
        "created_at": match.created_at.isoformat() if match.created_at else None
    }

@router.put("/admin/matches/{id}", status_code=status.HTTP_200_OK)
def update_match(
    id: UUID,
    title: Optional[str] = None,
    status: Optional[str] = None,
    result: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if status:
        match.status = status

    db.commit()
    db.refresh(match)

    log_admin_action(db, current_user.id, "update", "match", id)
    return match

@router.post("/admin/matches/{id}/force-end", status_code=status.HTTP_200_OK)
def force_end_match(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if match.status == "completed":
        raise HTTPException(status_code=400, detail="Match already completed")

    # Force end the match
    match.status = "completed"

    db.commit()
    db.refresh(match)

    log_admin_action(db, current_user.id, "force_end", "match", id)
    return match

@router.delete("/admin/matches/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_match(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    db.delete(match)
    db.commit()

    log_admin_action(db, current_user.id, "delete", "match", id)
    return None

# --- Reports & Moderation ---

@router.get("/admin/reports", status_code=status.HTTP_200_OK)
def get_reports(
    status_filter: Optional[str] = Query(None, alias="status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    query = db.query(Report)
    if status_filter:
        query = query.filter(Report.status == status_filter)
    return query.order_by(Report.created_at.desc()).all()

@router.post("/admin/reports/{id}/resolve", response_model=ReportResponse)
def resolve_report(
    id: UUID,
    action: str = Query("resolved"), # resolved or dismissed
    admin_notes: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    if action not in ["resolved", "dismissed"]:
        raise HTTPException(status_code=400, detail="Invalid action")

    report = db.query(Report).filter(Report.id == id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    report.status = action
    report.resolved_at = datetime.now(timezone.utc)
    report.resolved_by = current_user.id

    # Add admin notes if provided
    if admin_notes:
        # We would need to add admin_notes field to the Report model
        # For now, we'll append to the reason field
        report.reason = f"{report.reason}\n[Admin Notes: {admin_notes}]"

    db.commit()
    db.refresh(report)

    log_admin_action(db, current_user.id, f"resolve_report_{action}", "report", id)
    return report

