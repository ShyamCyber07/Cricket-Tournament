import sys
import os
sys.path.insert(0, os.path.abspath('.'))

from uuid import UUID
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.core.database import SessionLocal
from app.models.cricket import Innings, Ball, Match, Player
from app.routers.matches import get_live_match

def calculate_batsman_stats(db: Session, innings_id: UUID, player_id: UUID):
    balls = db.query(Ball).filter(
        Ball.innings_id == innings_id,
        Ball.batsman_id == player_id
    ).all()
    runs = sum(b.runs_batsman for b in balls)
    fours = sum(1 for b in balls if b.runs_batsman == 4)
    sixes = sum(1 for b in balls if b.runs_batsman == 6)
    legit_balls = sum(1 for b in balls if b.extra_type != "wide")
    sr = round((runs / legit_balls) * 100, 2) if legit_balls > 0 else 0.0
    return {
        "runs": runs,
        "balls": legit_balls,
        "fours": fours,
        "sixes": sixes,
        "strike_rate": sr
    }

def calculate_bowler_stats(db: Session, innings_id: UUID, player_id: UUID):
    balls = db.query(Ball).filter(
        Ball.innings_id == innings_id,
        Ball.bowler_id == player_id
    ).all()
    runs_conceded = sum(b.runs_batsman + b.runs_extras for b in balls if b.extra_type in ["wide", "no_ball", "none"])
    wickets = sum(1 for b in balls if b.is_wicket and b.wicket_type not in ["run_out", "retired_hurt", "none"])
    legit_balls = sum(1 for b in balls if b.extra_type not in ["wide", "no_ball"])
    overs = float(f"{legit_balls // 6}.{legit_balls % 6}")
    overs_frac = legit_balls / 6.0
    econ = round(runs_conceded / overs_frac, 2) if overs_frac > 0 else 0.0
    
    # Maidens
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
                
    return {
        "overs": overs,
        "runs": runs_conceded,
        "wickets": wickets,
        "maidens": maidens,
        "economy": econ
    }

def repair_database():
    db = SessionLocal()
    try:
        print("==================================================")
        print("          CRICKET DATABASE REPAIR SCRIPT          ")
        print("==================================================")
        
        for innings in db.query(Innings).all():
            match = innings.match
            print(f"\nAnalyzing Innings ID: {innings.id} (Innings #{innings.innings_number})")
            print(f"Match ID: {match.id} ({match.team1.name} vs {match.team2.name})")
            print(f"Batting Team: {innings.batting_team.name}")
            
            balls = db.query(Ball).filter(Ball.innings_id == innings.id).all()
            
            # Recalculate totals
            new_runs = sum(b.runs_batsman + b.runs_extras for b in balls)
            new_wickets = sum(1 for b in balls if b.is_wicket)
            
            new_wides = sum(b.runs_extras for b in balls if b.extra_type == "wide")
            new_noballs = sum(b.runs_extras for b in balls if b.extra_type == "no_ball")
            new_byes = sum(b.runs_extras for b in balls if b.extra_type == "bye")
            new_legbyes = sum(b.runs_extras for b in balls if b.extra_type == "leg_bye")
            
            legit_balls_count = sum(1 for b in balls if b.extra_type not in ["wide", "no_ball"])
            new_overs = float(f"{legit_balls_count // 6}.{legit_balls_count % 6}")
            
            print("\n  --- INNINGS AGGREGATES ---")
            print(f"    Total Runs:    Before: {innings.total_runs:<5} | After: {new_runs:<5}")
            print(f"    Wickets:       Before: {innings.total_wickets:<5} | After: {new_wickets:<5}")
            print(f"    Overs:         Before: {innings.total_overs:<5} | After: {new_overs:<5}")
            print(f"    Extras Wides:  Before: {innings.extras_wides:<5} | After: {new_wides:<5}")
            print(f"    Extras NoBall: Before: {innings.extras_noballs:<5} | After: {new_noballs:<5}")
            print(f"    Extras Byes:   Before: {innings.extras_byes:<5} | After: {new_byes:<5}")
            print(f"    Extras LegBye: Before: {innings.extras_legbyes:<5} | After: {new_legbyes:<5}")
            
            # Update fields
            innings.total_runs = new_runs
            innings.total_wickets = new_wickets
            innings.extras_wides = new_wides
            innings.extras_noballs = new_noballs
            innings.extras_byes = new_byes
            innings.extras_legbyes = new_legbyes
            innings.total_overs = new_overs
            
            # Recalculate batsman stats for players who faced any balls
            faced_player_ids = set(b.batsman_id for b in balls)
            if faced_player_ids:
                print("\n  --- BATSMAN STATISTICS ---")
                for p_id in faced_player_ids:
                    p_name = db.query(Player.name).filter(Player.id == p_id).scalar()
                    stats = calculate_batsman_stats(db, innings.id, p_id)
                    print(f"    Player: {p_name} ({p_id})")
                    print(f"      Runs: {stats['runs']}, Balls: {stats['balls']}, 4s: {stats['fours']}, 6s: {stats['sixes']}, SR: {stats['strike_rate']}")
            
            # Recalculate bowler stats for players who bowled any balls
            bowled_player_ids = set(b.bowler_id for b in balls)
            if bowled_player_ids:
                print("\n  --- BOWLER STATISTICS ---")
                for p_id in bowled_player_ids:
                    p_name = db.query(Player.name).filter(Player.id == p_id).scalar()
                    stats = calculate_bowler_stats(db, innings.id, p_id)
                    print(f"    Bowler: {p_name} ({p_id})")
                    print(f"      Overs: {stats['overs']}, Runs Conceded: {stats['runs']}, Wickets: {stats['wickets']}, Maidens: {stats['maidens']}, Econ: {stats['economy']}")
        
        db.commit()
        print("\nAll database updates committed successfully.")
        
        # Verify against live match endpoint
        print("\n==================================================")
        print("          VERIFYING LIVE MATCH ENDPOINTS          ")
        print("==================================================")
        for match in db.query(Match).all():
            if match.status in ["innings1", "innings2", "completed"]:
                live_state = get_live_match(match.id, db)
                print(f"\nMatch ID: {match.id} Status: {match.status}")
                print(f"  Live Score: {live_state.current_innings.total_runs}/{live_state.current_innings.total_wickets} in {live_state.current_innings.total_overs} overs")
                print(f"  Live Striker: {live_state.striker.name if live_state.striker else 'None'} -> {live_state.striker.runs if live_state.striker else 0} runs ({live_state.striker.balls if live_state.striker else 0} balls)")
                print(f"  Live Non-Striker: {live_state.non_striker.name if live_state.non_striker else 'None'} -> {live_state.non_striker.runs if live_state.non_striker else 0} runs ({live_state.non_striker.balls if live_state.non_striker else 0} balls)")
                print(f"  Live Bowler: {live_state.bowler.name if live_state.bowler else 'None'} -> {live_state.bowler.overs if live_state.bowler else 0.0} overs, {live_state.bowler.runs if live_state.bowler else 0} runs, {live_state.bowler.wickets if live_state.bowler else 0} wickets")

    finally:
        db.close()

if __name__ == "__main__":
    repair_database()
