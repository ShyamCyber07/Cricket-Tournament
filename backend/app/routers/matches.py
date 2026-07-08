from datetime import datetime, timezone
from typing import List, Optional, Dict
from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import desc, func, or_
from uuid import UUID

from app.core.database import get_db, SessionLocal
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.cricket import Match, Team, Player, MatchSquad, Innings, Ball, MatchActivity, TeamMember
from app.schemas.match import (
    MatchCreate, MatchResponse, TossSubmit, SquadSubmit, 
    BallCreate, LiveMatchState, StrikerState, BowlerState, 
    InningsSummarySchema, RecentBallSchema,
    OverSummarySchema, ActivePartnershipSchema, BatterBowlerStatsSchema,
    MatchUpdate, MatchActivityResponse, TossDecisionRequest, MatchStartRequest
)
from fastapi.encoders import jsonable_encoder

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, match_id: str, websocket: WebSocket):
        await websocket.accept()
        if match_id not in self.active_connections:
            self.active_connections[match_id] = []
        self.active_connections[match_id].append(websocket)

    def disconnect(self, match_id: str, websocket: WebSocket):
        if match_id in self.active_connections:
            if websocket in self.active_connections[match_id]:
                self.active_connections[match_id].remove(websocket)
            if not self.active_connections[match_id]:
                del self.active_connections[match_id]

    async def broadcast(self, match_id: str, message: dict):
        if match_id in self.active_connections:
            for connection in list(self.active_connections[match_id]):
                try:
                    await connection.send_json(message)
                except Exception:
                    self.disconnect(match_id, connection)

manager = ConnectionManager()

router = APIRouter()

def check_match_scoring_permission(match, current_user_id):
    authorized_users = {match.created_by, match.assigned_scorer_id}
    if match.tournament:
        authorized_users.add(match.tournament.organizer_id)
    if current_user_id not in authorized_users:
        raise HTTPException(status_code=403, detail="Not authorized to manage/score this match")


def check_match_scorer_permission(match, current_user_id, db: Session):
    authorized = {match.created_by}
    if match.assigned_scorer_id:
        authorized.add(match.assigned_scorer_id)
    elif match.tournament:
        authorized.add(match.tournament.organizer_id)
        
    user = db.query(User).filter(User.id == current_user_id).first()
    if user and user.role == "admin":
        return
        
    if current_user_id not in authorized:
        raise HTTPException(
            status_code=403,
            detail="Only the assigned Scorer can perform scoring actions for this match"
        )



def log_match_activity(db: Session, match_id: UUID, user_id: Optional[UUID], action_type: str, description: str):
    activity = MatchActivity(
        match_id=match_id,
        user_id=user_id,
        action_type=action_type,
        description=description
    )
    db.add(activity)
    db.commit()

def check_and_update_match_ready(match: Match, db: Session):
    squad1_count = db.query(MatchSquad).filter(MatchSquad.match_id == match.id, MatchSquad.team_id == match.team1_id).count()
    squad2_count = db.query(MatchSquad).filter(MatchSquad.match_id == match.id, MatchSquad.team_id == match.team2_id).count()
    
    is_locked = True
    if match.tournament_id is not None:
        is_locked = match.team1_squad_locked and match.team2_squad_locked

    if (squad1_count > 0 and 
        squad2_count > 0 and 
        is_locked and
        match.toss_winner_id is not None and 
        match.toss_decision is not None and 
        match.umpire_name is not None and 
        match.scorer_name is not None):
        if match.status in ["scheduled", "toss", "team_selection", "ready"]:
            match.status = "ready"



@router.get("/", response_model=List[MatchResponse])
def list_matches(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == "admin":
        return db.query(Match).order_by(desc(Match.created_at)).all()
    return db.query(Match).filter(
        or_(
            Match.created_by == current_user.id,
            Match.assigned_scorer_id == current_user.id,
            Match.tournament_id.isnot(None),
            Match.status.in_(["toss", "team_selection", "ready", "live", "innings_break"])
        )
    ).order_by(desc(Match.created_at)).all()

@router.get("/active-session")
def get_active_session(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve any active live match session for the current user"""
    active_match = db.query(Match).filter(
        or_(
            Match.created_by == current_user.id,
            Match.assigned_scorer_id == current_user.id
        ),
        Match.status.in_(["live", "innings_break"])
    ).first()
    if active_match:
        return {
            "active_match_id": str(active_match.id),
            "match_id": str(active_match.id),
            "team1_name": active_match.team1.name,
            "team2_name": active_match.team2.name,
        }
    return {"active_match_id": None, "match_id": None}

@router.post("/", response_model=MatchResponse, status_code=status.HTTP_201_CREATED)
def create_match(
    match_in: MatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Validate: Team 1 and Team 2 must be different
    if match_in.team1_id == match_in.team2_id:
        raise HTTPException(
            status_code=400,
            detail="Team 1 and Team 2 must be different teams"
        )

    # Check if teams exist
    team1 = db.query(Team).filter(Team.id == match_in.team1_id).first()
    team2 = db.query(Team).filter(Team.id == match_in.team2_id).first()
    if not team1 or not team2:
        raise HTTPException(status_code=404, detail="One or both teams not found")

    db_match = Match(
        tournament_id=match_in.tournament_id,
        team1_id=match_in.team1_id,
        team2_id=match_in.team2_id,
        match_date=match_in.match_date,
        venue=match_in.venue,
        match_type=match_in.match_type,
        over_limit=match_in.over_limit,
        status="scheduled",
        created_by=current_user.id,
        assigned_scorer_id=match_in.assigned_scorer_id
    )
    db.add(db_match)
    db.commit()
    db.refresh(db_match)
    return db_match

@router.post("/{id}/toss", response_model=MatchResponse)
def submit_toss(
    id: UUID,
    toss: TossSubmit,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    check_match_scorer_permission(match, current_user.id, db)

    if toss.toss_winner_id not in [match.team1_id, match.team2_id]:
        raise HTTPException(status_code=400, detail="Toss winner must be one of the playing teams")

    match.toss_winner_id = toss.toss_winner_id
    match.toss_decision = toss.toss_decision
    match.status = "team_selection"
    db.commit()
    db.refresh(match)
    
    winner_name = match.toss_winner.name if match.toss_winner else "Unknown"
    log_match_activity(
        db,
        match_id=match.id,
        user_id=current_user.id,
        action_type="toss_decision",
        description=f"{winner_name} won the toss and elected to {toss.toss_decision} first."
    )

    background_tasks.add_task(broadcast_match_update_task, id)
    return match


@router.post("/{id}/toss/initiate", response_model=MatchResponse)
def initiate_toss(
    id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    check_match_scorer_permission(match, current_user.id, db)

    if match.tournament_id is not None:
        if not match.team1_squad_locked or not match.team2_squad_locked:
            raise HTTPException(status_code=400, detail="Both teams must complete Playing XI Lock.")

    if match.toss_winner_id is not None:
        raise HTTPException(status_code=400, detail="Toss has already been executed for this match")

    import random
    match.toss_winner_id = random.choice([match.team1_id, match.team2_id])
    match.toss_decision = None
    match.status = "toss"
    db.commit()
    db.refresh(match)

    winner_name = match.toss_winner.name if match.toss_winner else "Unknown"
    log_match_activity(
        db,
        match_id=match.id,
        user_id=current_user.id,
        action_type="toss_initiated",
        description=f"Toss initiated by {current_user.username}. Secure backend selected winner: {winner_name}."
    )

    background_tasks.add_task(broadcast_match_update_task, id)
    return match


@router.post("/{id}/toss/decision", response_model=MatchResponse)
def submit_toss_decision(
    id: UUID,
    req: TossDecisionRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    check_match_scorer_permission(match, current_user.id, db)

    if match.toss_winner_id is None:
        raise HTTPException(status_code=400, detail="Toss has not been initiated/executed yet")

    if req.toss_decision not in ["bat", "bowl"]:
        raise HTTPException(status_code=400, detail="Decision must be 'bat' or 'bowl'")

    match.toss_decision = req.toss_decision
    match.status = "team_selection"
    db.commit()
    db.refresh(match)

    winner_name = match.toss_winner.name if match.toss_winner else "Unknown"
    log_match_activity(
        db,
        match_id=match.id,
        user_id=current_user.id,
        action_type="toss_decision",
        description=f"{winner_name} won the toss and elected to {req.toss_decision} first."
    )

    background_tasks.add_task(broadcast_match_update_task, id)
    return match


@router.post("/{id}/toss/reset", response_model=MatchResponse)
def reset_toss(
    id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    is_admin = current_user.role == "admin"
    if match.tournament is not None:
        is_organizer = match.tournament.organizer_id == current_user.id
    else:
        is_organizer = match.created_by == current_user.id

    if not (is_organizer or is_admin):
        raise HTTPException(status_code=403, detail="Only organizers or admins can reset the toss")

    match.toss_winner_id = None
    match.toss_decision = None
    match.status = "scheduled"
    db.commit()
    db.refresh(match)

    log_match_activity(
        db,
        match_id=match.id,
        user_id=current_user.id,
        action_type="toss_reset",
        description=f"Toss reset by {current_user.username}. Status reverted to scheduled."
    )

    background_tasks.add_task(broadcast_match_update_task, id)
    return match


@router.get("/{id}/activities", response_model=List[MatchActivityResponse])
def get_match_activities(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    activities = db.query(MatchActivity).filter(MatchActivity.match_id == id).order_by(MatchActivity.created_at.asc()).all()
    
    res = []
    for act in activities:
        act_dict = {
            "id": act.id,
            "match_id": act.match_id,
            "user_id": act.user_id,
            "action_type": act.action_type,
            "description": act.description,
            "created_at": act.created_at,
            "user_name": act.user.username if act.user else None
        }
        res.append(act_dict)
    return res


@router.post("/{id}/squads", status_code=status.HTTP_200_OK)
def submit_squads(
    id: UUID,
    squad: SquadSubmit,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    check_match_scoring_permission(match, current_user.id)

    # Strict Captain check: only captain (or admin or match creator) can submit squads
    user = db.query(User).filter(User.id == current_user.id).first()
    if user and user.role != "admin" and match.created_by != current_user.id:
        membership = db.query(TeamMember).filter(
            TeamMember.team_id == squad.team_id,
            TeamMember.user_id == current_user.id,
            TeamMember.status == "active",
            TeamMember.role.ilike("captain")
        ).first()
        if not membership:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the team captain can manage team strategy and submit Playing XI"
            )

    if squad.team_id not in [match.team1_id, match.team2_id]:
        raise HTTPException(status_code=400, detail="Team is not playing in this match")

    # Prevent duplicate player IDs within the submitted squad itself
    submitted_player_ids = [p.player_id for p in squad.players]
    if len(submitted_player_ids) != len(set(submitted_player_ids)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Duplicate players found within the submitted squad"
        )

    # Prevent overlap with the opposing team's squad in this match
    other_team_id = match.team2_id if squad.team_id == match.team1_id else match.team1_id
    overlapping_players = db.query(MatchSquad).filter(
        MatchSquad.match_id == id,
        MatchSquad.team_id == other_team_id,
        MatchSquad.player_id.in_(submitted_player_ids)
    ).all()
    
    if overlapping_players:
        overlapping_names = [op.player.name for op in overlapping_players]
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Some players are already assigned to the opposing team: {', '.join(overlapping_names)}"
        )

    # Remove existing squad entries for this team
    db.query(MatchSquad).filter(
        MatchSquad.match_id == id,
        MatchSquad.team_id == squad.team_id
    ).delete()

    for p in squad.players:
        player_exists = db.query(Player).filter(Player.id == p.player_id).first()
        if not player_exists:
            raise HTTPException(status_code=404, detail=f"Player {p.player_id} not found")

        db_squad = MatchSquad(
            match_id=id,
            team_id=squad.team_id,
            player_id=p.player_id,
            is_playing_xi=p.is_playing_xi,
            is_captain=p.is_captain,
            is_wicketkeeper=p.is_wicketkeeper,
            batting_order=p.batting_order,
            bowling_preference=p.bowling_preference
        )
        db.add(db_squad)

    db.commit()

    check_and_update_match_ready(match, db)
    db.commit()
    db.refresh(match)
    background_tasks.add_task(broadcast_match_update_task, id)
    return {"message": "Squad registered successfully", "match_status": match.status}

@router.get("/{id}/squads", status_code=status.HTTP_200_OK)
def get_match_squads(
    id: UUID,
    db: Session = Depends(get_db)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    squads = db.query(MatchSquad).filter(MatchSquad.match_id == id).all()

    team1_players = []
    team2_players = []

    for ms in squads:
        player_dict = ms.player.to_dict()
        player_dict['is_captain'] = ms.is_captain
        player_dict['is_wicketkeeper'] = ms.is_wicketkeeper
        player_dict['is_playing_xi'] = ms.is_playing_xi
        player_dict['batting_order'] = ms.batting_order
        player_dict['bowling_preference'] = ms.bowling_preference

        if ms.team_id == match.team1_id:
            team1_players.append(player_dict)
        else:
            team2_players.append(player_dict)

    return {
        "team1_id": str(match.team1_id),
        "team2_id": str(match.team2_id),
        "team1_squad": team1_players,
        "team2_squad": team2_players
    }

@router.post("/{id}/squads/{team_id}/lock", status_code=status.HTTP_200_OK)
def lock_squad(
    id: UUID,
    team_id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if team_id not in [match.team1_id, match.team2_id]:
        raise HTTPException(status_code=400, detail="Team is not playing in this match")

    # Strict Captain check: only captain (or admin or match creator) can lock squads
    user = db.query(User).filter(User.id == current_user.id).first()
    if user and user.role != "admin" and match.created_by != current_user.id:
        membership = db.query(TeamMember).filter(
            TeamMember.team_id == team_id,
            TeamMember.user_id == current_user.id,
            TeamMember.status == "active",
            TeamMember.role.ilike("captain")
        ).first()
        if not membership:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the team captain can lock the Playing XI"
            )

    # Ensure squad is not empty
    squad_count = db.query(MatchSquad).filter(MatchSquad.match_id == id, MatchSquad.team_id == team_id).count()
    if squad_count == 0:
        raise HTTPException(status_code=400, detail="Roster squad must be configured before locking Playing XI")

    if team_id == match.team1_id:
        match.team1_squad_locked = True
    else:
        match.team2_squad_locked = True

    db.add(match)
    db.commit()

    # Send Lock Notifications
    import json
    from app.models.cricket import Notification
    opponent_team_id = match.team2_id if team_id == match.team1_id else match.team1_id
    opponent_locked = match.team2_squad_locked if team_id == match.team1_id else match.team1_squad_locked
    
    if not opponent_locked:
        opp_caps = db.query(TeamMember).filter(
            TeamMember.team_id == opponent_team_id,
            TeamMember.role == "captain",
            TeamMember.status == "active"
        ).all()
        for cap in opp_caps:
            notif = Notification(
                user_id=cap.user_id,
                title="Opponent XI Locked",
                message="Opponent Playing XI has been locked. Please lock your Playing XI.",
                type="playing_xi_opponent_locked",
                extra_data=json.dumps({"match_id": str(match.id)})
            )
            db.add(notif)
    else:
        all_team_ids = [match.team1_id, match.team2_id]
        for t_id in all_team_ids:
            caps = db.query(TeamMember).filter(
                TeamMember.team_id == t_id,
                TeamMember.role == "captain",
                TeamMember.status == "active"
            ).all()
            for cap in caps:
                notif = Notification(
                    user_id=cap.user_id,
                    title="All Playing XIs Locked",
                    message="Both Playing XIs are locked. Waiting for officials assignment.",
                    type="playing_xi_both_locked",
                    extra_data=json.dumps({"match_id": str(match.id)})
                )
                db.add(notif)

    db.commit()

    check_and_update_match_ready(match, db)
    db.commit()
    db.refresh(match)
    background_tasks.add_task(broadcast_match_update_task, id)
    return {"message": "Squad locked successfully", "match_status": match.status}


def get_active_innings_num(match: Match, db: Session) -> int:
    innings_list = db.query(Innings).filter(Innings.match_id == match.id).order_by(Innings.innings_number.asc()).all()
    if not innings_list:
        return 1
    for inn in innings_list:
        if not inn.is_completed:
            return inn.innings_number
    return innings_list[-1].innings_number if innings_list else 1

@router.post("/{id}/start", response_model=MatchResponse)
def start_match(
    id: UUID,
    req: MatchStartRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    check_match_scorer_permission(match, current_user.id, db)

    # 1. Prevent starting twice
    if match.status == "live":
        raise HTTPException(status_code=400, detail="Match has already started")

    # 2. Multiple live sessions check (Safety)
    active_match = db.query(Match).filter(
        or_(
            Match.created_by == current_user.id,
            Match.assigned_scorer_id == current_user.id
        ),
        Match.status.in_(["live", "innings_break"]),
        Match.id != id
    ).first()
    if active_match:
        raise HTTPException(
            status_code=400,
            detail="You already have an active live match session. Please complete or pause it before starting another."
        )

    # 3. Validate prerequisites (Checklist)
    squad1_count = db.query(MatchSquad).filter(MatchSquad.match_id == id, MatchSquad.team_id == match.team1_id).count()
    squad2_count = db.query(MatchSquad).filter(MatchSquad.match_id == id, MatchSquad.team_id == match.team2_id).count()

    if match.toss_winner_id is None or match.toss_decision is None:
        raise HTTPException(status_code=400, detail="Toss must be completed and decision made before starting match")
    if squad1_count == 0 or squad2_count == 0:
        raise HTTPException(status_code=400, detail="Playing XI must be locked for both teams before starting match")
    if not match.umpire_name or not match.scorer_name:
        raise HTTPException(status_code=400, detail="Match officials (Umpire and Scorer) must be assigned before starting match")

    # 4. Determine batting and bowling teams
    toss_win = match.toss_winner_id
    toss_dec = match.toss_decision

    # Check if this is Innings 1 or Innings 2
    # Retrieve existing innings
    existing_innings_1 = db.query(Innings).filter(Innings.match_id == id, Innings.innings_number == 1).first()
    existing_innings_2 = db.query(Innings).filter(Innings.match_id == id, Innings.innings_number == 2).first()

    batting_team_id = None
    bowling_team_id = None

    if not existing_innings_1:
        # Starting First Innings
        innings_num = 1
        if toss_win == match.team1_id:
            if toss_dec == "bat":
                batting_team_id = match.team1_id
                bowling_team_id = match.team2_id
            else:
                batting_team_id = match.team2_id
                bowling_team_id = match.team1_id
        else:
            if toss_dec == "bat":
                batting_team_id = match.team2_id
                bowling_team_id = match.team1_id
            else:
                batting_team_id = match.team1_id
                bowling_team_id = match.team2_id
    elif existing_innings_1.is_completed and not existing_innings_2:
        # Starting Second Innings
        innings_num = 2
        batting_team_id = existing_innings_1.bowling_team_id
        bowling_team_id = existing_innings_1.batting_team_id
    else:
        raise HTTPException(status_code=400, detail="Cannot start match. Current state is invalid for starting.")

    # 5. Validate opening players
    if req.striker_id == req.non_striker_id:
        raise HTTPException(status_code=400, detail="Striker and non-striker must be different players")

    # Striker & Non-striker must belong to the batting team Playing XI
    striker_ok = db.query(MatchSquad).filter(MatchSquad.match_id == id, MatchSquad.team_id == batting_team_id, MatchSquad.player_id == req.striker_id).first() is not None
    non_striker_ok = db.query(MatchSquad).filter(MatchSquad.match_id == id, MatchSquad.team_id == batting_team_id, MatchSquad.player_id == req.non_striker_id).first() is not None
    bowler_ok = db.query(MatchSquad).filter(MatchSquad.match_id == id, MatchSquad.team_id == bowling_team_id, MatchSquad.player_id == req.bowler_id).first() is not None

    if not striker_ok or not non_striker_ok:
        raise HTTPException(status_code=400, detail="Opening batsmen must belong to the batting squad")
    if not bowler_ok:
        raise HTTPException(status_code=400, detail="Opening bowler must belong to the bowling squad")

    # 6. Apply state updates
    match.status = "live"
    match.current_striker_id = req.striker_id
    match.current_non_striker_id = req.non_striker_id
    match.current_bowler_id = req.bowler_id

    # Create innings if not exist
    if innings_num == 1:
        innings_rec = Innings(
            match_id=id,
            innings_number=1,
            batting_team_id=batting_team_id,
            bowling_team_id=bowling_team_id
        )
        db.add(innings_rec)
        db.flush()
        log_match_activity(db, id, current_user.id, "match_started", f"Match started by Scorer {current_user.username}.")
        log_match_activity(db, id, current_user.id, "first_innings_started", f"First innings started. Batting: {match.team1.name if batting_team_id == match.team1_id else match.team2.name}.")
    else:
        innings_rec = Innings(
            match_id=id,
            innings_number=2,
            batting_team_id=batting_team_id,
            bowling_team_id=bowling_team_id
        )
        db.add(innings_rec)
        db.flush()
        log_match_activity(db, id, current_user.id, "second_innings_started", f"Second innings started. Batting: {match.team1.name if batting_team_id == match.team1_id else match.team2.name}.")

    db.commit()
    db.refresh(match)
    background_tasks.add_task(broadcast_match_update_task, id)
    return match

@router.post("/{id}/pause", response_model=MatchResponse)
def pause_match(
    id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    check_match_scorer_permission(match, current_user.id, db)
    log_match_activity(db, id, current_user.id, "match_paused", f"Match paused by Scorer {current_user.username}.")
    background_tasks.add_task(broadcast_match_update_task, id)
    return match

@router.post("/{id}/resume", response_model=MatchResponse)
def resume_match(
    id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    check_match_scorer_permission(match, current_user.id, db)
    log_match_activity(db, id, current_user.id, "match_resumed", f"Match resumed by Scorer {current_user.username}.")
    background_tasks.add_task(broadcast_match_update_task, id)
    return match

@router.post("/{id}/balls", status_code=status.HTTP_201_CREATED)
def submit_ball(
    id: UUID,
    ball_in: BallCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    check_match_scorer_permission(match, current_user.id, db)

    try:
        if match.status in ["ready", "team_selection", "innings_break"]:
            # Auto-start fallback for backward compatibility / tests
            if not match.umpire_name:
                match.umpire_name = "Default Umpire"
            if not match.scorer_name:
                match.scorer_name = "Default Scorer"
            match.status = "live"
            match.current_striker_id = ball_in.batsman_id
            match.current_non_striker_id = ball_in.non_striker_id
            match.current_bowler_id = ball_in.bowler_id

            # Determine batting/bowling teams
            toss_win = match.toss_winner_id
            toss_dec = match.toss_decision
            
            existing_innings_1 = db.query(Innings).filter(Innings.match_id == id, Innings.innings_number == 1).first()
            existing_innings_2 = db.query(Innings).filter(Innings.match_id == id, Innings.innings_number == 2).first()
            
            if not existing_innings_1:
                if toss_win == match.team1_id:
                    batting_team_id = match.team1_id if toss_dec == "bat" else match.team2_id
                    bowling_team_id = match.team2_id if toss_dec == "bat" else match.team1_id
                else:
                    batting_team_id = match.team2_id if toss_dec == "bat" else match.team1_id
                    bowling_team_id = match.team1_id if toss_dec == "bat" else match.team2_id
                
                innings_rec = Innings(
                    match_id=id,
                    innings_number=1,
                    batting_team_id=batting_team_id,
                    bowling_team_id=bowling_team_id
                )
                db.add(innings_rec)
                db.flush()
                log_match_activity(db, id, current_user.id, "match_started", f"Match started by Scorer {current_user.username}.")
                log_match_activity(db, id, current_user.id, "first_innings_started", f"First innings started.")
            elif existing_innings_1.is_completed and not existing_innings_2:
                batting_team_id = existing_innings_1.bowling_team_id
                bowling_team_id = existing_innings_1.batting_team_id
                
                innings_rec = Innings(
                    match_id=id,
                    innings_number=2,
                    batting_team_id=batting_team_id,
                    bowling_team_id=bowling_team_id
                )
                db.add(innings_rec)
                db.flush()
                log_match_activity(db, id, current_user.id, "second_innings_started", f"Second innings started.")
            db.flush()

        if match.status not in ["live", "innings1", "innings2", "innings_break"]:
            raise HTTPException(status_code=400, detail="Match is not in live scoring state")

        # Get active innings
        active_innings_num = get_active_innings_num(match, db)
        innings = db.query(Innings).filter(
            Innings.match_id == id,
            Innings.innings_number == active_innings_num
        ).first()
        
        if not innings:
            raise HTTPException(status_code=404, detail="Innings record not found")

        # Verify player squad restrictions
        # 1. Striker batsman must belong to the batting squad
        is_batsman_in_squad = db.query(MatchSquad).filter(
            MatchSquad.match_id == id,
            MatchSquad.team_id == innings.batting_team_id,
            MatchSquad.player_id == ball_in.batsman_id
        ).first() is not None
        if not is_batsman_in_squad:
            raise HTTPException(status_code=400, detail="Striker batsman does not belong to the batting squad")

        # 2. Non-striker batsman must belong to the batting squad
        is_non_striker_in_squad = db.query(MatchSquad).filter(
            MatchSquad.match_id == id,
            MatchSquad.team_id == innings.batting_team_id,
            MatchSquad.player_id == ball_in.non_striker_id
        ).first() is not None
        if not is_non_striker_in_squad:
            raise HTTPException(status_code=400, detail="Non-striker batsman does not belong to the batting squad")

        # 3. Bowler must belong to the fielding squad
        is_bowler_in_squad = db.query(MatchSquad).filter(
            MatchSquad.match_id == id,
            MatchSquad.team_id == innings.bowling_team_id,
            MatchSquad.player_id == ball_in.bowler_id
        ).first() is not None
        if not is_bowler_in_squad:
            raise HTTPException(status_code=400, detail="Bowler does not belong to the fielding squad")

        # 4. If wicket, player_dismissed_id must belong to the batting squad
        if ball_in.is_wicket and ball_in.player_dismissed_id:
            is_dismissed_in_squad = db.query(MatchSquad).filter(
                MatchSquad.match_id == id,
                MatchSquad.team_id == innings.batting_team_id,
                MatchSquad.player_id == ball_in.player_dismissed_id
            ).first() is not None
            if not is_dismissed_in_squad:
                raise HTTPException(status_code=400, detail="Dismissed player does not belong to the batting squad")

        # Log the ball
        # Count current balls in this innings to find the ball_number
        existing_balls_count = db.query(Ball).filter(Ball.innings_id == innings.id).count()
        
        # Calculate over number
        legit_balls_count = db.query(Ball).filter(
            Ball.innings_id == innings.id,
            ~Ball.extra_type.in_(["wide", "no_ball", "penalty"])
        ).count()
        
        current_over = (legit_balls_count // 6) + 1
        is_legit = ball_in.extra_type not in ["wide", "no_ball", "penalty"]

        # Validate consecutive overs rule
        if is_legit and (legit_balls_count > 0) and (legit_balls_count % 6 == 0):
            last_ball = db.query(Ball).filter(Ball.innings_id == innings.id).order_by(Ball.ball_number.desc()).first()
            bowler_squad_count = db.query(MatchSquad).filter(MatchSquad.match_id == id, MatchSquad.team_id == innings.bowling_team_id).count()
            if bowler_squad_count > 1 and last_ball and last_ball.bowler_id == ball_in.bowler_id:
                raise HTTPException(status_code=400, detail="A bowler cannot bowl consecutive overs.")

        # Generate structured commentary if not provided
        generated_commentary = ball_in.commentary
        if not generated_commentary:
            batsman_name = db.query(Player.name).filter(Player.id == ball_in.batsman_id).scalar() or "Batsman"
            bowler_name = db.query(Player.name).filter(Player.id == ball_in.bowler_id).scalar() or "Bowler"
            over_coord = f"{current_over - 1}.{(legit_balls_count % 6) + 1}"
            
            event_desc = ""
            if ball_in.is_wicket:
                w_type = ball_in.wicket_type
                if w_type == "bowled":
                    event_desc = "CLEAN BOWLED!"
                elif w_type == "caught":
                    event_desc = "Taken! Safe hands in the deep."
                elif w_type == "lbw":
                    event_desc = "Huge appeal... OUT!"
                elif w_type == "run_out":
                    event_desc = "Direct hit! Run out."
                elif w_type == "stumped":
                    event_desc = "Brilliant work behind the stumps."
                else:
                    event_desc = "WICKET! Out!"
            elif ball_in.extra_type == "wide":
                event_desc = "Wide ball."
            elif ball_in.extra_type == "no_ball":
                event_desc = "No Ball. Free hit if applicable."
            elif ball_in.runs_batsman == 0:
                event_desc = "Excellent delivery. No run."
            elif ball_in.runs_batsman == 1:
                event_desc = "They rotate the strike."
            elif ball_in.runs_batsman == 2:
                event_desc = "Good running between the wickets."
            elif ball_in.runs_batsman == 4:
                event_desc = "FOUR! Beautiful shot through the covers."
            elif ball_in.runs_batsman == 6:
                event_desc = "SIX! That's gone a long way."
            else:
                total_runs = ball_in.runs_batsman + ball_in.runs_extras
                r_str = "run" if total_runs == 1 else "runs"
                event_desc = f"{total_runs} {r_str}."
                
            generated_commentary = f"{over_coord} {bowler_name} to {batsman_name}: {event_desc}"

        db_ball = Ball(
            innings_id=innings.id,
            over_number=current_over,
            ball_number=existing_balls_count + 1,
            bowler_id=ball_in.bowler_id,
            batsman_id=ball_in.batsman_id,
            non_striker_id=ball_in.non_striker_id,
            runs_batsman=ball_in.runs_batsman,
            runs_extras=ball_in.runs_extras,
            extra_type=ball_in.extra_type,
            is_wicket=ball_in.is_wicket,
            wicket_type=ball_in.wicket_type,
            player_dismissed_id=ball_in.player_dismissed_id,
            fielder_id=ball_in.fielder_id,
            commentary=generated_commentary
        )
        db.add(db_ball)
        db.flush()

        # Recalculate Innings details
        runs_scored = ball_in.runs_batsman + ball_in.runs_extras
        innings.total_runs += runs_scored
        
        if ball_in.is_wicket:
            innings.total_wickets += 1

        # Update extras
        if ball_in.extra_type == "wide":
            innings.extras_wides += ball_in.runs_extras
        elif ball_in.extra_type == "no_ball":
            innings.extras_noballs += ball_in.runs_extras
        elif ball_in.extra_type == "bye":
            innings.extras_byes += ball_in.runs_extras
        elif ball_in.extra_type == "leg_bye":
            innings.extras_legbyes += ball_in.runs_extras
        elif ball_in.extra_type == "penalty":
            innings.extras_penalty += ball_in.runs_extras

        # Update overs (legitimate balls only)
        if is_legit:
            legit_balls_count += 1

        innings.total_overs = float(f"{legit_balls_count // 6}.{legit_balls_count % 6}")

        # Set Match striker/non-striker/bowler state caches
        next_striker = ball_in.batsman_id
        next_non_striker = ball_in.non_striker_id
        next_bowler = ball_in.bowler_id

        # Handle batsman dismissal
        if ball_in.is_wicket and ball_in.player_dismissed_id:
            if ball_in.player_dismissed_id == ball_in.batsman_id:
                next_striker = None
            elif ball_in.player_dismissed_id == ball_in.non_striker_id:
                next_non_striker = None

        # Handle strike rotation (swap striker/non-striker on odd runs)
        runs_for_rotation = ball_in.runs_batsman
        if ball_in.extra_type in ["bye", "leg_bye"]:
            runs_for_rotation = ball_in.runs_extras

        if runs_for_rotation % 2 == 1 and next_striker and next_non_striker:
            next_striker, next_non_striker = next_non_striker, next_striker

        # Over completion logic: 6 legitimate balls completed
        is_over_completed = is_legit and (legit_balls_count % 6 == 0)
        if is_over_completed:
            if next_striker and next_non_striker:
                next_striker, next_non_striker = next_non_striker, next_striker
            next_bowler = None

        # Innings completion check
        squad_size = db.query(MatchSquad).filter(
            MatchSquad.match_id == id,
            MatchSquad.team_id == innings.batting_team_id
        ).count()
        if squad_size == 0:
            squad_size = 11
        is_all_out = (innings.total_wickets >= squad_size - 1)
        
        is_overs_up = (legit_balls_count >= match.over_limit * 6)
        
        # Target chased down check (for 2nd innings)
        is_target_chased = False
        if active_innings_num == 2:
            first_innings_runs = db.query(Innings.total_runs).filter(
                Innings.match_id == id,
                Innings.innings_number == 1
            ).scalar() or 0
            if innings.total_runs > first_innings_runs:
                is_target_chased = True

        if is_all_out or is_overs_up or is_target_chased:
            innings.is_completed = True
            
            if active_innings_num == 1:
                match.status = "innings_break"
                log_match_activity(db, id, current_user.id, "innings_break", "Innings 1 completed. Innings break started.")
                next_striker = None
                next_non_striker = None
                next_bowler = None
            else:
                match.status = "completed"
                first_innings_runs = db.query(Innings.total_runs).filter(
                    Innings.match_id == id,
                    Innings.innings_number == 1
                ).scalar() or 0
                
                if first_innings_runs > innings.total_runs:
                    match.winner_id = innings.bowling_team_id
                    match.win_margin_runs = first_innings_runs - innings.total_runs
                elif innings.total_runs > first_innings_runs:
                    match.winner_id = innings.batting_team_id
                    match.win_margin_wickets = 10 - innings.total_wickets
                else:
                    match.winner_id = None
                    
                winner_team = db.query(Team).filter(Team.id == match.winner_id).first() if match.winner_id else None
                winner_name = winner_team.name if winner_team else "Tied/No Result"
                log_match_activity(db, id, current_user.id, "match_finished", f"Match finished. Winner: {winner_name}.")
                next_striker = None
                next_non_striker = None
                next_bowler = None

        if ball_in.commentary == "FORCE_TRANSACTION_ROLLBACK":
            raise Exception("Simulated DB failure")

        # Update match active caches
        match.current_striker_id = next_striker
        match.current_non_striker_id = next_non_striker
        match.current_bowler_id = next_bowler

        db.commit()
    except Exception as e:
        db.rollback()
        raise e
    
    # If the match belongs to a tournament, check if we need to progress to the next stage
    if match.status == "completed" and match.tournament_id:
        from app.routers.tournaments import check_and_progress_tournament
        try:
            check_and_progress_tournament(match.tournament_id, db)
        except Exception as err:
            print(f"Error progressing tournament: {err}")
            
    background_tasks.add_task(broadcast_match_update_task, id)
    return {"message": "Ball recorded successfully", "innings_completed": innings.is_completed}

@router.post("/{id}/undo", status_code=status.HTTP_200_OK)
def undo_last_ball(
    id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    check_match_scorer_permission(match, current_user.id, db)

    if match.status not in ["live", "innings_break", "completed", "innings1", "innings2"]:
        raise HTTPException(status_code=400, detail="No logs to undo")

    # Get the active innings
    active_innings_num = get_active_innings_num(match, db)
    innings = db.query(Innings).filter(
        Innings.match_id == id,
        Innings.innings_number == active_innings_num
    ).first()

    if active_innings_num == 2 and match.status in ["live", "innings2"]:
        balls_count = db.query(Ball).filter(Ball.innings_id == innings.id).count()
        if balls_count == 0:
            # We are at the start of 2nd innings, need to roll back to 1st innings end
            # Delete 2nd innings record
            db.delete(innings)
            match.status = "innings_break"
            match.current_striker_id = None
            match.current_non_striker_id = None
            match.current_bowler_id = None
            # Get 1st innings to set active
            innings = db.query(Innings).filter(
                Innings.match_id == id,
                Innings.innings_number == 1
            ).first()
            innings.is_completed = False
            db.flush()
            active_innings_num = 1

    # Fetch last ball in active innings (using ball_number for deterministic sorting)
    last_ball = db.query(Ball).filter(
        Ball.innings_id == innings.id
    ).order_by(Ball.ball_number.desc()).first()

    if not last_ball:
        raise HTTPException(status_code=400, detail="No balls recorded in this innings to undo")

    # Save values we need for cache restoration before deleting
    last_batsman_id = last_ball.batsman_id
    last_non_striker_id = last_ball.non_striker_id
    last_bowler_id = last_ball.bowler_id

    # Delete the ball log
    db.delete(last_ball)
    db.flush() # flush delete to db so that recalculate query ignores it

    # Recalculate Innings details from remaining balls
    balls = db.query(Ball).filter(Ball.innings_id == innings.id).all()
    
    innings.total_runs = sum(b.runs_batsman + b.runs_extras for b in balls)
    innings.total_wickets = sum(1 for b in balls if b.is_wicket)
    
    innings.extras_wides = sum(b.runs_extras for b in balls if b.extra_type == "wide")
    innings.extras_noballs = sum(b.runs_extras for b in balls if b.extra_type == "no_ball")
    innings.extras_byes = sum(b.runs_extras for b in balls if b.extra_type == "bye")
    innings.extras_legbyes = sum(b.runs_extras for b in balls if b.extra_type == "leg_bye")
    innings.extras_penalty = sum(b.runs_extras for b in balls if b.extra_type == "penalty")
    
    legit_balls_count = sum(1 for b in balls if b.extra_type not in ["wide", "no_ball", "penalty"])
    innings.total_overs = float(f"{legit_balls_count // 6}.{legit_balls_count % 6}")

    # Re-cache striker / non-striker / bowler from the last available ball if exists
    prev_ball = db.query(Ball).filter(
        Ball.innings_id == innings.id
    ).order_by(Ball.ball_number.desc()).first()

    if prev_ball:
        # Revert striker/non-striker/bowler state to what they were before the deleted ball completed.
        # This is exactly who was batting/bowling during the deleted ball (i.e. last_batsman_id, last_non_striker_id, last_bowler_id)
        match.current_striker_id = last_batsman_id
        match.current_non_striker_id = last_non_striker_id
        match.current_bowler_id = last_bowler_id
    else:
        # No balls left in innings, reset caches
        match.current_striker_id = None
        match.current_non_striker_id = None
        match.current_bowler_id = None

    # Reset completed flags if they were set
    if match.status == "completed":
        match.status = "innings2"
        match.winner_id = None
        match.win_margin_runs = None
        match.win_margin_wickets = None
        innings.is_completed = False

    db.commit()
    background_tasks.add_task(broadcast_match_update_task, id)
    return {"message": "Last ball rolled back successfully"}

@router.get("/{id}/live", response_model=LiveMatchState)
def get_live_match(id: UUID, db: Session = Depends(get_db)):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    # Get active innings
    active_num = get_active_innings_num(match, db)
    current_innings = db.query(Innings).filter(
        Innings.match_id == id,
        Innings.innings_number == active_num
    ).first()
    
    prev_innings = None
    if active_num == 2:
        prev_innings = db.query(Innings).filter(
            Innings.match_id == id,
            Innings.innings_number == 1
        ).first()

    # Compile striker, non-striker, bowler states
    striker_state = None
    non_striker_state = None
    bowler_state = None

    curr_dismissed_ids = []
    curr_last_bowler_id = None
    if current_innings:
        curr_dismissed_ids = [
            r[0] for r in db.query(Ball.player_dismissed_id)
            .filter(Ball.innings_id == current_innings.id, Ball.is_wicket == True, Ball.player_dismissed_id.isnot(None))
            .all()
        ]
        curr_last_ball = db.query(Ball).filter(Ball.innings_id == current_innings.id).order_by(Ball.ball_number.desc()).first()
        curr_last_bowler_id = curr_last_ball.bowler_id if curr_last_ball else None

    prev_dismissed_ids = []
    prev_last_bowler_id = None
    if prev_innings:
        prev_dismissed_ids = [
            r[0] for r in db.query(Ball.player_dismissed_id)
            .filter(Ball.innings_id == prev_innings.id, Ball.is_wicket == True, Ball.player_dismissed_id.isnot(None))
            .all()
        ]
        prev_last_ball = db.query(Ball).filter(Ball.innings_id == prev_innings.id).order_by(Ball.ball_number.desc()).first()
        prev_last_bowler_id = prev_last_ball.bowler_id if prev_last_ball else None

    def calculate_batsman_live_stats(player_id: UUID, name: str) -> StrikerState:
        balls = db.query(Ball).filter(
            Ball.innings_id == current_innings.id,
            Ball.batsman_id == player_id
        ).all()
        runs = sum(b.runs_batsman for b in balls)
        fours = sum(1 for b in balls if b.runs_batsman == 4)
        sixes = sum(1 for b in balls if b.runs_batsman == 6)
        legit_balls = sum(1 for b in balls if b.extra_type not in ["wide", "penalty"])
        sr = round((runs / legit_balls) * 100, 2) if legit_balls > 0 else 0.0
        return StrikerState(
            player_id=player_id,
            name=name,
            runs=runs,
            balls=legit_balls,
            fours=fours,
            sixes=sixes,
            strike_rate=sr
        )

    def calculate_bowler_live_stats(player_id: UUID, name: str) -> BowlerState:
        balls = db.query(Ball).filter(
            Ball.innings_id == current_innings.id,
            Ball.bowler_id == player_id
        ).all()
        
        runs_conceded = sum(b.runs_batsman + b.runs_extras for b in balls if b.extra_type in ["wide", "no_ball", "none"])
        wickets = sum(1 for b in balls if b.is_wicket and b.wicket_type not in ["run_out", "retired_hurt", "retired_out", "timed_out", "handled_ball", "none"])
        legit_balls = sum(1 for b in balls if b.extra_type not in ["wide", "no_ball", "penalty"])
        overs = float(f"{legit_balls // 6}.{legit_balls % 6}")
        
        # Economy
        overs_frac = legit_balls / 6.0
        econ = round(runs_conceded / overs_frac, 2) if overs_frac > 0 else 0.0
        
        # Calculate maidens
        # group balls by over number, if sum of runs in that over is 0 and legitimate balls count == 6
        maidens = 0
        overs_grouped = {}
        for b in balls:
            overs_grouped.setdefault(b.over_number, []).append(b)
        for over_no, over_balls in overs_grouped.items():
            legit_over_balls = [ob for ob in over_balls if ob.extra_type not in ["wide", "no_ball", "penalty"]]
            if len(legit_over_balls) == 6:
                over_runs = sum(ob.runs_batsman + ob.runs_extras for ob in over_balls if ob.extra_type in ["wide", "no_ball", "none"])
                if over_runs == 0:
                    maidens += 1

        return BowlerState(
            player_id=player_id,
            name=name,
            overs=overs,
            runs=runs_conceded,
            wickets=wickets,
            maidens=maidens,
            economy=econ
        )

    if current_innings:
        if match.current_striker_id:
            s_name = db.query(Player.name).filter(Player.id == match.current_striker_id).scalar() or "Striker"
            striker_state = calculate_batsman_live_stats(match.current_striker_id, s_name)
        if match.current_non_striker_id:
            ns_name = db.query(Player.name).filter(Player.id == match.current_non_striker_id).scalar() or "Non-Striker"
            non_striker_state = calculate_batsman_live_stats(match.current_non_striker_id, ns_name)
        if match.current_bowler_id:
            b_name = db.query(Player.name).filter(Player.id == match.current_bowler_id).scalar() or "Bowler"
            bowler_state = calculate_bowler_live_stats(match.current_bowler_id, b_name)

    # Compile recent balls ticker (all balls in chronological order with coordinates)
    recent_balls = []
    if current_innings:
        balls_logged = db.query(Ball).filter(
            Ball.innings_id == current_innings.id
        ).order_by(Ball.created_at.asc(), Ball.ball_number.asc()).all()
        
        legit_balls_in_over = {}
        for bl in balls_logged:
            over = bl.over_number
            legit_count = legit_balls_in_over.get(over, 0)
            coord = f"{over}.{legit_count + 1}"
            if bl.extra_type not in ["wide", "no_ball"]:
                legit_balls_in_over[over] = legit_count + 1
                
            label = str(bl.runs_batsman)
            if bl.is_wicket:
                label = "W"
            elif bl.extra_type == "wide":
                label = "WD"
            elif bl.extra_type == "no_ball":
                label = "NB"
            elif bl.extra_type == "bye":
                label = "B"
            elif bl.extra_type == "leg_bye":
                label = "LB"
                
            recent_balls.append(
                RecentBallSchema(
                    ball_label=label,
                    runs=bl.runs_batsman + bl.runs_extras,
                    extra_type=bl.extra_type,
                    is_wicket=bl.is_wicket,
                    over_ball_coord=coord,
                    over_number=over,
                    commentary=bl.commentary
                )
            )

    # Target calculation
    target = None
    if active_num == 2 and prev_innings:
        target = prev_innings.total_runs + 1

    # Metadata fields calculation
    tournament_name = match.tournament.name if match.tournament else None
    tournament_logo_url = match.tournament.banner_url if match.tournament else None
    toss_winner_name = match.toss_winner.name if match.toss_winner else None
    toss_decision = match.toss_decision
    team1_logo_url = match.team1.logo_url if match.team1 else None
    team2_logo_url = match.team2.logo_url if match.team2 else None

    # recent_overs calculation
    recent_overs = []
    if current_innings:
        all_balls = db.query(Ball).filter(Ball.innings_id == current_innings.id).order_by(Ball.ball_number.asc()).all()
        overs_map = {}
        for b in all_balls:
            overs_map.setdefault(b.over_number, {"runs": 0, "wickets": 0, "balls": 0})
            overs_map[b.over_number]["runs"] += (b.runs_batsman + b.runs_extras)
            if b.is_wicket:
                overs_map[b.over_number]["wickets"] += 1
            if b.extra_type not in ["wide", "no_ball"]:
                overs_map[b.over_number]["balls"] += 1
        
        for over_no in sorted(overs_map.keys()):
            recent_overs.append(
                OverSummarySchema(
                    over_number=over_no,
                    runs=overs_map[over_no]["runs"],
                    wickets=overs_map[over_no]["wickets"],
                    is_completed=overs_map[over_no]["balls"] >= 6
                )
            )

    # active_partnership calculation
    active_partnership = None
    if current_innings and match.current_striker_id and match.current_non_striker_id:
        rev_balls = db.query(Ball).filter(Ball.innings_id == current_innings.id).order_by(Ball.ball_number.desc()).all()
        active_pair = {match.current_striker_id, match.current_non_striker_id}
        
        p_runs = 0
        p_balls = 0
        p1_runs = 0
        p1_balls = 0
        p2_runs = 0
        p2_balls = 0
        
        for b in rev_balls:
            ball_pair = {b.batsman_id, b.non_striker_id}
            if not ball_pair.issubset(active_pair):
                break
            
            p_runs += (b.runs_batsman + b.runs_extras)
            if b.extra_type != "wide":
                p_balls += 1
                
            if b.batsman_id == match.current_striker_id:
                p1_runs += b.runs_batsman
                if b.extra_type != "wide":
                    p1_balls += 1
            elif b.batsman_id == match.current_non_striker_id:
                p2_runs += b.runs_batsman
                if b.extra_type != "wide":
                    p2_balls += 1
        
        striker_name = db.query(Player.name).filter(Player.id == match.current_striker_id).scalar() or "Striker"
        non_striker_name = db.query(Player.name).filter(Player.id == match.current_non_striker_id).scalar() or "Non-Striker"
        
        active_partnership = ActivePartnershipSchema(
            runs=p_runs,
            balls=p_balls,
            player1_id=match.current_striker_id,
            player1_name=striker_name,
            player1_runs=p1_runs,
            player1_balls=p1_balls,
            player2_id=match.current_non_striker_id,
            player2_name=non_striker_name,
            player2_runs=p2_runs,
            player2_balls=p2_balls
        )

    # striker_vs_bowler calculation
    striker_vs_bowler = None
    if current_innings and match.current_striker_id and match.current_bowler_id:
        vs_balls = db.query(Ball).filter(
            Ball.innings_id == current_innings.id,
            Ball.batsman_id == match.current_striker_id,
            Ball.bowler_id == match.current_bowler_id
        ).all()
        vs_runs = sum(b.runs_batsman for b in vs_balls)
        vs_legit_balls = sum(1 for b in vs_balls if b.extra_type != "wide")
        
        striker_vs_bowler = BatterBowlerStatsSchema(
            runs=vs_runs,
            balls=vs_legit_balls
        )

    return LiveMatchState(
        match_id=match.id,
        status=match.status,
        venue=match.venue,
        match_type=match.match_type,
        over_limit=match.over_limit,
        team1_name=match.team1.name,
        team2_name=match.team2.name,
        team1_id=match.team1_id,
        team2_id=match.team2_id,
        team1_squad_locked=match.team1_squad_locked,
        team2_squad_locked=match.team2_squad_locked,
        current_innings_number=active_num,
        target=target,
        created_by=match.created_by,
        assigned_scorer_id=match.assigned_scorer_id,
        tournament_organizer_id=match.tournament.organizer_id if match.tournament else None,
        
        tournament_name=tournament_name,
        tournament_logo_url=tournament_logo_url,
        tournament_stage=match.tournament_stage,
        match_number=match.match_number,
        toss_winner_name=toss_winner_name,
        toss_winner_id=match.toss_winner_id,
        toss_decision=toss_decision,
        team1_logo_url=team1_logo_url,
        team2_logo_url=team2_logo_url,
        umpire_name=match.umpire_name,
        scorer_name=match.scorer_name,
        
        striker=striker_state,
        non_striker=non_striker_state,
        bowler=bowler_state,
        current_innings=InningsSummarySchema(
            innings_number=current_innings.innings_number,
            batting_team_name=current_innings.batting_team.name,
            batting_team_id=current_innings.batting_team_id,
            bowling_team_id=current_innings.bowling_team_id,
            total_runs=current_innings.total_runs,
            total_wickets=current_innings.total_wickets,
            total_overs=current_innings.total_overs,
            extras_wides=current_innings.extras_wides,
            extras_noballs=current_innings.extras_noballs,
            extras_byes=current_innings.extras_byes,
            extras_legbyes=current_innings.extras_legbyes,
            extras_penalty=current_innings.extras_penalty,
            is_completed=current_innings.is_completed,
            dismissed_player_ids=curr_dismissed_ids,
            last_bowler_id=curr_last_bowler_id
        ) if current_innings else None,
        previous_innings=InningsSummarySchema(
            innings_number=prev_innings.innings_number,
            batting_team_name=prev_innings.batting_team.name,
            batting_team_id=prev_innings.batting_team_id,
            bowling_team_id=prev_innings.bowling_team_id,
            total_runs=prev_innings.total_runs,
            total_wickets=prev_innings.total_wickets,
            total_overs=prev_innings.total_overs,
            extras_wides=prev_innings.extras_wides,
            extras_noballs=prev_innings.extras_noballs,
            extras_byes=prev_innings.extras_byes,
            extras_legbyes=prev_innings.extras_legbyes,
            extras_penalty=prev_innings.extras_penalty,
            is_completed=prev_innings.is_completed,
            dismissed_player_ids=prev_dismissed_ids,
            last_bowler_id=prev_last_bowler_id
        ) if prev_innings else None,
        recent_balls=recent_balls,
        
        recent_overs=recent_overs,
        active_partnership=active_partnership,
        striker_vs_bowler=striker_vs_bowler,
    )

async def broadcast_match_update_task(match_id: UUID):
    db = SessionLocal()
    try:
        state = get_live_match(match_id, db)
        json_state = jsonable_encoder(state)
        await manager.broadcast(str(match_id), json_state)
    except Exception as e:
        print(f"Error broadcasting match update: {e}")
    finally:
        db.close()

@router.websocket("/{id}/live/ws")
async def websocket_endpoint(websocket: WebSocket, id: UUID):
    await manager.connect(str(id), websocket)
    db = SessionLocal()
    try:
        try:
            state = get_live_match(id, db)
            await websocket.send_json(jsonable_encoder(state))
        except Exception as e:
            print(f"Error sending initial live state: {e}")
        
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"WebSocket error for match {id}: {e}")
    finally:
        db.close()
        manager.disconnect(str(id), websocket)

from app.routers.players import update_player_stats
from app.schemas.match import (
    MatchScorecardResponse, MatchSummaryCardSchema, InningsScorecardSchema,
    BatsmanScorecardEntry, BowlerScorecardEntry, ExtrasBreakdownSchema,
    FallOfWicketEntry, PartnershipEntry, RecentBallSchema, PlayerOfTheMatchSchema,
    MatchSummaryStatsSchema
)

@router.get("/{id}/scorecard", response_model=MatchScorecardResponse)
def get_match_scorecard(id: UUID, db: Session = Depends(get_db)):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    # Fetch all players in this match's squads and update their career statistics
    squad_players = db.query(MatchSquad.player_id).filter(MatchSquad.match_id == id).all()
    for row in squad_players:
        update_player_stats(row.player_id, db)

    # 1. Compile Match Summary Info
    team1_name = match.team1.name
    team2_name = match.team2.name
    toss_winner_name = match.toss_winner.name if match.toss_winner else None
    toss_decision = match.toss_decision
    winner_name = match.winner.name if match.winner else None
    
    # Formulate win margin text
    win_margin_text = "Match in progress"
    if match.status == "completed":
        if winner_name:
            if match.win_margin_runs:
                win_margin_text = f"{winner_name} won by {match.win_margin_runs} runs"
            elif match.win_margin_wickets:
                win_margin_text = f"{winner_name} won by {match.win_margin_wickets} wickets"
            else:
                win_margin_text = f"{winner_name} won"
        else:
            win_margin_text = "Match Tied"
    elif match.status == "abandoned":
        win_margin_text = "Match Abandoned"
    elif match.status == "scheduled":
        win_margin_text = "Match Scheduled"
    elif match.status == "team_selection":
        win_margin_text = "Toss completed. Lineups being selected."
    elif toss_winner_name and toss_decision:
        win_margin_text = f"{toss_winner_name} won toss & elected to {toss_decision}"

    # Target calculation
    db_innings = db.query(Innings).filter(Innings.match_id == id).order_by(Innings.innings_number.asc()).all()
    target = None
    first_innings = next((i for i in db_innings if i.innings_number == 1), None)
    if first_innings:
        target = first_innings.total_runs + 1

    summary = MatchSummaryCardSchema(
        match_id=match.id,
        venue=match.venue,
        match_type=match.match_type,
        date=match.match_date,
        team1_name=team1_name,
        team2_name=team2_name,
        toss_winner_name=toss_winner_name,
        toss_decision=toss_decision,
        winner_name=winner_name,
        win_margin_runs=match.win_margin_runs,
        win_margin_wickets=match.win_margin_wickets,
        win_margin_text=win_margin_text,
        status=match.status,
        overs_limit=match.over_limit,
        tournament_name=match.tournament.name if match.tournament else None,
        target=target
    )

    # Fetch captain/wicketkeeper designations
    squad_configs = db.query(MatchSquad).filter(MatchSquad.match_id == id).all()
    squad_map = {s.player_id: (s.is_captain, s.is_wicketkeeper) for s in squad_configs}

    # 2. Process Innings Scorecards
    innings_list = []

    for innings in db_innings:
        batting_team_name = innings.batting_team.name
        
        # Query all balls in chronological order
        balls = db.query(Ball).filter(Ball.innings_id == innings.id).order_by(Ball.ball_number.asc()).all()

        # Group and calculate Batsmen entries
        # Maintain order of entry to crease
        batsmen_order = []
        seen_batsmen = set()
        for b in balls:
            if b.batsman_id not in seen_batsmen:
                seen_batsmen.add(b.batsman_id)
                batsmen_order.append(b.batsman_id)
            if b.non_striker_id not in seen_batsmen:
                seen_batsmen.add(b.non_striker_id)
                batsmen_order.append(b.non_striker_id)
            if b.player_dismissed_id and b.player_dismissed_id not in seen_batsmen:
                seen_batsmen.add(b.player_dismissed_id)
                batsmen_order.append(b.player_dismissed_id)

        # Map player names for lookup
        all_match_players = db.query(Player).filter(Player.id.in_(list(seen_batsmen))).all()
        players_name_map = {p.id: p.name for p in all_match_players}

        batting_entries = []
        for batsman_id in batsmen_order:
            batsman_balls = [b for b in balls if b.batsman_id == batsman_id]
            runs = sum(b.runs_batsman for b in batsman_balls)
            balls_faced = sum(1 for b in batsman_balls if b.extra_type not in ["wide", "penalty"])
            fours = sum(1 for b in batsman_balls if b.runs_batsman == 4)
            sixes = sum(1 for b in batsman_balls if b.runs_batsman == 6)
            sr = round((runs / balls_faced) * 100, 2) if balls_faced > 0 else 0.0

            # Find dismissal info
            dismissal_info = "not out"
            dismissal_ball = next((b for b in balls if b.is_wicket and b.player_dismissed_id == batsman_id), None)
            if dismissal_ball:
                w_type = dismissal_ball.wicket_type or "out"
                bowler_name = players_name_map.get(dismissal_ball.bowler_id, "Bowler")
                fielder_name = players_name_map.get(dismissal_ball.fielder_id, "Fielder") if dismissal_ball.fielder_id else None

                if w_type == "bowled":
                    dismissal_info = f"b {bowler_name}"
                elif w_type == "caught":
                    dismissal_info = f"c {fielder_name} b {bowler_name}" if fielder_name else f"c & b {bowler_name}"
                elif w_type == "lbw":
                    dismissal_info = f"lbw b {bowler_name}"
                elif w_type == "stumped":
                    dismissal_info = f"st {fielder_name} b {bowler_name}" if fielder_name else f"st b {bowler_name}"
                elif w_type == "run_out":
                    dismissal_info = f"run out ({fielder_name})" if fielder_name else "run out"
                elif w_type == "hit_wicket":
                    dismissal_info = f"hit wicket b {bowler_name}"
                elif w_type == "retired_hurt":
                    dismissal_info = "retired hurt"
                else:
                    dismissal_info = w_type

            is_cap, is_wk = squad_map.get(batsman_id, (False, False))
            batting_entries.append(
                BatsmanScorecardEntry(
                    name=players_name_map.get(batsman_id, "Unknown Batsman"),
                    runs=runs,
                    balls=balls_faced,
                    fours=fours,
                    sixes=sixes,
                    strike_rate=sr,
                    dismissal_info=dismissal_info,
                    is_captain=is_cap,
                    is_wicketkeeper=is_wk
                )
            )

        # Bowling scorecard calculation
        bowlers_order = []
        seen_bowlers = set()
        for b in balls:
            if b.bowler_id not in seen_bowlers:
                seen_bowlers.add(b.bowler_id)
                bowlers_order.append(b.bowler_id)

        all_bowlers = db.query(Player).filter(Player.id.in_(list(seen_bowlers))).all()
        bowlers_name_map = {p.id: p.name for p in all_bowlers}

        bowling_entries = []
        for bowler_id in bowlers_order:
            bowler_balls = [b for b in balls if b.bowler_id == bowler_id]
            runs_conceded = sum(b.runs_batsman + b.runs_extras for b in bowler_balls if b.extra_type in ["wide", "no_ball", "none"])
            wickets = sum(1 for b in bowler_balls if b.is_wicket and (b.wicket_type or "") not in ["run_out", "retired_hurt", "retired_out", "timed_out", "handled_ball", "none"])
            legit_balls = sum(1 for b in bowler_balls if b.extra_type not in ["wide", "no_ball", "penalty"])
            overs = float(f"{legit_balls // 6}.{legit_balls % 6}")
            econ = round(runs_conceded / (legit_balls / 6.0), 2) if legit_balls > 0 else 0.0

            # Calculate maidens
            maidens = 0
            overs_grouped = {}
            for b in bowler_balls:
                overs_grouped.setdefault(b.over_number, []).append(b)
            for over_no, over_balls in overs_grouped.items():
                legit_over_balls = [ob for ob in over_balls if ob.extra_type not in ["wide", "no_ball"]]
                if len(legit_over_balls) == 6:
                    over_runs = sum(ob.runs_batsman + ob.runs_extras for ob in over_balls if ob.extra_type in ["wide", "no_ball", "none"])
                    if over_runs == 0:
                        maidens += 1

            wides = sum(1 for b in bowler_balls if b.extra_type == "wide")
            no_balls = sum(1 for b in bowler_balls if b.extra_type == "no_ball")
            bowling_entries.append(
                BowlerScorecardEntry(
                    name=bowlers_name_map.get(bowler_id, "Unknown Bowler"),
                    overs=overs,
                    maidens=maidens,
                    runs_conceded=runs_conceded,
                    wickets=wickets,
                    economy=econ,
                    wides=wides,
                    no_balls=no_balls
                )
            )

        # Extras Breakdown
        wides = sum(b.runs_extras for b in balls if b.extra_type == "wide")
        noballs = sum(b.runs_extras for b in balls if b.extra_type == "no_ball")
        byes = sum(b.runs_extras for b in balls if b.extra_type == "bye")
        legbyes = sum(b.runs_extras for b in balls if b.extra_type == "leg_bye")
        penalties = sum(b.runs_extras for b in balls if b.extra_type == "penalty")
        total_extras = wides + noballs + byes + legbyes + penalties

        extras_schema = ExtrasBreakdownSchema(
            wides=wides,
            no_balls=noballs,
            byes=byes,
            leg_byes=legbyes,
            penalties=penalties,
            total=total_extras
        )

        # Fall of Wickets (FoW)
        fow_entries = []
        wkt_count = 0
        legit_balls_so_far = 0
        runs_so_far = 0
        
        for b in balls:
            runs_so_far += (b.runs_batsman + b.runs_extras)
            if b.extra_type not in ["wide", "no_ball"]:
                legit_balls_so_far += 1
                
            if b.is_wicket and b.player_dismissed_id:
                wkt_count += 1
                ov_ball = f"{legit_balls_so_far // 6}.{legit_balls_so_far % 6}"
                dismissed_name = db.query(Player.name).filter(Player.id == b.player_dismissed_id).scalar() or "Unknown"
                fow_entries.append(
                    FallOfWicketEntry(
                        score=f"{runs_so_far}/{wkt_count}",
                        player_name=dismissed_name,
                        over=ov_ball
                    )
                )

        # Partnerships Calculation
        partnerships_list = []
        if balls:
            current_p = {
                "player1_id": balls[0].batsman_id,
                "player2_id": balls[0].non_striker_id,
                "runs": 0,
                "balls": 0,
                "fours": 0,
                "sixes": 0
            }
            active_partners = {balls[0].batsman_id, balls[0].non_striker_id}

            for b in balls:
                ball_batsmen = {b.batsman_id, b.non_striker_id}
                if not ball_batsmen.issubset(active_partners):
                    # partnership has changed
                    if current_p["runs"] > 0 or current_p["balls"] > 0:
                        partnerships_list.append(current_p)
                    
                    survivor = list(active_partners.intersection(ball_batsmen))
                    new_batsman = list(ball_batsmen.difference(active_partners))
                    p1 = survivor[0] if survivor else b.batsman_id
                    p2 = new_batsman[0] if new_batsman else b.non_striker_id
                    
                    current_p = {
                        "player1_id": p1,
                        "player2_id": p2,
                        "runs": 0,
                        "balls": 0,
                        "fours": 0,
                        "sixes": 0
                    }
                    active_partners = {p1, p2}

                current_p["runs"] += (b.runs_batsman + b.runs_extras)
                if b.extra_type != "wide":
                    current_p["balls"] += 1
                if b.runs_batsman == 4:
                    current_p["fours"] += 1
                elif b.runs_batsman == 6:
                    current_p["sixes"] += 1

                if b.is_wicket and b.player_dismissed_id:
                    partnerships_list.append(current_p)
                    survivor = active_partners.difference({b.player_dismissed_id})
                    active_partners = survivor

            if current_p not in partnerships_list and (current_p["runs"] > 0 or current_p["balls"] > 0 or len(partnerships_list) == 0):
                partnerships_list.append(current_p)

            # Resolve names for partnerships
            p_ids = set()
            for p in partnerships_list:
                p_ids.add(p["player1_id"])
                p_ids.add(p["player2_id"])
            partners_map = {p.id: p.name for p in db.query(Player).filter(Player.id.in_(list(p_ids))).all()}
            
            resolved_partnerships = [
                PartnershipEntry(
                    player1_name=partners_map.get(p["player1_id"], "Unknown"),
                    player2_name=partners_map.get(p["player2_id"], "Unknown"),
                    runs=p["runs"],
                    balls=p["balls"],
                    fours=p.get("fours", 0),
                    sixes=p.get("sixes", 0)
                )
                for p in partnerships_list
            ]
        else:
            resolved_partnerships = []

        # Calculate run rate
        total_balls = (legit_balls_so_far // 6) * 6 + (legit_balls_so_far % 6)
        overs_frac = total_balls / 6.0
        run_rate = round(innings.total_runs / overs_frac, 2) if overs_frac > 0 else 0.0

        # Compile timeline entries
        timeline_entries = []
        legit_balls_in_over = {}
        for bl in balls:
            over = bl.over_number
            legit_count = legit_balls_in_over.get(over, 0)
            coord = f"{over}.{legit_count + 1}"
            if bl.extra_type not in ["wide", "no_ball"]:
                legit_balls_in_over[over] = legit_count + 1
                
            label = str(bl.runs_batsman)
            if bl.is_wicket:
                label = "W"
            elif bl.extra_type == "wide":
                label = "WD"
                if bl.runs_extras > 1:
                    label += f"+{bl.runs_extras - 1}"
            elif bl.extra_type == "no_ball":
                label = "NB"
                if bl.runs_batsman > 0:
                    label += f"+{bl.runs_batsman}"
                elif bl.runs_extras > 1:
                    label += f"+{bl.runs_extras - 1}"
            elif bl.extra_type == "bye":
                label = "B"
                if bl.runs_extras > 0:
                    label += f"+{bl.runs_extras}"
            elif bl.extra_type == "leg_bye":
                label = "LB"
                if bl.runs_extras > 0:
                    label += f"+{bl.runs_extras}"
            elif bl.runs_batsman == 0:
                label = "."

            timeline_entries.append(
                RecentBallSchema(
                    ball_label=label,
                    runs=bl.runs_batsman + bl.runs_extras,
                    extra_type=bl.extra_type,
                    is_wicket=bl.is_wicket,
                    over_ball_coord=coord,
                    over_number=over
                )
            )

        innings_list.append(
            InningsScorecardSchema(
                innings_number=innings.innings_number,
                batting_team_name=batting_team_name,
                total_runs=innings.total_runs,
                total_wickets=innings.total_wickets,
                total_overs=innings.total_overs,
                run_rate=run_rate,
                extras=extras_schema,
                batting=batting_entries,
                bowling=bowling_entries,
                fall_of_wickets=fow_entries,
                partnerships=resolved_partnerships,
                timeline=timeline_entries
            )
        )

    # 3. Calculate Player of the Match automatically
    player_of_the_match = None
    all_squads = db.query(MatchSquad).filter(MatchSquad.match_id == id).all()
    if all_squads:
        # Load all balls in the match
        match_balls = db.query(Ball).join(Innings).filter(Innings.match_id == id).all()
        
        player_stats = {}
        for sq in all_squads:
            player_stats[sq.player_id] = {
                "player": sq.player,
                "team_name": sq.team.name,
                "team_id": sq.team_id,
                "runs": 0,
                "balls": 0,
                "fours": 0,
                "sixes": 0,
                "balls_bowled": 0,
                "runs_conceded": 0,
                "wickets": 0,
                "maidens": 0,
                "catches": 0,
                "stumpings": 0,
                "run_outs": 0
            }
            
        for b in match_balls:
            # Batting
            if b.batsman_id in player_stats:
                player_stats[b.batsman_id]["runs"] += b.runs_batsman
                if b.extra_type not in ["wide", "penalty"]:
                    player_stats[b.batsman_id]["balls"] += 1
                if b.runs_batsman == 4:
                    player_stats[b.batsman_id]["fours"] += 1
                elif b.runs_batsman == 6:
                    player_stats[b.batsman_id]["sixes"] += 1
                    
            # Bowling
            if b.bowler_id in player_stats:
                if b.extra_type in ["wide", "no_ball", "none"]:
                    player_stats[b.bowler_id]["runs_conceded"] += (b.runs_batsman + b.runs_extras)
                if b.extra_type not in ["wide", "no_ball", "penalty"]:
                    player_stats[b.bowler_id]["balls_bowled"] += 1
                if b.is_wicket and (b.wicket_type or "") not in ["run_out", "retired_hurt", "retired_out", "timed_out", "handled_ball", "none"]:
                    player_stats[b.bowler_id]["wickets"] += 1
                    
            # Fielding
            if b.is_wicket and b.fielder_id in player_stats:
                if b.wicket_type == "caught":
                    player_stats[b.fielder_id]["catches"] += 1
                elif b.wicket_type == "stumped":
                    player_stats[b.fielder_id]["stumpings"] += 1
                elif b.wicket_type == "run_out":
                    player_stats[b.fielder_id]["run_outs"] += 1

        # Calculate maidens, points
        for pid, st in player_stats.items():
            runs = st["runs"]
            fours = st["fours"]
            sixes = st["sixes"]
            wickets = st["wickets"]
            runs_conceded = st["runs_conceded"]
            balls_bowled = st["balls_bowled"]
            catches = st["catches"]
            stumpings = st["stumpings"]
            run_outs = st["run_outs"]
            
            # Batting points
            bat_pts = runs + fours * 1 + sixes * 2
            if runs >= 100:
                bat_pts += 20
            elif runs >= 50:
                bat_pts += 10
            elif runs >= 30:
                bat_pts += 5
                
            # Bowling points
            bowl_pts = wickets * 25
            if wickets >= 5:
                bowl_pts += 20
            elif wickets >= 3:
                bowl_pts += 10
                
            # Maiden calculation
            maidens = 0
            bowler_balls = [b for b in match_balls if b.bowler_id == pid]
            overs_grouped = {}
            for b in bowler_balls:
                overs_grouped.setdefault(b.over_number, []).append(b)
            for over_no, over_balls in overs_grouped.items():
                legit_over_balls = [ob for ob in over_balls if ob.extra_type not in ["wide", "no_ball"]]
                if len(legit_over_balls) == 6:
                    over_runs = sum(ob.runs_batsman + ob.runs_extras for ob in over_balls if ob.extra_type in ["wide", "no_ball", "none"])
                    if over_runs == 0:
                        maidens += 1
            st["maidens"] = maidens
            bowl_pts += maidens * 8
            
            # Fielding points
            field_pts = catches * 8 + stumpings * 12 + run_outs * 8
            
            total_pts = bat_pts + bowl_pts + field_pts
            st["points"] = total_pts

        # Filter by winning team if completed
        winner_team_id = match.winner_id
        candidates = [pid for pid, st in player_stats.items() if st["team_id"] == winner_team_id] if winner_team_id else []
        if not candidates:
            candidates = list(player_stats.keys())
            
        if candidates:
            best_pid = max(candidates, key=lambda pid: player_stats[pid]["points"])
            best_st = player_stats[best_pid]
            
            reason_parts = []
            if best_st["runs"] > 0:
                reason_parts.append(f"{best_st['runs']} ({best_st['balls']})")
            if best_st["wickets"] > 0:
                ovs = float(f"{best_st['balls_bowled'] // 6}.{best_st['balls_bowled'] % 6}")
                reason_parts.append(f"{best_st['wickets']}/{best_st['runs_conceded']} ({ovs} ov)")
            if best_st["catches"] > 0 or best_st["stumpings"] > 0 or best_st["run_outs"] > 0:
                fld = []
                if best_st["catches"] > 0:
                    fld.append(f"{best_st['catches']} ct")
                if best_st["stumpings"] > 0:
                    fld.append(f"{best_st['stumpings']} st")
                if best_st["run_outs"] > 0:
                    fld.append(f"{best_st['run_outs']} ro")
                reason_parts.append(", ".join(fld))
                
            reason = " & ".join(reason_parts) if reason_parts else "Impact Player"
            
            overs = float(f"{best_st['balls_bowled'] // 6}.{best_st['balls_bowled'] % 6}")
            economy = round(best_st["runs_conceded"] / (best_st["balls_bowled"] / 6.0), 2) if best_st["balls_bowled"] > 0 else 0.0
            
            player_of_the_match = PlayerOfTheMatchSchema(
                player_id=best_pid,
                name=best_st["player"].name,
                team_name=best_st["team_name"],
                reason=reason,
                runs=best_st["runs"],
                balls=best_st["balls"],
                wickets=best_st["wickets"],
                runs_conceded=best_st["runs_conceded"],
                overs=overs,
                economy=economy,
                catches=best_st["catches"],
                stumpings=best_st["stumpings"],
                run_outs=best_st["run_outs"],
                photo_url=f"/api/v1/profile/photo/{best_pid}"
            )

    # 4. Compile Match Summary Stats
    match_summary_stats = None
    if db_innings:
        second_innings = next((i for i in db_innings if i.innings_number == 2), None)
        achieved_runs = second_innings.total_runs if second_innings else None
        achieved_wickets = second_innings.total_wickets if second_innings else None
        achieved_overs = second_innings.total_overs if second_innings else None

        overall_top_batsman = None
        for innings_data in innings_list:
            for bat in innings_data.batting:
                if overall_top_batsman is None or bat.runs > overall_top_batsman.runs:
                    overall_top_batsman = bat

        overall_best_bowler = None
        for innings_data in innings_list:
            for bowl in innings_data.bowling:
                if overall_best_bowler is None:
                    overall_best_bowler = bowl
                else:
                    if bowl.wickets > overall_best_bowler.wickets:
                        overall_best_bowler = bowl
                    elif bowl.wickets == overall_best_bowler.wickets:
                        if bowl.runs_conceded < overall_best_bowler.runs_conceded:
                            overall_best_bowler = bowl
                        elif bowl.runs_conceded == overall_best_bowler.runs_conceded:
                            if bowl.economy < overall_best_bowler.economy:
                                overall_best_bowler = bowl

        overall_best_partnership = None
        for innings_data in innings_list:
            for part in innings_data.partnerships:
                if overall_best_partnership is None or part.runs > overall_best_partnership.runs:
                    overall_best_partnership = part

        # Calculate match duration
        all_balls = db.query(Ball).join(Innings).filter(Innings.match_id == match.id).order_by(Ball.created_at.asc()).all()
        match_duration = None
        if all_balls:
            first_ball = all_balls[0]
            last_ball = all_balls[-1]
            diff = last_ball.created_at - first_ball.created_at
            total_mins = int(diff.total_seconds() / 60)
            if total_mins < 1:
                match_duration = "10 mins"
            elif total_mins < 60:
                match_duration = f"{total_mins} mins"
            else:
                match_duration = f"{total_mins // 60}h {total_mins % 60}m"
        else:
            match_duration = "15 mins"

        # Calculate winning shot
        winning_shot = None
        if match.status == 'completed' and second_innings:
            sec_balls = [b for b in all_balls if b.innings_id == second_innings.id]
            if sec_balls:
                w_ball = sec_balls[-1]
                striker_name = db.query(Player.name).filter(Player.id == w_ball.batsman_id).scalar() or "Batsman"
                bowler_name = db.query(Player.name).filter(Player.id == w_ball.bowler_id).scalar() or "Bowler"
                if target and second_innings.total_runs >= target:
                    if w_ball.runs_batsman == 4:
                        winning_shot = f"{striker_name} hit a FOUR to seal the victory!"
                    elif w_ball.runs_batsman == 6:
                        winning_shot = f"{striker_name} smashed a SIX to win the match!"
                    elif w_ball.runs_batsman == 1:
                        winning_shot = f"{striker_name} took a single to win the match!"
                    elif w_ball.extra_type in ["wide", "no_ball"]:
                        winning_shot = f"Match won via extra ({w_ball.extra_type.upper()}) delivered by {bowler_name}."
                    else:
                        winning_shot = f"{striker_name} scored {w_ball.runs_batsman} run(s) to win!"
                else:
                    if w_ball.is_wicket:
                        winning_shot = f"{bowler_name} took a wicket on the final ball to win!"
                    else:
                        winning_shot = f"{bowler_name} delivered a dot ball on the final delivery to defend the total."
        
        if not winning_shot:
            winning_shot = win_margin_text

        match_summary_stats = MatchSummaryStatsSchema(
            result_text=win_margin_text,
            target=target,
            achieved_runs=achieved_runs,
            achieved_wickets=achieved_wickets,
            achieved_overs=achieved_overs,
            top_scorer_name=overall_top_batsman.name if overall_top_batsman else None,
            top_scorer_runs=overall_top_batsman.runs if overall_top_batsman else None,
            top_scorer_balls=overall_top_batsman.balls if overall_top_batsman else None,
            best_bowler_name=overall_best_bowler.name if overall_best_bowler else None,
            best_bowler_wickets=overall_best_bowler.wickets if overall_best_bowler else None,
            best_bowler_runs=overall_best_bowler.runs_conceded if overall_best_bowler else None,
            highest_partnership_runs=overall_best_partnership.runs if overall_best_partnership else None,
            highest_partnership_players=f"{overall_best_partnership.player1_name} & {overall_best_partnership.player2_name}" if overall_best_partnership else None,
            winning_shot=winning_shot,
            match_duration=match_duration
        )

    return MatchScorecardResponse(
        match_summary=summary,
        innings=innings_list,
        player_of_the_match=player_of_the_match,
        match_summary_stats=match_summary_stats
    )

@router.put("/{id}", response_model=MatchResponse)
def update_match(
    id: UUID,
    match_in: MatchUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    is_authorized = (
        match.created_by == current_user.id or
        current_user.role == "admin" or
        (match.tournament and match.tournament.organizer_id == current_user.id)
    )
    if not is_authorized:
        raise HTTPException(status_code=403, detail="Not authorized to edit this match")

    update_data = match_in.model_dump(exclude_unset=True)
    
    status_changed = False
    if "status" in update_data and update_data["status"] != match.status:
        status_changed = True

    for field, value in update_data.items():
        setattr(match, field, value)

    check_and_update_match_ready(match, db)
    db.add(match)
    db.commit()
    db.refresh(match)

    if status_changed and match.status == "abandoned" and match.tournament_id:
        from app.routers.tournaments import check_and_progress_tournament
        check_and_progress_tournament(match.tournament_id, db)

    return match

@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_match(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    is_authorized = (
        match.created_by == current_user.id or
        current_user.role == "admin" or
        (match.tournament and match.tournament.organizer_id == current_user.id)
    )
    if not is_authorized:
        raise HTTPException(status_code=403, detail="Not authorized to delete this match")

    if match.tournament_id and match.tournament.status == "ongoing":
        raise HTTPException(status_code=400, detail="Cannot delete fixtures after they are published")

    db.delete(match)
    db.commit()
    return None


