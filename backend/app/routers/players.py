from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_
from uuid import UUID

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.cricket import Player, Ball, MatchSquad, Match
from app.schemas.player import PlayerCreate, PlayerResponse, PlayerUpdate

router = APIRouter()

@router.post("/", response_model=PlayerResponse, status_code=status.HTTP_201_CREATED)
def create_player(
    player_in: PlayerCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    # If user_id is provided, verify it exists. Else default to None.
    if player_in.user_id:
        user_exists = db.query(User).filter(User.id == player_in.user_id).first()
        if not user_exists:
            raise HTTPException(status_code=404, detail="User not found")
            
    db_player = Player(
        user_id=player_in.user_id,
        name=player_in.name,
        role=player_in.role,
        batting_style=player_in.batting_style,
        bowling_style=player_in.bowling_style,
        profile_photo_url=player_in.profile_photo_url,
        jersey_number=player_in.jersey_number,
        created_by=current_user.id
    )
    db.add(db_player)
    db.commit()
    db.refresh(db_player)
    return db_player

@router.get("/", response_model=List[PlayerResponse])
def list_players(
    search: Optional[str] = Query(None, description="Search player by name"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Player).filter(Player.created_by == current_user.id)
    if search:
        query = query.filter(Player.name.ilike(f"%{search}%"))
    return query.limit(50).all()

@router.get("/{id}", response_model=PlayerResponse)
def get_player(id: UUID, db: Session = Depends(get_db)):
    player = db.query(Player).filter(Player.id == id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")
    return player

@router.get("/{id}/stats")
def get_player_stats(id: UUID, db: Session = Depends(get_db)):
    player = db.query(Player).filter(Player.id == id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")

    # BATTING STATS CALCULATION
    # Total Matches played where the player was in the squad
    matches_played = db.query(func.count(func.distinct(MatchSquad.match_id))).filter(
        MatchSquad.player_id == id
    ).scalar() or 0

    # Batting innings: matches where the player faced at least 1 ball or was dismissed
    batting_innings = db.query(func.count(func.distinct(Ball.innings_id))).filter(
        or_(
            Ball.batsman_id == id,
            and_(Ball.is_wicket == True, Ball.player_dismissed_id == id)
        )
    ).scalar() or 0

    # Total Runs
    total_runs = db.query(func.sum(Ball.runs_batsman)).filter(
        Ball.batsman_id == id
    ).scalar() or 0

    # Balls faced (exclude wides because striker doesn't face a wide ball)
    balls_faced = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.batsman_id == id,
            Ball.extra_type != "wide"
        )
    ).scalar() or 0

    # Fours & Sixes
    fours = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.batsman_id == id,
            Ball.runs_batsman == 4
        )
    ).scalar() or 0

    sixes = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.batsman_id == id,
            Ball.runs_batsman == 6
        )
    ).scalar() or 0

    # Outs
    outs = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.is_wicket == True,
            Ball.player_dismissed_id == id,
            # Retired hurt is not an out
            Ball.wicket_type != "retired_hurt"
        )
    ).scalar() or 0

    batting_average = round(total_runs / outs, 2) if outs > 0 else (float(total_runs) if batting_innings > 0 else 0.0)
    strike_rate = round((total_runs / balls_faced) * 100, 2) if balls_faced > 0 else 0.0

    # High Score calculation
    # Group runs by innings
    high_score = db.query(func.sum(Ball.runs_batsman).label("innings_runs")).filter(
        Ball.batsman_id == id
    ).group_by(Ball.innings_id).order_by(func.sum(Ball.runs_batsman).desc()).first()
    
    high_score_val = high_score[0] if high_score else 0

    # BOWLING STATS CALCULATION
    # Bowling innings: matches where they bowled at least one ball
    bowling_innings = db.query(func.count(func.distinct(Ball.innings_id))).filter(
        Ball.bowler_id == id
    ).scalar() or 0

    # Legitimate balls (exclude wides & no balls)
    legit_balls = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.bowler_id == id,
            ~Ball.extra_type.in_(["wide", "no_ball"])
        )
    ).scalar() or 0

    overs_bowled = float(f"{legit_balls // 6}.{legit_balls % 6}")

    # Runs conceded: batsman runs + wides + no_balls (byes and legbyes are not conceded by bowler)
    runs_conceded = db.query(func.sum(Ball.runs_batsman + Ball.runs_extras)).filter(
        and_(
            Ball.bowler_id == id,
            Ball.extra_type.in_(["wide", "no_ball", "none"])
        )
    ).scalar() or 0

    # Wickets credited to bowler (exclude run outs, retired hurts)
    wickets = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.bowler_id == id,
            Ball.is_wicket == True,
            ~Ball.wicket_type.in_(["run_out", "retired_hurt", "none"])
        )
    ).scalar() or 0

    bowling_average = round(runs_conceded / wickets, 2) if wickets > 0 else (float(runs_conceded) if bowling_innings > 0 else 0.0)
    
    # Economy
    overs_fraction = legit_balls / 6.0
    bowling_economy = round(runs_conceded / overs_fraction, 2) if overs_fraction > 0 else 0.0

    # 5-wicket hauls
    # count matches where wickets >= 5
    five_wkt_hauls = 0
    match_wickets = db.query(func.count(Ball.id).label("wkts")).filter(
        and_(
            Ball.bowler_id == id,
            Ball.is_wicket == True,
            ~Ball.wicket_type.in_(["run_out", "retired_hurt"])
        )
    ).group_by(Ball.innings_id).all()
    for mw in match_wickets:
        if mw.wkts >= 5:
            five_wkt_hauls += 1

    return {
        "player_id": str(id),
        "name": player.name,
        "role": player.role,
        "batting": {
            "matches": matches_played,
            "innings": batting_innings,
            "runs": total_runs,
            "balls_faced": balls_faced,
            "average": batting_average,
            "strike_rate": strike_rate,
            "high_score": high_score_val,
            "fours": fours,
            "sixes": sixes,
            "outs": outs
        },
        "bowling": {
            "matches": matches_played,
            "innings": bowling_innings,
            "overs": overs_bowled,
            "runs_conceded": runs_conceded,
            "wickets": wickets,
            "average": bowling_average,
            "economy": bowling_economy,
            "five_wickets": five_wkt_hauls
        }
    }

def update_player_stats(player_id: UUID, db: Session):
    player = db.query(Player).filter(Player.id == player_id).first()
    if not player:
        return

    # Total Matches played where the player was in the squad
    matches_played = db.query(func.count(func.distinct(MatchSquad.match_id))).filter(
        MatchSquad.player_id == player_id
    ).scalar() or 0

    # Total Runs
    total_runs = db.query(func.sum(Ball.runs_batsman)).filter(
        Ball.batsman_id == player_id
    ).scalar() or 0

    # Balls faced (exclude wides because striker doesn't face a wide ball)
    balls_faced = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.batsman_id == player_id,
            Ball.extra_type != "wide"
        )
    ).scalar() or 0

    # Outs
    outs = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.is_wicket == True,
            Ball.player_dismissed_id == player_id,
            Ball.wicket_type != "retired_hurt"
        )
    ).scalar() or 0

    batting_average = round(total_runs / outs, 2) if outs > 0 else (float(total_runs) if balls_faced > 0 else 0.0)
    strike_rate = round((total_runs / balls_faced) * 100, 2) if balls_faced > 0 else 0.0

    # High Score calculation
    high_score = db.query(func.sum(Ball.runs_batsman).label("innings_runs")).filter(
        Ball.batsman_id == player_id
    ).group_by(Ball.innings_id).order_by(func.sum(Ball.runs_batsman).desc()).first()
    
    high_score_val = high_score[0] if high_score else 0

    # Bowling stats:
    # Wickets credited to bowler (exclude run outs, retired hurts)
    wickets = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.bowler_id == player_id,
            Ball.is_wicket == True,
            ~Ball.wicket_type.in_(["run_out", "retired_hurt", "none"])
        )
    ).scalar() or 0

    # Legitimate balls (exclude wides & no balls)
    legit_balls = db.query(func.count(Ball.id)).filter(
        and_(
            Ball.bowler_id == player_id,
            ~Ball.extra_type.in_(["wide", "no_ball"])
        )
    ).scalar() or 0

    # Runs conceded
    runs_conceded = db.query(func.sum(Ball.runs_batsman + Ball.runs_extras)).filter(
        and_(
            Ball.bowler_id == player_id,
            Ball.extra_type.in_(["wide", "no_ball", "none"])
        )
    ).scalar() or 0

    overs_fraction = legit_balls / 6.0
    economy = round(runs_conceded / overs_fraction, 2) if overs_fraction > 0 else 0.0

    # Best bowling figures (wickets/runs)
    subquery_wkts = db.query(
        Ball.innings_id,
        func.count(Ball.id).label("wkts")
    ).filter(
        and_(
            Ball.bowler_id == player_id,
            Ball.is_wicket == True,
            ~Ball.wicket_type.in_(["run_out", "retired_hurt", "none"])
        )
    ).group_by(Ball.innings_id).subquery()

    subquery_runs = db.query(
        Ball.innings_id,
        func.sum(Ball.runs_batsman + Ball.runs_extras).label("runs")
    ).filter(
        and_(
            Ball.bowler_id == player_id,
            Ball.extra_type.in_(["wide", "no_ball", "none"])
        )
    ).group_by(Ball.innings_id).subquery()

    bowler_innings = db.query(
        Ball.innings_id,
        func.coalesce(subquery_wkts.c.wkts, 0).label("wkts"),
        func.coalesce(subquery_runs.c.runs, 0).label("runs")
    ).outerjoin(subquery_wkts, Ball.innings_id == subquery_wkts.c.innings_id)\
     .outerjoin(subquery_runs, Ball.innings_id == subquery_runs.c.innings_id)\
     .filter(Ball.bowler_id == player_id)\
     .distinct().all()

    best_w = 0
    best_r = 999
    best_fig_str = "0/0"
    
    for row in bowler_innings:
        w = row.wkts
        r = row.runs
        if w > best_w:
            best_w = w
            best_r = r
            best_fig_str = f"{w}/{r}"
        elif w == best_w and w > 0:
            if r < best_r:
                best_r = r
                best_fig_str = f"{w}/{r}"
        elif w == 0 and best_w == 0:
            if r < best_r:
                best_r = r
                best_fig_str = f"0/{r}"

    if best_w == 0 and best_r == 999:
        best_fig_str = "0/0"

    player.career_runs = total_runs
    player.career_wickets = wickets
    player.matches_played = matches_played
    player.batting_average = batting_average
    player.strike_rate = strike_rate
    player.economy = economy
    player.highest_score = high_score_val
    player.best_bowling_figures = best_fig_str

    db.add(player)
    db.commit()


@router.put("/{id}", response_model=PlayerResponse)
def update_player(
    id: UUID,
    player_in: PlayerUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    player = db.query(Player).filter(Player.id == id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")

    if player.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this player")

    # Update fields if provided
    update_data = player_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(player, field, value)

    db.add(player)
    db.commit()
    db.refresh(player)
    return player


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_player(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    player = db.query(Player).filter(Player.id == id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")

    if player.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this player")

    # Prevent deletion if player is in an active (non-completed/non-abandoned) match squad
    active_match = db.query(Match).join(MatchSquad).filter(
        MatchSquad.player_id == id,
        ~Match.status.in_(["completed", "abandoned"])
    ).first()
    if active_match:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete player because they are part of an active match squad: {active_match.team1.name} vs {active_match.team2.name}."
        )

    db.delete(player)
    db.commit()
    return None
