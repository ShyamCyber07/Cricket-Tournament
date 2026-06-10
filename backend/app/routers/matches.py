from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc, func
from uuid import UUID

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.cricket import Match, Team, Player, MatchSquad, Innings, Ball
from app.schemas.match import (
    MatchCreate, MatchResponse, TossSubmit, SquadSubmit, 
    BallCreate, LiveMatchState, StrikerState, BowlerState, 
    InningsSummarySchema, RecentBallSchema
)

router = APIRouter()

@router.get("/", response_model=List[MatchResponse])
def list_matches(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Match).order_by(desc(Match.created_at)).all()

@router.post("/", response_model=MatchResponse, status_code=status.HTTP_201_CREATED)
def create_match(
    match_in: MatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
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
        status="scheduled"
    )
    db.add(db_match)
    db.commit()
    db.refresh(db_match)
    return db_match

@router.post("/{id}/toss", response_model=MatchResponse)
def submit_toss(
    id: UUID,
    toss: TossSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if toss.toss_winner_id not in [match.team1_id, match.team2_id]:
        raise HTTPException(status_code=400, detail="Toss winner must be one of the playing teams")

    match.toss_winner_id = toss.toss_winner_id
    match.toss_decision = toss.toss_decision
    match.status = "team_selection"
    db.commit()
    db.refresh(match)
    return match

@router.post("/{id}/squads", status_code=status.HTTP_200_OK)
def submit_squads(
    id: UUID,
    squad: SquadSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if squad.team_id not in [match.team1_id, match.team2_id]:
        raise HTTPException(status_code=400, detail="Team is not playing in this match")

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
            is_playing_xi=True,
            is_captain=p.is_captain,
            is_wicketkeeper=p.is_wicketkeeper
        )
        db.add(db_squad)

    db.commit()

    # If squads for both teams are registered, transition match status to first innings
    squad1_count = db.query(MatchSquad).filter(MatchSquad.match_id == id, MatchSquad.team_id == match.team1_id).count()
    squad2_count = db.query(MatchSquad).filter(MatchSquad.match_id == id, MatchSquad.team_id == match.team2_id).count()
    
    if squad1_count > 0 and squad2_count > 0:
        match.status = "innings1"
        
        # Create first Innings
        # Decide who bats first
        toss_win = match.toss_winner_id
        toss_dec = match.toss_decision
        
        batting_team_id = None
        bowling_team_id = None
        
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

        # Verify no innings exists yet
        existing_innings = db.query(Innings).filter(Innings.match_id == id, Innings.innings_number == 1).first()
        if not existing_innings:
            first_innings = Innings(
                match_id=id,
                innings_number=1,
                batting_team_id=batting_team_id,
                bowling_team_id=bowling_team_id
            )
            db.add(first_innings)
            
        db.commit()
        db.refresh(match)
        
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

@router.post("/{id}/balls", status_code=status.HTTP_201_CREATED)
def submit_ball(
    id: UUID,
    ball_in: BallCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if match.status not in ["innings1", "innings2"]:
        raise HTTPException(status_code=400, detail="Match is not in live scoring state")

    # Get active innings
    active_innings_num = 1 if match.status == "innings1" else 2
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
    # Standard over number = (legit balls // 6) + 1
    legit_balls_count = db.query(Ball).filter(
        Ball.innings_id == innings.id,
        ~Ball.extra_type.in_(["wide", "no_ball"])
    ).count()
    
    current_over = (legit_balls_count // 6) + 1
    
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
        commentary=ball_in.commentary
    )
    db.add(db_ball)
    db.flush() # flush ball first to query cleanly

    # Recalculate Innings details
    # Runs: batsman runs + extras runs
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

    # Update overs (legitimate balls only)
    is_legit = ball_in.extra_type not in ["wide", "no_ball"]
    if is_legit:
        legit_balls_count += 1

    innings.total_overs = float(f"{legit_balls_count // 6}.{legit_balls_count % 6}")

    # Set Match striker/non-striker/bowler state caches
    # Default is what was passed in
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
    # Wickets: strike doesn't change unless it is a run-out of non-striker
    # Wides/No balls: check runs
    # Total batsman runs or extras byes/leg-byes
    runs_for_rotation = ball_in.runs_batsman
    if ball_in.extra_type in ["bye", "leg_bye"]:
        runs_for_rotation = ball_in.runs_extras

    if runs_for_rotation % 2 == 1 and next_striker and next_non_striker:
        # Swap
        next_striker, next_non_striker = next_non_striker, next_striker

    # Over completion logic: 6 legitimate balls completed
    is_over_completed = is_legit and (legit_balls_count % 6 == 0)
    if is_over_completed:
        # Swap strike at end of over
        if next_striker and next_non_striker:
            next_striker, next_non_striker = next_non_striker, next_striker
        # Bowler is unset so scorer has to pick new bowler
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
            # Transition to 2nd innings
            match.status = "innings2"
            # Create Innings 2 record
            second_innings = Innings(
                match_id=id,
                innings_number=2,
                batting_team_id=innings.bowling_team_id,
                bowling_team_id=innings.batting_team_id
            )
            db.add(second_innings)
            next_striker = None
            next_non_striker = None
            next_bowler = None
        else:
            # Match completed
            match.status = "completed"
            first_innings_runs = db.query(Innings.total_runs).filter(
                Innings.match_id == id,
                Innings.innings_number == 1
            ).scalar() or 0
            
            # Winner assessment
            if first_innings_runs > innings.total_runs:
                match.winner_id = match.toss_winner_id if innings.bowling_team_id == match.toss_winner_id else (match.team1_id if match.team1_id == innings.bowling_team_id else match.team2_id)
                # Ensure correct team mapping
                match.winner_id = innings.bowling_team_id
                match.win_margin_runs = first_innings_runs - innings.total_runs
            elif innings.total_runs > first_innings_runs:
                match.winner_id = innings.batting_team_id
                match.win_margin_wickets = 10 - innings.total_wickets
            else:
                # Tied match
                match.winner_id = None
                
            next_striker = None
            next_non_striker = None
            next_bowler = None

    # Update match active caches
    match.current_striker_id = next_striker
    match.current_non_striker_id = next_non_striker
    match.current_bowler_id = next_bowler

    db.commit()
    return {"message": "Ball recorded successfully", "innings_completed": innings.is_completed}

@router.post("/{id}/undo", status_code=status.HTTP_200_OK)
def undo_last_ball(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    if match.status not in ["innings1", "innings2", "completed"]:
        raise HTTPException(status_code=400, detail="No logs to undo")

    # Get the active innings
    active_innings_num = 2 if match.status == "completed" or match.status == "innings2" else 1
    # Check if 2nd innings has any balls logged. If not, rollback innings status
    innings = db.query(Innings).filter(
        Innings.match_id == id,
        Innings.innings_number == active_innings_num
    ).first()

    if active_innings_num == 2 and match.status == "innings2":
        balls_count = db.query(Ball).filter(Ball.innings_id == innings.id).count()
        if balls_count == 0:
            # We are at the start of 2nd innings, need to roll back to 1st innings end
            # Delete 2nd innings record
            db.delete(innings)
            match.status = "innings1"
            # Get 1st innings to set active
            innings = db.query(Innings).filter(
                Innings.match_id == id,
                Innings.innings_number == 1
            ).first()
            innings.is_completed = False
            db.flush()

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
    
    legit_balls_count = sum(1 for b in balls if b.extra_type not in ["wide", "no_ball"])
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
    return {"message": "Last ball rolled back successfully"}

@router.get("/{id}/live", response_model=LiveMatchState)
def get_live_match(id: UUID, db: Session = Depends(get_db)):
    match = db.query(Match).filter(Match.id == id).first()
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")

    # Get active innings
    active_num = 2 if match.status in ["innings2", "completed"] else 1
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
        legit_balls = sum(1 for b in balls if b.extra_type != "wide")
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
        wickets = sum(1 for b in balls if b.is_wicket and b.wicket_type not in ["run_out", "retired_hurt", "none"])
        legit_balls = sum(1 for b in balls if b.extra_type not in ["wide", "no_ball"])
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
            legit_over_balls = [ob for ob in over_balls if ob.extra_type not in ["wide", "no_ball"]]
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

    # Compile recent balls ticker (last 12 balls)
    recent_balls = []
    if current_innings:
        balls_logged = db.query(Ball).filter(
            Ball.innings_id == current_innings.id
        ).order_by(Ball.ball_number.desc()).limit(12).all()
        # reverse to show chronological order
        balls_logged.reverse()
        
        for bl in balls_logged:
            label = str(bl.runs_batsman)
            if bl.is_wicket:
                label = "W"
            elif bl.extra_type == "wide":
                label = f"{bl.runs_extras}Wd"
            elif bl.extra_type == "no_ball":
                label = f"{bl.runs_batsman + bl.runs_extras}Nb"
            elif bl.extra_type == "bye":
                label = f"{bl.runs_extras}B"
            elif bl.extra_type == "leg_bye":
                label = f"{bl.runs_extras}Lb"
                
            recent_balls.append(
                RecentBallSchema(
                    ball_label=label,
                    runs=bl.runs_batsman + bl.runs_extras,
                    extra_type=bl.extra_type,
                    is_wicket=bl.is_wicket
                )
            )

    # Target calculation
    target = None
    if active_num == 2 and prev_innings:
        target = prev_innings.total_runs + 1

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
        current_innings_number=active_num,
        target=target,
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
            is_completed=prev_innings.is_completed,
            dismissed_player_ids=prev_dismissed_ids,
            last_bowler_id=prev_last_bowler_id
        ) if prev_innings else None,
        recent_balls=recent_balls
    )

