from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
import os
import shutil
import uuid
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from uuid import UUID

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User, UserActivity, UserAchievement
from app.models.cricket import Player, MatchSquad, Ball, TournamentTeam, Tournament, Match
from app.schemas.profile import (
    ProfileResponse,
    ProfileUpdate,
    CareerStatsResponse,
    BattingStats,
    BowlingStats,
    FieldingStats,
    TournamentStats,
    UserActivityResponse,
    UserAchievementResponse
)

router = APIRouter()

def log_user_activity(db: Session, user_id: UUID, activity_type: str, description: str):
    activity = UserActivity(
        user_id=user_id,
        activity_type=activity_type,
        description=description,
        created_at=datetime.now(timezone.utc)
    )
    db.add(activity)
    try:
        db.commit()
    except Exception:
        db.rollback()

def check_and_unlock_achievements(db: Session, user_id: UUID):
    # Fetch player details
    player = db.query(Player).filter(Player.user_id == user_id).first()
    if not player:
        return

    # 1. Matches played
    matches_played = db.query(MatchSquad).filter(MatchSquad.player_id == player.id, MatchSquad.is_playing_xi == True).count()
    if player.matches_played:
        matches_played += player.matches_played

    # 2. Runs / Fifties / Hundreds
    innings_runs = db.query(
        Ball.innings_id,
        func.sum(Ball.runs_batsman).label("runs")
    ).filter(Ball.batsman_id == player.id).group_by(Ball.innings_id).all()
    max_runs = max([r.runs for r in innings_runs]) if innings_runs else 0
    if player.highest_score and player.highest_score > max_runs:
        max_runs = player.highest_score

    # 3. Wickets
    wickets = db.query(Ball).filter(
        Ball.bowler_id == player.id,
        Ball.is_wicket == True,
        Ball.wicket_type.in_(["bowled", "caught", "lbw", "stumped", "hit_wicket"])
    ).count()
    if player.career_wickets:
        wickets += player.career_wickets

    # Tournaments won
    team_ids = [t.id for t in player.teams]
    tournaments_won = db.query(Tournament).filter(Tournament.winner_id.in_(team_ids)).count() if team_ids else 0

    def unlock(ach_type: str):
        existing = db.query(UserAchievement).filter(
            UserAchievement.user_id == user_id,
            UserAchievement.achievement_type == ach_type
        ).first()
        if not existing:
            existing = UserAchievement(
                user_id=user_id,
                achievement_type=ach_type,
                is_unlocked=True,
                unlocked_at=datetime.now(timezone.utc)
            )
            db.add(existing)
            db.commit()
            log_user_activity(
                db,
                user_id,
                "achievement_unlocked",
                f"Unlocked Achievement: {ach_type.replace('_', ' ').title()}!"
            )
        elif not existing.is_unlocked:
            existing.is_unlocked = True
            existing.unlocked_at = datetime.now(timezone.utc)
            db.add(existing)
            db.commit()
            log_user_activity(
                db,
                user_id,
                "achievement_unlocked",
                f"Unlocked Achievement: {ach_type.replace('_', ' ').title()}!"
            )

    if matches_played >= 1:
        unlock("first_match")
    if max_runs >= 50:
        unlock("first_fifty")
    if max_runs >= 100:
        unlock("first_century")
    if wickets >= 1:
        unlock("first_wicket")
    if tournaments_won >= 1:
        unlock("tournament_winner")


@router.get("/", response_model=ProfileResponse)
def get_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not current_user.joined_at:
        current_user.joined_at = current_user.created_at or datetime.now(timezone.utc)
        db.add(current_user)
        db.commit()
        db.refresh(current_user)
    return current_user


@router.put("/", response_model=ProfileResponse)
def update_profile(
    profile_in: ProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if profile_in.username is not None and profile_in.username != current_user.username:
        existing_user = db.query(User).filter(User.username == profile_in.username).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Username is already taken")
        current_user.username = profile_in.username

    if profile_in.full_name is not None:
        current_user.full_name = profile_in.full_name
        if not current_user.display_name:
            current_user.display_name = profile_in.full_name

    if profile_in.bio is not None:
        current_user.bio = profile_in.bio

    if profile_in.profile_picture is not None:
        current_user.profile_picture = profile_in.profile_picture

    if profile_in.profile_photo_url is not None:
        current_user.profile_photo_url = profile_in.profile_photo_url

    db.add(current_user)
    
    # Sync to Player model if linked
    player = db.query(Player).filter(Player.user_id == current_user.id).first()
    if player:
        if profile_in.full_name is not None:
            player.name = profile_in.full_name
        if profile_in.profile_photo_url is not None:
            player.profile_photo_url = profile_in.profile_photo_url
        db.add(player)

    db.commit()
    db.refresh(current_user)

    log_user_activity(db, current_user.id, "profile_update", "Updated profile information.")
    return current_user


@router.get("/stats", response_model=CareerStatsResponse)
def get_profile_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    player = db.query(Player).filter(Player.user_id == current_user.id).first()
    
    # Initialize empty response structure
    batting = BattingStats()
    bowling = BowlingStats()
    fielding = FieldingStats()
    tournament = TournamentStats()

    if not player:
        # User has no linked player profile. Return zero stats.
        return CareerStatsResponse(
            batting=batting,
            bowling=bowling,
            fielding=fielding,
            tournament=tournament
        )

    # 1. Batting Statistics
    baseline_runs = player.career_runs or 0
    baseline_wickets = player.career_wickets or 0
    baseline_matches = player.matches_played or 0

    # Matches played
    m_played = db.query(MatchSquad).filter(MatchSquad.player_id == player.id, MatchSquad.is_playing_xi == True).count()
    batting.matches_played = m_played + baseline_matches

    # Balls faced
    balls_faced = db.query(Ball).filter(Ball.batsman_id == player.id, Ball.extra_type != "wide").count()

    # Innings batted
    batting.innings = db.query(Ball.innings_id).filter(
        or_(Ball.batsman_id == player.id, Ball.player_dismissed_id == player.id)
    ).distinct().count()

    # Runs
    runs_scored = db.query(func.sum(Ball.runs_batsman)).filter(Ball.batsman_id == player.id).scalar() or 0
    batting.runs = runs_scored + baseline_runs

    # Fours & Sixes
    batting.fours = db.query(Ball).filter(Ball.batsman_id == player.id, Ball.runs_batsman == 4).count()
    batting.sixes = db.query(Ball).filter(Ball.batsman_id == player.id, Ball.runs_batsman == 6).count()

    # Highest score
    innings_runs = db.query(
        Ball.innings_id,
        func.sum(Ball.runs_batsman).label("runs")
    ).filter(Ball.batsman_id == player.id).group_by(Ball.innings_id).all()
    max_runs = max([r.runs for r in innings_runs]) if innings_runs else 0
    batting.highest_score = max(max_runs, player.highest_score or 0)

    # Fifties and Hundreds
    batting.fifties = sum(1 for r in innings_runs if 50 <= r.runs < 100)
    batting.hundreds = sum(1 for r in innings_runs if r.runs >= 100)

    # Average
    dismissed = db.query(Ball).filter(Ball.player_dismissed_id == player.id).count()
    if dismissed > 0:
        batting.average = round(batting.runs / dismissed, 2)
    else:
        batting.average = float(batting.runs)

    # Strike rate
    if balls_faced > 0:
        batting.strike_rate = round((batting.runs / balls_faced) * 100, 2)
    elif player.strike_rate:
        batting.strike_rate = player.strike_rate

    # 2. Bowling Statistics
    # Wickets
    wkt = db.query(Ball).filter(
        Ball.bowler_id == player.id,
        Ball.is_wicket == True,
        Ball.wicket_type.in_(["bowled", "caught", "lbw", "stumped", "hit_wicket"])
    ).count()
    bowling.wickets = wkt + baseline_wickets

    # Balls bowled
    balls_bowled = db.query(Ball).filter(Ball.bowler_id == player.id, ~Ball.extra_type.in_(["wide", "no_ball"])).count()
    raw_overs = balls_bowled / 6.0
    bowling.overs_bowled = round((balls_bowled // 6) + (balls_bowled % 6) / 10.0, 1)

    # Conceded runs
    conceded_balls = db.query(Ball).filter(Ball.bowler_id == player.id).all()
    runs_conceded = 0
    for b in conceded_balls:
        if b.extra_type in ["wide", "no_ball"]:
            runs_conceded += (b.runs_batsman or 0) + (b.runs_extras or 0)
        else:
            runs_conceded += (b.runs_batsman or 0)

    if raw_overs > 0:
        bowling.economy = round(runs_conceded / raw_overs, 2)
    elif player.economy:
        bowling.economy = player.economy

    # Best figures
    innings_bowling = {}
    for b in conceded_balls:
        in_id = b.innings_id
        if in_id not in innings_bowling:
            innings_bowling[in_id] = {"wickets": 0, "runs": 0}
        
        is_wk = b.is_wicket and b.wicket_type in ["bowled", "caught", "lbw", "stumped", "hit_wicket"]
        if is_wk:
            innings_bowling[in_id]["wickets"] += 1
            
        if b.extra_type in ["wide", "no_ball"]:
            innings_bowling[in_id]["runs"] += (b.runs_batsman or 0) + (b.runs_extras or 0)
        else:
            innings_bowling[in_id]["runs"] += (b.runs_batsman or 0)
            
    best_fig = "0/0"
    best_wk = -1
    best_runs = 9999
    for in_id, stat in innings_bowling.items():
        wk = stat["wickets"]
        r = stat["runs"]
        if wk > best_wk or (wk == best_wk and r < best_runs):
            best_wk = wk
            best_runs = r
            best_fig = f"{wk}/{r}"
    if best_wk != -1:
        bowling.best_bowling_figures = best_fig
    else:
        bowling.best_bowling_figures = player.best_bowling_figures or "0/0"

    # Maidens
    over_groups = {}
    for b in conceded_balls:
        key = (b.innings_id, b.over_number)
        if key not in over_groups:
            over_groups[key] = []
        over_groups[key].append(b)
    
    for key, balls_in_over in over_groups.items():
        legal_balls = sum(1 for b in balls_in_over if b.extra_type not in ["wide", "no_ball"])
        if legal_balls >= 6:
            runs_in_over = 0
            for b in balls_in_over:
                if b.extra_type in ["wide", "no_ball"]:
                    runs_in_over += (b.runs_batsman or 0) + (b.runs_extras or 0)
                else:
                    runs_in_over += (b.runs_batsman or 0)
            if runs_in_over == 0:
                bowling.maidens += 1

    # 3. Fielding Statistics
    fielding.catches = db.query(Ball).filter(Ball.fielder_id == player.id, Ball.wicket_type == "caught").count()
    fielding.stumpings = db.query(Ball).filter(Ball.fielder_id == player.id, Ball.wicket_type == "stumped").count()
    fielding.run_outs = db.query(Ball).filter(Ball.fielder_id == player.id, Ball.wicket_type == "run_out").count()

    # 4. Tournament Statistics
    team_ids = [t.id for t in player.teams]
    if team_ids:
        tournament.tournaments_played = db.query(TournamentTeam.tournament_id).filter(
            TournamentTeam.team_id.in_(team_ids)
        ).distinct().count()
        tournament.tournaments_won = db.query(Tournament).filter(Tournament.winner_id.in_(team_ids)).count()
        tournament.finals_played = db.query(Match).filter(
            Match.tournament_stage.ilike("final"),
            or_(Match.team1_id.in_(team_ids), Match.team2_id.in_(team_ids))
        ).count()
        
        matches_count = db.query(Match).filter(
            or_(Match.team1_id.in_(team_ids), Match.team2_id.in_(team_ids))
        ).count()
        matches_won = db.query(Match).filter(Match.winner_id.in_(team_ids)).count()
        if matches_count > 0:
            tournament.win_percentage = round((matches_won / matches_count) * 100.0, 1)

    return CareerStatsResponse(
        batting=batting,
        bowling=bowling,
        fielding=fielding,
        tournament=tournament
    )


@router.get("/activity", response_model=List[UserActivityResponse])
def get_profile_activity(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Dynamic check to ensure some initial activities exist for test demonstration
    activities = db.query(UserActivity).filter(UserActivity.user_id == current_user.id).order_by(UserActivity.created_at.desc()).limit(20).all()
    if not activities:
        # Seed some clean starting demo activities
        log_user_activity(db, current_user.id, "account_created", "Joined CricUP platform! Welcome.")
        log_user_activity(db, current_user.id, "profile_creation", "Completed onboarding profile registration.")
        activities = db.query(UserActivity).filter(UserActivity.user_id == current_user.id).order_by(UserActivity.created_at.desc()).all()
    return activities


@router.get("/achievements", response_model=List[UserAchievementResponse])
def get_profile_achievements(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Trigger dynamic lock check and sync
    check_and_unlock_achievements(db, current_user.id)

    user_ach = db.query(UserAchievement).filter(UserAchievement.user_id == current_user.id).all()
    ach_dict = {a.achievement_type: a for a in user_ach}
    
    results = []
    # Guarantee that the UI always receives all 6 standard cards
    for ach_type in ["first_match", "first_fifty", "first_century", "first_wicket", "tournament_winner", "mvp"]:
        if ach_type in ach_dict:
            results.append(ach_dict[ach_type])
        else:
            results.append(UserAchievement(
                user_id=current_user.id,
                achievement_type=ach_type,
                is_unlocked=False,
                unlocked_at=None
            ))
    return results


@router.post("/upload-photo")
def upload_profile_photo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ext = file.filename.split(".")[-1].lower()
    if ext not in ["jpg", "jpeg", "png", "gif", "webp"]:
        raise HTTPException(status_code=400, detail="Invalid file type. Only image files are allowed.")
    
    filename = f"{current_user.id}_{uuid.uuid4().hex}.{ext}"
    os.makedirs(os.path.join("static", "uploads"), exist_ok=True)
    filepath = os.path.join("static", "uploads", filename)
    
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    url = f"/static/uploads/{filename}"
    current_user.profile_photo_url = url
    db.add(current_user)
    
    # Sync to Player model if linked
    player = db.query(Player).filter(Player.user_id == current_user.id).first()
    if player:
        player.profile_photo_url = url
        db.add(player)

    db.commit()
    db.refresh(current_user)
    
    log_user_activity(db, current_user.id, "profile_update", "Uploaded new profile photo.")
    return {"url": url, "profile_photo_url": url}
