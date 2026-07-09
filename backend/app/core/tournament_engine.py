import logging
import uuid
import json
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.models.cricket import Tournament, Match, Team, MatchSquad, Innings, TournamentStanding
from app.core.notification import sendToUser

logger = logging.getLogger(__name__)

def init_tournament_standings(db: Session, tournament_id: uuid.UUID):
    """
    Initializes standing records for all teams in the tournament if they do not exist yet.
    """
    tour = db.query(Tournament).filter(Tournament.id == tournament_id).first()
    if not tour:
        return
        
    for team in tour.teams:
        existing = db.query(TournamentStanding).filter(
            TournamentStanding.tournament_id == tournament_id,
            TournamentStanding.team_id == team.id
        ).first()
        
        if not existing:
            standing = TournamentStanding(
                id=uuid.uuid4(),
                tournament_id=tournament_id,
                team_id=team.id,
                played=0,
                won=0,
                lost=0,
                tied=0,
                no_result=0,
                points=0,
                runs_scored=0,
                overs_faced=0.0,
                runs_conceded=0,
                overs_bowled=0.0,
                net_run_rate=0.0,
                is_qualified=False
            )
            db.add(standing)
            
    db.commit()
    logger.info(f"[TournamentEngine] Initialized standings for tournament: {tournament_id}")

def update_team_standings_on_match_completion(db: Session, match_id: uuid.UUID):
    """
    Recalculates and updates the standings only for the two teams involved in the completed match.
    Also automatically updates the overall tournament status and triggers qualification updates.
    """
    match = db.query(Match).filter(Match.id == match_id).first()
    if not match or not match.tournament_id:
        return
        
    tournament_id = match.tournament_id
    
    # Initialize standings if not exist
    init_tournament_standings(db, tournament_id)
    
    # We update the standings for team1 and team2
    for team_id in [match.team1_id, match.team2_id]:
        # Fetch completed/abandoned league matches for this team
        matches = db.query(Match).filter(
            Match.tournament_id == tournament_id,
            Match.status.in_(["completed", "abandoned"]),
            or_(Match.tournament_stage == "league", Match.tournament_stage.is_(None)),
            or_(Match.team1_id == team_id, Match.team2_id == team_id)
        ).all()
        
        played = 0
        won = 0
        lost = 0
        tied = 0
        no_result = 0
        points = 0
        
        runs_scored = 0
        overs_faced = 0.0
        runs_conceded = 0
        overs_bowled = 0.0
        
        for m in matches:
            if m.status == "abandoned":
                played += 1
                no_result += 1
                points += 1
                continue
                
            played += 1
            if m.winner_id == team_id:
                won += 1
                points += 2
            elif m.winner_id is None:
                tied += 1
                points += 1
            else:
                lost += 1
                
            t1_squad = db.query(MatchSquad).filter(MatchSquad.match_id == m.id, MatchSquad.team_id == m.team1_id).count() or 11
            t2_squad = db.query(MatchSquad).filter(MatchSquad.match_id == m.id, MatchSquad.team_id == m.team2_id).count() or 11
            
            for innings in m.innings:
                overs_int = int(innings.total_overs)
                overs_balls = round((innings.total_overs - overs_int) * 10)
                actual_fractional = overs_int + (overs_balls / 6.0)
                
                is_batting = innings.batting_team_id == team_id
                opp_squad_size = t2_squad if m.team1_id == team_id else t1_squad
                own_squad_size = t1_squad if m.team1_id == team_id else t2_squad
                
                if is_batting:
                    runs_scored += innings.total_runs
                    if innings.total_wickets >= own_squad_size - 1:
                        overs_faced += float(m.over_limit)
                    else:
                        overs_faced += actual_fractional
                else:
                    runs_conceded += innings.total_runs
                    if innings.total_wickets >= opp_squad_size - 1:
                        overs_bowled += float(m.over_limit)
                    else:
                        overs_bowled += actual_fractional
                        
        nrr = 0.0
        if overs_faced > 0 and overs_bowled > 0:
            rate_scored = runs_scored / overs_faced
            rate_conceded = runs_conceded / overs_bowled
            nrr = round(rate_scored - rate_conceded, 3)
            
        # Update TournamentStanding record
        standing = db.query(TournamentStanding).filter(
            TournamentStanding.tournament_id == tournament_id,
            TournamentStanding.team_id == team_id
        ).first()
        
        if standing:
            standing.played = played
            standing.won = won
            standing.lost = lost
            standing.tied = tied
            standing.no_result = no_result
            standing.points = points
            standing.runs_scored = runs_scored
            standing.overs_faced = round(overs_faced, 2)
            standing.runs_conceded = runs_conceded
            standing.overs_bowled = round(overs_bowled, 2)
            standing.net_run_rate = nrr
            
    db.commit()
    logger.info(f"[TournamentEngine] Updated standings for match teams in tournament: {tournament_id}")
    
    # Update Qualification status
    run_qualification_check(db, tournament_id)
    
    # Update Tournament status (Upcoming -> Running -> Completed)
    update_tournament_status_progression(db, tournament_id)

def run_qualification_check(db: Session, tournament_id: uuid.UUID):
    """
    Evaluates standings, applies ranking rules, and marks qualifying teams.
    Supports League and Knockout stage progressions.
    """
    tour = db.query(Tournament).filter(Tournament.id == tournament_id).first()
    if not tour:
        return
        
    standings = db.query(TournamentStanding).filter(
        TournamentStanding.tournament_id == tournament_id
    ).all()
    
    if not standings:
        return
        
    # Sort standings by: 1. Points, 2. NRR, 3. Wins (Head-to-head placeholder / wins)
    standings.sort(key=lambda x: (x.points, x.net_run_rate, x.won), reverse=True)
    
    # Reset qualification status
    for st in standings:
        st.is_qualified = False
        
    # Apply qualification rules based on format
    if tour.format == "League":
        # Top team qualifies as winner
        standings[0].is_qualified = True
    elif "Knockout" in tour.format or "Cup" in tour.format:
        # Top 4 teams qualify for knockout / semi-finals
        limit = min(4, len(standings))
        for i in range(limit):
            standings[i].is_qualified = True
            
    db.commit()
    logger.info(f"[TournamentEngine] Updated qualification tags for tournament: {tournament_id}")

def update_tournament_status_progression(db: Session, tournament_id: uuid.UUID):
    """
    Transitions tournament status (Upcoming -> Running -> Completed) based on matches progression.
    """
    tour = db.query(Tournament).filter(Tournament.id == tournament_id).first()
    if not tour:
        return
        
    matches = db.query(Match).filter(Match.tournament_id == tournament_id).all()
    if not matches:
        return
        
    any_live_or_finished = any(
        m.status in ["live", "innings_break", "innings1", "innings2", "completed", "abandoned"]
        for m in matches
    )
    
    is_tour_completed = False
    if tour.format == "League":
        is_tour_completed = all(m.status in ["completed", "abandoned"] for m in matches)
    else:
        final_match = next((m for m in matches if m.tournament_stage == "final"), None)
        is_tour_completed = final_match is not None and final_match.status in ["completed", "abandoned"]
    
    old_status = tour.status
    if is_tour_completed:
        tour.status = "completed"
        # Set winner
        standings = db.query(TournamentStanding).filter(
            TournamentStanding.tournament_id == tournament_id
        ).all()
        if standings:
            standings.sort(key=lambda x: (x.points, x.net_run_rate, x.won), reverse=True)
            tour.winner_id = standings[0].team_id
    elif any_live_or_finished:
        tour.status = "ongoing"  # Running state
    else:
        tour.status = "registration_closed"  # Upcoming / Fixtures published state
        
    if tour.status != old_status:
        db.commit()
        logger.info(f"[TournamentEngine] Status changed from {old_status} to {tour.status} for tournament: {tournament_id}")
        
        # Notify Organizer
        if tour.organizer_id:
            sendToUser(
                db, 
                tour.organizer_id, 
                "Tournament Status Update", 
                f"Tournament '{tour.name}' status has transitioned to {tour.status.upper()}.", 
                "TOURNAMENT", 
                json.dumps({"tournament_id": str(tournament_id)})
            )
