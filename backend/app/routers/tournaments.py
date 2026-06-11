from datetime import datetime, timezone, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_
from uuid import UUID
from pydantic import BaseModel

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.cricket import Tournament, Team, TournamentTeam, Match, Innings, TeamPlayer, Player, Ball, MatchSquad
from app.schemas.tournament import (
    TournamentCreate, TournamentResponse, PointsTableEntry, 
    LeaderboardResponse, PlayerLeaderboardEntry
)

router = APIRouter()

class FixtureGenerateRequest(BaseModel):
    home_away: bool = False
    venue: str = "Main Ground"
    over_limit: int = 20
    match_type: str = "T20"

def get_points_table_logic(id: UUID, db: Session) -> List[PointsTableEntry]:
    tour = db.query(Tournament).filter(Tournament.id == id).first()
    if not tour:
        return []
        
    teams = tour.teams
    
    # Get completed/abandoned league matches
    matches = db.query(Match).filter(
        Match.tournament_id == id,
        Match.status.in_(["completed", "abandoned"]),
        (Match.tournament_stage == "league") | (Match.tournament_stage.is_(None))
    ).all()
    
    points_table = []
    
    for team in teams:
        played = 0
        won = 0
        lost = 0
        tied = 0
        no_result = 0
        points = 0
        
        total_runs_scored = 0
        total_overs_faced = 0.0
        total_runs_conceded = 0
        total_overs_bowled = 0.0
        
        for m in matches:
            if team.id not in [m.team1_id, m.team2_id]:
                continue
                
            if m.status == "abandoned":
                played += 1
                no_result += 1
                points += 1
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
                
            t1_squad = db.query(MatchSquad).filter(MatchSquad.match_id == m.id, MatchSquad.team_id == m.team1_id).count() or 11
            t2_squad = db.query(MatchSquad).filter(MatchSquad.match_id == m.id, MatchSquad.team_id == m.team2_id).count() or 11
            
            for innings in m.innings:
                overs_int = int(innings.total_overs)
                overs_balls = round((innings.total_overs - overs_int) * 10)
                actual_fractional = overs_int + (overs_balls / 6.0)
                
                is_batting = innings.batting_team_id == team.id
                opp_squad_size = t2_squad if m.team1_id == team.id else t1_squad
                own_squad_size = t1_squad if m.team1_id == team.id else t2_squad
                
                if is_batting:
                    total_runs_scored += innings.total_runs
                    if innings.total_wickets >= own_squad_size - 1:
                        total_overs_faced += float(m.over_limit)
                    else:
                        total_overs_faced += actual_fractional
                else:
                    total_runs_conceded += innings.total_runs
                    if innings.total_wickets >= opp_squad_size - 1:
                        total_overs_bowled += float(m.over_limit)
                    else:
                        total_overs_bowled += actual_fractional
                        
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
                no_result=no_result,
                points=points,
                runs_for=total_runs_scored,
                runs_against=total_runs_conceded,
                overs_faced=round(total_overs_faced, 2),
                overs_bowled=round(total_overs_bowled, 2),
                net_run_rate=nrr
            )
        )
        
    points_table.sort(key=lambda x: (x.points, x.net_run_rate), reverse=True)
    return points_table

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
        num_teams=tour_in.num_teams,
        status="registration",
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

    if tour.status != "registration":
        raise HTTPException(status_code=400, detail="Cannot add teams after tournament has started")
        
    # Check if team limits reached
    registered_count = db.query(TournamentTeam).filter(TournamentTeam.tournament_id == id).count()
    if registered_count >= tour.num_teams:
        raise HTTPException(status_code=400, detail="Tournament team limit has been reached")
        
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

    # Roster validation: check team has at least 5 players
    player_count = db.query(TeamPlayer).filter(TeamPlayer.team_id == team_id).count()
    if player_count < 5:
        raise HTTPException(status_code=400, detail="Team must have at least 5 registered players for tournament registration")
        
    assoc = TournamentTeam(tournament_id=id, team_id=team_id)
    db.add(assoc)
    db.commit()
    return {"message": "Team registered successfully"}

@router.delete("/{id}/teams/{team_id}", status_code=status.HTTP_200_OK)
def remove_team_from_tournament(
    id: UUID,
    team_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tour = db.query(Tournament).filter(Tournament.id == id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
        
    if tour.organizer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the organizer can modify teams")

    if tour.status != "registration":
        raise HTTPException(status_code=400, detail="Cannot modify teams after tournament has started")

    exists = db.query(TournamentTeam).filter(
        TournamentTeam.tournament_id == id,
        TournamentTeam.team_id == team_id
    ).first()
    
    if not exists:
        raise HTTPException(status_code=404, detail="Team is not registered in this tournament")

    db.delete(exists)
    db.commit()
    return {"message": "Team deregistered successfully"}

@router.post("/{id}/fixtures/generate", status_code=status.HTTP_201_CREATED)
def generate_fixtures(
    id: UUID,
    req: Optional[FixtureGenerateRequest] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tour = db.query(Tournament).filter(Tournament.id == id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")
        
    if tour.organizer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the organizer can generate fixtures")

    teams = tour.teams
    if len(teams) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 teams to generate fixtures")

    home_away = req.home_away if req else False
    venue = req.venue if (req and req.venue) else "Main Ground"
    over_limit = req.over_limit if req else 20
    match_type = req.match_type if (req and req.match_type) else "T20"

    # Delete existing scheduled matches for this tournament to regenerate
    db.query(Match).filter(Match.tournament_id == id, Match.status == "scheduled").delete()

    created_matches = []
    current_match_date = datetime.combine(tour.start_date, datetime.min.time()).replace(tzinfo=timezone.utc)

    if tour.format in ["League", "League + Knockout"]:
        # Round Robin combinations
        pairs = []
        n = len(teams)
        for i in range(n):
            for j in range(i + 1, n):
                pairs.append((teams[i], teams[j]))
                if home_away:
                    pairs.append((teams[j], teams[i]))
                    
        for team_a, team_b in pairs:
            db_match = Match(
                tournament_id=id,
                team1_id=team_a.id,
                team2_id=team_b.id,
                match_date=current_match_date,
                venue=venue,
                status="scheduled",
                match_type=match_type,
                over_limit=over_limit,
                tournament_stage="league"
            )
            db.add(db_match)
            created_matches.append(db_match)
            current_match_date += timedelta(days=1)
            
    elif tour.format == "Knockout":
        n = len(teams)
        if n not in [2, 4, 8]:
            raise HTTPException(status_code=400, detail="Knockout format requires exactly 2, 4, or 8 teams registered")
            
        pairs = []
        for i in range(n // 2):
            pairs.append((teams[i], teams[n - 1 - i]))
            
        stage = "quarter_final" if n == 8 else ("semi_final" if n == 4 else "final")
        
        for idx, (team_a, team_b) in enumerate(pairs):
            code = f"QF{idx + 1}" if n == 8 else (f"SF{idx + 1}" if n == 4 else "F")
            db_match = Match(
                tournament_id=id,
                team1_id=team_a.id,
                team2_id=team_b.id,
                match_date=current_match_date,
                venue=venue,
                status="scheduled",
                match_type=match_type,
                over_limit=over_limit,
                tournament_stage=stage,
                bracket_code=code
            )
            db.add(db_match)
            created_matches.append(db_match)
            current_match_date += timedelta(days=1)

    tour.status = "ongoing"
    db.commit()
    return {"message": f"Generated {len(created_matches)} matches successfully"}

@router.get("/{id}/points-table", response_model=List[PointsTableEntry])
def get_points_table(id: UUID, db: Session = Depends(get_db)):
    return get_points_table_logic(id, db)

@router.get("/{id}/leaderboards", response_model=LeaderboardResponse)
def get_tournament_leaderboards(id: UUID, db: Session = Depends(get_db)):
    # Query top batsmen
    top_batsmen_query = db.query(
        Player.id.label("player_id"),
        Player.name.label("player_name"),
        Team.name.label("team_name"),
        Player.profile_photo_url.label("profile_photo_url"),
        func.sum(Ball.runs_batsman).label("runs")
    ).join(Ball, Ball.batsman_id == Player.id)\
     .join(Innings, Innings.id == Ball.innings_id)\
     .join(Match, Match.id == Innings.match_id)\
     .join(Team, Team.id == Innings.batting_team_id)\
     .filter(Match.tournament_id == id)\
     .group_by(Player.id, Player.name, Team.name, Player.profile_photo_url)\
     .order_by(func.sum(Ball.runs_batsman).desc())\
     .limit(10).all()

    # Query top bowlers
    top_bowlers_query = db.query(
        Player.id.label("player_id"),
        Player.name.label("player_name"),
        Team.name.label("team_name"),
        Player.profile_photo_url.label("profile_photo_url"),
        func.count(Ball.id).label("wickets")
    ).join(Ball, Ball.bowler_id == Player.id)\
     .join(Innings, Innings.id == Ball.innings_id)\
     .join(Match, Match.id == Innings.match_id)\
     .join(Team, Team.id == Innings.bowling_team_id)\
     .filter(
         Match.tournament_id == id,
         Ball.is_wicket == True,
         ~Ball.wicket_type.in_(["run_out", "retired_hurt", "none"])
     ).group_by(Player.id, Player.name, Team.name, Player.profile_photo_url)\
     .order_by(func.count(Ball.id).desc())\
     .limit(10).all()

    batsmen_entries = [
        PlayerLeaderboardEntry(
            player_id=row.player_id,
            player_name=row.player_name,
            team_name=row.team_name,
            profile_photo_url=row.profile_photo_url,
            metric_value=float(row.runs)
        )
        for row in top_batsmen_query
    ]

    bowlers_entries = [
        PlayerLeaderboardEntry(
            player_id=row.player_id,
            player_name=row.player_name,
            team_name=row.team_name,
            profile_photo_url=row.profile_photo_url,
            metric_value=float(row.wickets)
        )
        for row in top_bowlers_query
    ]

    return LeaderboardResponse(
        top_batsmen=batsmen_entries,
        top_bowlers=bowlers_entries
    )

@router.get("/{id}/dashboard")
def get_tournament_dashboard(id: UUID, db: Session = Depends(get_db)):
    tour = db.query(Tournament).filter(Tournament.id == id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Tournament not found")

    # Completed or abandoned matches
    completed_matches = db.query(Match).filter(
        Match.tournament_id == id,
        Match.status.in_(["completed", "abandoned"])
    ).order_by(Match.match_date.desc()).all()

    # Upcoming scheduled/toss/squad matches
    upcoming_matches = db.query(Match).filter(
        Match.tournament_id == id,
        ~Match.status.in_(["completed", "abandoned"])
    ).order_by(Match.match_date.asc()).all()

    points_table = get_points_table_logic(id, db)
    leaderboards = get_tournament_leaderboards(id, db)

    summary_data = {
        "id": str(tour.id),
        "name": tour.name,
        "start_date": str(tour.start_date),
        "end_date": str(tour.end_date),
        "format": tour.format,
        "num_teams": tour.num_teams,
        "status": tour.status,
        "registered_teams_count": len(tour.teams),
        "winner_name": tour.winner.name if tour.winner else None
    }

    def map_match(m):
        return {
            "id": str(m.id),
            "venue": m.venue,
            "match_date": str(m.match_date),
            "match_type": m.match_type,
            "over_limit": m.over_limit,
            "team1_name": m.team1.name,
            "team2_name": m.team2.name,
            "team1_id": str(m.team1_id),
            "team2_id": str(m.team2_id),
            "status": m.status,
            "winner_name": m.winner.name if m.winner else None,
            "win_margin_runs": m.win_margin_runs,
            "win_margin_wickets": m.win_margin_wickets,
            "tournament_stage": m.tournament_stage,
            "bracket_code": m.bracket_code
        }

    return {
        "summary": summary_data,
        "points_table": points_table,
        "leaderboards": leaderboards,
        "upcoming_matches": [map_match(m) for m in upcoming_matches],
        "completed_matches": [map_match(m) for m in completed_matches]
    }

def check_and_progress_tournament(tournament_id: UUID, db: Session):
    tour = db.query(Tournament).filter(Tournament.id == tournament_id).first()
    if not tour or tour.status == "completed":
        return

    # Check if all matches currently generated for the tournament are completed
    active_matches = db.query(Match).filter(Match.tournament_id == tournament_id).all()
    if not active_matches:
        return

    # If any match is not completed or abandoned, we cannot progress
    if any(m.status not in ["completed", "abandoned"] for m in active_matches):
        return

    # All current matches are completed! Let's check which stages are present
    stages = [m.tournament_stage for m in active_matches if m.tournament_stage]
    
    if tour.format == "League":
        # Pure league tournament completes when all league matches finish
        standings = get_points_table_logic(tour.id, db)
        if standings:
            tour.winner_id = standings[0].team_id
        tour.status = "completed"
        db.add(tour)
        db.commit()
        return

    elif tour.format == "Knockout":
        # Knockout progression: QF -> SF -> F
        if "quarter_final" in stages and not any(s == "semi_final" for s in stages):
            # QF finished, generate SF
            qf_matches = [m for m in active_matches if m.tournament_stage == "quarter_final"]
            if len(qf_matches) == 4:
                qf1 = next((m for m in qf_matches if m.bracket_code == "QF1"), None)
                qf2 = next((m for m in qf_matches if m.bracket_code == "QF2"), None)
                qf3 = next((m for m in qf_matches if m.bracket_code == "QF3"), None)
                qf4 = next((m for m in qf_matches if m.bracket_code == "QF4"), None)
                
                if qf1 and qf2 and qf3 and qf4:
                    ref = qf_matches[0]
                    sf1 = Match(
                        tournament_id=tournament_id,
                        team1_id=qf1.winner_id or qf1.team1_id,
                        team2_id=qf2.winner_id or qf2.team1_id,
                        match_date=datetime.now(timezone.utc) + timedelta(days=1),
                        venue=ref.venue,
                        status="scheduled",
                        match_type=ref.match_type,
                        over_limit=ref.over_limit,
                        tournament_stage="semi_final",
                        bracket_code="SF1"
                    )
                    sf2 = Match(
                        tournament_id=tournament_id,
                        team1_id=qf3.winner_id or qf3.team1_id,
                        team2_id=qf4.winner_id or qf4.team1_id,
                        match_date=datetime.now(timezone.utc) + timedelta(days=1),
                        venue=ref.venue,
                        status="scheduled",
                        match_type=ref.match_type,
                        over_limit=ref.over_limit,
                        tournament_stage="semi_final",
                        bracket_code="SF2"
                    )
                    db.add(sf1)
                    db.add(sf2)
                    db.commit()
            
        elif "semi_final" in stages and not any(s == "final" for s in stages):
            # SF finished, generate Final
            sf_matches = [m for m in active_matches if m.tournament_stage == "semi_final"]
            sf1 = next((m for m in sf_matches if m.bracket_code == "SF1"), None)
            sf2 = next((m for m in sf_matches if m.bracket_code == "SF2"), None)
            
            if sf1 and sf2:
                ref = sf_matches[0]
                final_match = Match(
                    tournament_id=tournament_id,
                    team1_id=sf1.winner_id or sf1.team1_id,
                    team2_id=sf2.winner_id or sf2.team1_id,
                    match_date=datetime.now(timezone.utc) + timedelta(days=2),
                    venue=ref.venue,
                    status="scheduled",
                    match_type=ref.match_type,
                    over_limit=ref.over_limit,
                    tournament_stage="final",
                    bracket_code="F"
                )
                db.add(final_match)
                db.commit()
            
        elif "final" in stages:
            # Final finished, tournament complete!
            final_match = next((m for m in active_matches if m.tournament_stage == "final" and m.bracket_code == "F"), None)
            if final_match:
                tour.winner_id = final_match.winner_id or final_match.team1_id
                tour.status = "completed"
                db.add(tour)
                db.commit()

    elif tour.format == "League + Knockout":
        # Hybrid progression: League -> SF -> Final
        if all(m.tournament_stage == "league" for m in active_matches):
            # League finished, generate SF
            standings = get_points_table_logic(tour.id, db)
            if len(standings) < 4:
                # Fallback: not enough teams, complete the tournament early
                if standings:
                    tour.winner_id = standings[0].team_id
                tour.status = "completed"
                db.add(tour)
                db.commit()
                return
                
            # Top 4 teams qualify
            t1, t2, t3, t4 = standings[0].team_id, standings[1].team_id, standings[2].team_id, standings[3].team_id
            
            ref = active_matches[0]
            sf1 = Match(
                tournament_id=tournament_id,
                team1_id=t1,
                team2_id=t4,
                match_date=datetime.now(timezone.utc) + timedelta(days=1),
                venue=ref.venue,
                status="scheduled",
                match_type=ref.match_type,
                over_limit=ref.over_limit,
                tournament_stage="semi_final",
                bracket_code="SF1"
            )
            sf2 = Match(
                tournament_id=tournament_id,
                team1_id=t2,
                team2_id=t3,
                match_date=datetime.now(timezone.utc) + timedelta(days=1),
                venue=ref.venue,
                status="scheduled",
                match_type=ref.match_type,
                over_limit=ref.over_limit,
                tournament_stage="semi_final",
                bracket_code="SF2"
            )
            db.add(sf1)
            db.add(sf2)
            db.commit()
            
        elif "semi_final" in stages and not any(s == "final" for s in stages):
            # SF finished, generate Final
            sf_matches = [m for m in active_matches if m.tournament_stage == "semi_final"]
            sf1 = next((m for m in sf_matches if m.bracket_code == "SF1"), None)
            sf2 = next((m for m in sf_matches if m.bracket_code == "SF2"), None)
            
            if sf1 and sf2:
                ref = sf_matches[0]
                final_match = Match(
                    tournament_id=tournament_id,
                    team1_id=sf1.winner_id or sf1.team1_id,
                    team2_id=sf2.winner_id or sf2.team1_id,
                    match_date=datetime.now(timezone.utc) + timedelta(days=2),
                    venue=ref.venue,
                    status="scheduled",
                    match_type=ref.match_type,
                    over_limit=ref.over_limit,
                    tournament_stage="final",
                    bracket_code="F"
                )
                db.add(final_match)
                db.commit()
            
        elif "final" in stages:
            # Final finished, tournament complete!
            final_match = next((m for m in active_matches if m.tournament_stage == "final" and m.bracket_code == "F"), None)
            if final_match:
                tour.winner_id = final_match.winner_id or final_match.team1_id
                tour.status = "completed"
                db.add(tour)
                db.commit()
