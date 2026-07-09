import logging
import uuid
import json
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.notification import sendToUser
from app.models.cricket import Match, TeamMember, MatchSquad, AutomationLog, Player
from app.models.user import User

logger = logging.getLogger(__name__)

# Reusable scheduler service
def log_automation_event(db: Session, match_id: uuid.UUID, event_type: str, recipient_id: uuid.UUID = None) -> bool:
    """
    Checks if an automation event has already been executed/sent for this match/recipient.
    If not, it logs it to the database to prevent duplicate notifications.
    """
    existing = db.query(AutomationLog).filter(
        AutomationLog.match_id == match_id,
        AutomationLog.event_type == event_type,
        AutomationLog.recipient_id == recipient_id
    ).first()
    
    if existing:
        return False
        
    log = AutomationLog(
        id=uuid.uuid4(),
        match_id=match_id,
        event_type=event_type,
        recipient_id=recipient_id,
        executed_at=datetime.now(timezone.utc)
    )
    db.add(log)
    db.commit()
    logger.info(f"[Scheduler] Logged event: {event_type} for match: {match_id}, recipient: {recipient_id}")
    return True

def get_captains_and_creators(db: Session, team_id: uuid.UUID) -> list[uuid.UUID]:
    """
    Returns unique user IDs of captains and creators for a given team.
    """
    recipients = []
    
    # 1. Captains in team_members
    captains = db.query(TeamMember).filter(
        TeamMember.team_id == team_id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).all()
    for cap in captains:
        recipients.append(cap.user_id)
        
    # 2. Team creator/owner
    from app.models.cricket import Team
    team = db.query(Team).filter(Team.id == team_id).first()
    if team and team.created_by:
        recipients.append(team.created_by)
        
    # Deduplicate
    return list(set(recipients))

def get_match_organizers(db: Session, match: Match) -> list[uuid.UUID]:
    """
    Returns unique user IDs of organizers of the match.
    """
    organizers = []
    if match.created_by:
        organizers.append(match.created_by)
    if match.tournament_organizer_id:
        organizers.append(match.tournament_organizer_id)
        
    # Deduplicate
    return list(set(organizers))

def finalize_squad_auto_lock(db: Session, match_id: uuid.UUID, team_id: uuid.UUID):
    """
    Automatically populates and finalizes a team's playing XI, captain, wicket keeper,
    and batting/bowling orders if they are not fully selected.
    """
    # 1. Fetch existing MatchSquad entries
    existing_squads = db.query(MatchSquad).filter(
        MatchSquad.match_id == match_id,
        MatchSquad.team_id == team_id
    ).all()
    
    # If squad already exists but just not locked, we keep it and only lock/fill gaps
    # Otherwise, populate it from the active team members
    if not existing_squads:
        # Fetch active team members
        members = db.query(TeamMember).filter(
            TeamMember.team_id == team_id,
            TeamMember.status == "active"
        ).order_by(TeamMember.role.desc(), TeamMember.joined_at.asc()).all()
        
        if not members:
            logger.warning(f"[AutoLock] No members found for team {team_id} in match {match_id}. Cannot populate squad.")
            return
            
        # Select up to 11 players for the squad
        selected_members = members[:11]
        for idx, member in enumerate(selected_members):
            # Try to find user profile to get player ID
            player = db.query(Player).filter(Player.user_id == member.user_id).first()
            player_id = player.id if player else member.user_id # fallback
            
            squad_item = MatchSquad(
                match_id=match_id,
                team_id=team_id,
                player_id=player_id,
                is_playing_xi=True,
                is_captain=(idx == 0),
                is_wicketkeeper=(idx == 0),
                batting_order=idx + 1,
                bowling_preference=idx + 1
            )
            db.add(squad_item)
        db.commit()
    else:
        # Check gaps: ensure there's at least one captain and wicketkeeper in the existing squad
        has_captain = any(s.is_captain for s in existing_squads)
        has_wk = any(s.is_wicketkeeper for s in existing_squads)
        
        for idx, squad_item in enumerate(existing_squads):
            # Auto-assign captain/wk if missing
            if not has_captain and idx == 0:
                squad_item.is_captain = True
                has_captain = True
            if not has_wk and idx == 0:
                squad_item.is_wicketkeeper = True
                has_wk = True
                
            # Fill batting order/bowling preference if null
            if squad_item.batting_order is None:
                squad_item.batting_order = idx + 1
            if squad_item.bowling_preference is None:
                squad_item.bowling_preference = idx + 1
                
        db.commit()

# Main automation loop check function
def run_matchday_automation_engine(db: Session):
    """
    Periodic check function that transitions match states, sends push alerts,
    and executes squad auto-locks automatically. Called every minute.
    """
    now = datetime.now(timezone.utc)
    
    # 1. Fetch active matches (not completed/abandoned)
    active_matches = db.query(Match).filter(
        Match.status.in_(["scheduled", "upcoming", "playing_xi_pending", "ready", "toss", "team_selection", "innings1", "innings2", "innings_break"])
    ).all()
    
    for m in active_matches:
        try:
            match_date_utc = m.match_date.replace(tzinfo=timezone.utc) if m.match_date.tzinfo is None else m.match_date
            
            # Offsets
            t_24h = match_date_utc - timedelta(hours=settings.REMINDER_24H_OFFSET_HOURS)
            t_2h = match_date_utc - timedelta(hours=settings.REMINDER_2H_OFFSET_HOURS)
            t_30m = match_date_utc - timedelta(minutes=settings.REMINDER_30M_OFFSET_MINUTES)
            t_10m = match_date_utc - timedelta(minutes=settings.REMINDER_10M_OFFSET_MINUTES)
            t_autolock = match_date_utc - timedelta(minutes=settings.AUTO_LOCK_OFFSET_MINUTES)
            
            # --- PART 1 & 6: STATE TRANSITIONS ---
            if now >= t_24h and m.status == "scheduled":
                m.status = "upcoming"
                db.commit()
                logger.info(f"[Automation] Match {m.id} transitioned: scheduled -> upcoming")
                
            if now >= t_2h and m.status == "upcoming" and (not m.team1_squad_locked or not m.team2_squad_locked):
                m.status = "playing_xi_pending"
                db.commit()
                logger.info(f"[Automation] Match {m.id} transitioned: upcoming -> playing_xi_pending")
                
            # If both locked, move to ready
            if m.team1_squad_locked and m.team2_squad_locked and m.status in ["scheduled", "upcoming", "playing_xi_pending"]:
                m.status = "ready"
                db.commit()
                logger.info(f"[Automation] Match {m.id} transitioned to ready (both squads locked)")
                
                # Notify Organizer and Captains
                organizers = get_match_organizers(db, m)
                for org_id in organizers:
                    if log_automation_event(db, m.id, "match_ready_organizer", org_id):
                        sendToUser(db, org_id, "Match Ready!", f"Both teams have locked squads for match '{m.venue}'. Match is ready to start.", "MATCH_STARTED", json.dumps({"match_id": str(m.id)}))
                
                for cap_id in get_captains_and_creators(db, m.team1_id) + get_captains_and_creators(db, m.team2_id):
                    if log_automation_event(db, m.id, "match_ready_captain", cap_id):
                        sendToUser(db, cap_id, "Match Ready to Start!", f"Squads are locked. All set for match at '{m.venue}'!", "MATCH_STARTED", json.dumps({"match_id": str(m.id)}))
            
            # --- PART 2: AUTOMATIC REMINDERS ---
            # 1. 24 hours before: Upcoming Match Tomorrow
            if now >= t_24h:
                for cap_id in get_captains_and_creators(db, m.team1_id) + get_captains_and_creators(db, m.team2_id):
                    if log_automation_event(db, m.id, "reminder_24h_captain", cap_id):
                        sendToUser(db, cap_id, "Upcoming Match Tomorrow", f"Reminder: Your match at '{m.venue}' starts tomorrow.", "MATCH_REMINDER", json.dumps({"match_id": str(m.id)}))
                for org_id in get_match_organizers(db, m):
                    if log_automation_event(db, m.id, "reminder_24h_organizer", org_id):
                        sendToUser(db, org_id, "Match Scheduled Tomorrow", f"Reminder: Match you organized at '{m.venue}' starts tomorrow.", "MATCH_REMINDER", json.dumps({"match_id": str(m.id)}))
                        
            # 2. 2 hours before: Captain Reminder
            if now >= t_2h:
                if not m.team1_squad_locked:
                    for cap_id in get_captains_and_creators(db, m.team1_id):
                        if log_automation_event(db, m.id, "reminder_2h_team1", cap_id):
                            sendToUser(db, cap_id, "Captain Reminder: Lock Playing XI", "Please select and lock your Playing XI. 2 hours remaining.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))
                if not m.team2_squad_locked:
                    for cap_id in get_captains_and_creators(db, m.team2_id):
                        if log_automation_event(db, m.id, "reminder_2h_team2", cap_id):
                            sendToUser(db, cap_id, "Captain Reminder: Lock Playing XI", "Please select and lock your Playing XI. 2 hours remaining.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))

            # 3. 30 minutes before: 30m Reminder
            if now >= t_30m:
                if not m.team1_squad_locked:
                    for cap_id in get_captains_and_creators(db, m.team1_id):
                        if log_automation_event(db, m.id, "reminder_30m_team1", cap_id):
                            sendToUser(db, cap_id, "Playing XI Reminder", "Squad selections lock in 30 minutes. Please finalize details.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))
                if not m.team2_squad_locked:
                    for cap_id in get_captains_and_creators(db, m.team2_id):
                        if log_automation_event(db, m.id, "reminder_30m_team2", cap_id):
                            sendToUser(db, cap_id, "Playing XI Reminder", "Squad selections lock in 30 minutes. Please finalize details.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))

            # 4. 10 minutes before: Final 10m Reminder
            if now >= t_10m:
                if not m.team1_squad_locked:
                    for cap_id in get_captains_and_creators(db, m.team1_id):
                        if log_automation_event(db, m.id, "reminder_10m_team1", cap_id):
                            sendToUser(db, cap_id, "Final Reminder: Squad Locks in 10m", "Final warning: select and lock Playing XI now.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))
                if not m.team2_squad_locked:
                    for cap_id in get_captains_and_creators(db, m.team2_id):
                        if log_automation_event(db, m.id, "reminder_10m_team2", cap_id):
                            sendToUser(db, cap_id, "Final Reminder: Squad Locks in 10m", "Final warning: select and lock Playing XI now.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))
                            
            # --- PART 3: AUTO LOCK EXECUTION ---
            if now >= t_autolock:
                executed_autolock = False
                
                # Lock Team 1
                if not m.team1_squad_locked:
                    finalize_squad_auto_lock(db, m.id, m.team1_id)
                    m.team1_squad_locked = True
                    db.commit()
                    executed_autolock = True
                    logger.info(f"[AutoLock] Team 1 auto-locked for match {m.id}")
                    
                    # Notify captain/creator
                    for cap_id in get_captains_and_creators(db, m.team1_id):
                        sendToUser(db, cap_id, "Playing XI Auto Locked", "The deadline expired. Your squad was locked automatically.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))
                    
                    # Notify Organizer
                    for org_id in get_match_organizers(db, m):
                        sendToUser(db, org_id, "Team A Locked (Auto)", f"Team A squad was locked automatically due to deadline for match '{m.venue}'.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))
                
                # Lock Team 2
                if not m.team2_squad_locked:
                    finalize_squad_auto_lock(db, m.id, m.team2_id)
                    m.team2_squad_locked = True
                    db.commit()
                    executed_autolock = True
                    logger.info(f"[AutoLock] Team 2 auto-locked for match {m.id}")
                    
                    # Notify captain/creator
                    for cap_id in get_captains_and_creators(db, m.team2_id):
                        sendToUser(db, cap_id, "Playing XI Auto Locked", "The deadline expired. Your squad was locked automatically.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))
                    
                    # Notify Organizer
                    for org_id in get_match_organizers(db, m):
                        sendToUser(db, org_id, "Team B Locked (Auto)", f"Team B squad was locked automatically due to deadline for match '{m.venue}'.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))
                        
                # Log execution in AutomationLog to prevent re-execution
                if executed_autolock:
                    log_automation_event(db, m.id, "autolock_executed")
                    
                    # Transition match to ready if not live yet
                    if m.status in ["scheduled", "upcoming", "playing_xi_pending"]:
                        m.status = "ready"
                        db.commit()
                        
                    # Notify Organizer overall
                    for org_id in get_match_organizers(db, m):
                        sendToUser(db, org_id, "Auto Lock Executed", f"Squad auto-lock deadline completed. Match '{m.venue}' is now Ready.", "PLAYING_XI", json.dumps({"match_id": str(m.id)}))

        except Exception as err:
            logger.error(f"[Automation Error] Failed executing match day check for match {m.id}: {err}", exc_info=True)
