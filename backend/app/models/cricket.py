import uuid
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer, Boolean, Float, Date
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.core.database import Base

class TeamPlayer(Base):
    __tablename__ = "team_players"

    team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="CASCADE"), primary_key=True)
    player_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="CASCADE"), primary_key=True, unique=True)
    joined_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class TeamMember(Base):
    __tablename__ = "team_members"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role = Column(String, default="player", nullable=False)  # captain/player
    joined_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    status = Column(String, default="active", nullable=False)  # active/pending

    # Relationships
    team = relationship("Team", back_populates="members")
    user = relationship("User")

class TournamentTeam(Base):
    __tablename__ = "tournament_teams"

    tournament_id = Column(UUID(as_uuid=True), ForeignKey("tournaments.id", ondelete="CASCADE"), primary_key=True)
    team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="CASCADE"), primary_key=True)

class Player(Base):
    __tablename__ = "players"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    name = Column(String, nullable=False)
    role = Column(String, nullable=False) # batsman, bowler, all_rounder, wicket_keeper
    batting_style = Column(String, nullable=False) # right_hand, left_hand
    bowling_style = Column(String, nullable=False) # right_arm_fast, right_arm_spin, etc.
    profile_photo_url = Column(String, nullable=True)
    jersey_number = Column(Integer, nullable=True)

    # Career Stats
    career_runs = Column(Integer, default=0, nullable=True)
    career_wickets = Column(Integer, default=0, nullable=True)
    matches_played = Column(Integer, default=0, nullable=True)
    batting_average = Column(Float, default=0.0, nullable=True)
    strike_rate = Column(Float, default=0.0, nullable=True)
    economy = Column(Float, default=0.0, nullable=True)
    highest_score = Column(Integer, default=0, nullable=True)
    best_bowling_figures = Column(String, default="", nullable=True)

    # Relationships - Removed problematic User.back_populates="players" reference
    teams = relationship("Team", secondary="team_players", back_populates="players")

    def to_dict(self):
        return {
            "id": str(self.id),
            "name": self.name,
            "role": self.role,
            "batting_style": self.batting_style,
            "bowling_style": self.bowling_style,
            "profile_photo_url": self.profile_photo_url,
            "jersey_number": self.jersey_number,
            "career_runs": self.career_runs,
            "career_wickets": self.career_wickets,
            "matches_played": self.matches_played,
            "batting_average": self.batting_average,
            "strike_rate": self.strike_rate,
            "economy": self.economy,
            "highest_score": self.highest_score,
            "best_bowling_figures": self.best_bowling_figures,
        }

class Team(Base):
    __tablename__ = "teams"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, index=True, nullable=False)  # Unique per user, not globally
    logo_url = Column(String, nullable=True)
    captain_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="SET NULL"), nullable=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    creator = relationship("User", back_populates="created_teams")
    players = relationship("Player", secondary="team_players", back_populates="teams")
    tournaments = relationship("Tournament", secondary="tournament_teams", back_populates="teams")
    members = relationship("TeamMember", back_populates="team", cascade="all, delete-orphan")

class Tournament(Base):
    __tablename__ = "tournaments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    organizer_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    format = Column(String, nullable=False) # League, Knockout, League + Knockout
    num_teams = Column(Integer, nullable=False, default=4)
    status = Column(String, default="registration", nullable=False) # registration, ongoing, completed
    winner_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="SET NULL"), nullable=True)
    banner_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    organizer = relationship("User", back_populates="organized_tournaments", foreign_keys=[organizer_id])
    teams = relationship("Team", secondary="tournament_teams", back_populates="tournaments")
    matches = relationship("Match", back_populates="tournament")
    winner = relationship("Team", foreign_keys=[winner_id])

class Match(Base):
    __tablename__ = "matches"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tournament_id = Column(UUID(as_uuid=True), ForeignKey("tournaments.id", ondelete="SET NULL"), nullable=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    assigned_scorer_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    team1_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False)
    team2_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False)
    match_date = Column(DateTime, nullable=False)
    venue = Column(String, nullable=False)
    status = Column(String, default="scheduled") # scheduled, toss, team_selection, innings1, innings2, completed, abandoned
    match_type = Column(String, nullable=False) # T20, ODI, Test, Custom
    over_limit = Column(Integer, nullable=False)
    toss_winner_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="SET NULL"), nullable=True)
    toss_decision = Column(String, nullable=True) # bat, bowl
    winner_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="SET NULL"), nullable=True)
    win_margin_runs = Column(Integer, nullable=True)
    win_margin_wickets = Column(Integer, nullable=True)
    
    # Tournament structures
    tournament_stage = Column(String, nullable=True) # league, quarter_final, semi_final, final
    bracket_code = Column(String, nullable=True) # QF1, QF2, QF3, QF4, SF1, SF2, F
    
    # Active Scorer State Cache (nullable when not in live scoring mode)
    current_striker_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="SET NULL"), nullable=True)
    current_non_striker_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="SET NULL"), nullable=True)
    current_bowler_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="SET NULL"), nullable=True)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    tournament = relationship("Tournament", back_populates="matches")
    team1 = relationship("Team", foreign_keys=[team1_id])
    team2 = relationship("Team", foreign_keys=[team2_id])
    toss_winner = relationship("Team", foreign_keys=[toss_winner_id])
    winner = relationship("Team", foreign_keys=[winner_id])
    squads = relationship("MatchSquad", back_populates="match", cascade="all, delete-orphan")
    innings = relationship("Innings", back_populates="match", cascade="all, delete-orphan")

    @property
    def team1_name(self) -> Optional[str]:
        return self.team1.name if self.team1 else None

    @property
    def team2_name(self) -> Optional[str]:
        return self.team2.name if self.team2 else None

    @property
    def team1_logo_url(self) -> Optional[str]:
        return self.team1.logo_url if self.team1 else None

    @property
    def team2_logo_url(self) -> Optional[str]:
        return self.team2.logo_url if self.team2 else None


class MatchSquad(Base):
    __tablename__ = "match_squads"

    match_id = Column(UUID(as_uuid=True), ForeignKey("matches.id", ondelete="CASCADE"), primary_key=True)
    team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="CASCADE"), primary_key=True)
    player_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    is_playing_xi = Column(Boolean, default=True)
    is_captain = Column(Boolean, default=False)
    is_wicketkeeper = Column(Boolean, default=False)

    # Relationships
    match = relationship("Match", back_populates="squads")
    player = relationship("Player")
    team = relationship("Team")

class Innings(Base):
    __tablename__ = "innings"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    match_id = Column(UUID(as_uuid=True), ForeignKey("matches.id", ondelete="CASCADE"), nullable=False)
    innings_number = Column(Integer, nullable=False) # 1 or 2
    batting_team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False)
    bowling_team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False)
    total_runs = Column(Integer, default=0)
    total_wickets = Column(Integer, default=0)
    total_overs = Column(Float, default=0.0) # represented as e.g. 15.4 for 15 overs and 4 balls
    extras_byes = Column(Integer, default=0)
    extras_legbyes = Column(Integer, default=0)
    extras_wides = Column(Integer, default=0)
    extras_noballs = Column(Integer, default=0)
    is_completed = Column(Boolean, default=False)

    # Relationships
    match = relationship("Match", back_populates="innings")
    batting_team = relationship("Team", foreign_keys=[batting_team_id])
    bowling_team = relationship("Team", foreign_keys=[bowling_team_id])
    balls = relationship("Ball", back_populates="innings", cascade="all, delete-orphan", order_by="Ball.created_at")

class Ball(Base):
    __tablename__ = "balls"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    innings_id = Column(UUID(as_uuid=True), ForeignKey("innings.id", ondelete="CASCADE"), nullable=False)
    over_number = Column(Integer, nullable=False) # 1-indexed over number
    ball_number = Column(Integer, nullable=False) # 1-indexed ball in that over (excluding/including extras depending on rules, standard raw count)
    bowler_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="CASCADE"), nullable=False)
    batsman_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="CASCADE"), nullable=False)
    non_striker_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="CASCADE"), nullable=False)
    runs_batsman = Column(Integer, default=0)
    runs_extras = Column(Integer, default=0)
    extra_type = Column(String, default="none") # wide, no_ball, bye, leg_bye, none
    is_wicket = Column(Boolean, default=False)
    wicket_type = Column(String, nullable=True) # bowled, caught, lbw, run_out, stumped, hit_wicket, retired_hurt, none
    player_dismissed_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="SET NULL"), nullable=True)
    fielder_id = Column(UUID(as_uuid=True), ForeignKey("players.id", ondelete="SET NULL"), nullable=True)
    commentary = Column(String, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    innings = relationship("Innings", back_populates="balls")
    bowler = relationship("Player", foreign_keys=[bowler_id])
    batsman = relationship("Player", foreign_keys=[batsman_id])
    non_striker = relationship("Player", foreign_keys=[non_striker_id])
    player_dismissed = relationship("Player", foreign_keys=[player_dismissed_id])
    fielder = relationship("Player", foreign_keys=[fielder_id])
