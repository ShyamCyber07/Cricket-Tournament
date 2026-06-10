from sqladmin import ModelView
from app.models.user import User
from app.models.cricket import Player, Team, Tournament, Match, MatchSquad, Innings, Ball

class UserAdmin(ModelView, model=User):
    column_list = [User.id, User.email, User.full_name, User.created_at]
    column_searchable_list = [User.email, User.full_name]
    icon = "fa-solid fa-user"
    name = "User"
    name_plural = "Users"

class PlayerAdmin(ModelView, model=Player):
    column_list = [Player.id, Player.name, Player.role, Player.batting_style, Player.bowling_style]
    column_searchable_list = [Player.name]
    icon = "fa-solid fa-users-rectangle"
    name = "Player"
    name_plural = "Players"

class TeamAdmin(ModelView, model=Team):
    column_list = [Team.id, Team.name, Team.created_by, Team.created_at]
    column_searchable_list = [Team.name]
    icon = "fa-solid fa-people-group"
    name = "Team"
    name_plural = "Teams"

class TournamentAdmin(ModelView, model=Tournament):
    column_list = [Tournament.id, Tournament.name, Tournament.format, Tournament.start_date, Tournament.end_date]
    column_searchable_list = [Tournament.name]
    icon = "fa-solid fa-trophy"
    name = "Tournament"
    name_plural = "Tournaments"

class MatchAdmin(ModelView, model=Match):
    column_list = [Match.id, Match.venue, Match.status, Match.match_type, Match.match_date]
    column_searchable_list = [Match.venue, Match.status]
    icon = "fa-solid fa-baseball-bat-ball"
    name = "Match"
    name_plural = "Matches"

class MatchSquadAdmin(ModelView, model=MatchSquad):
    column_list = [MatchSquad.match_id, MatchSquad.team_id, MatchSquad.player_id, MatchSquad.is_playing_xi]
    icon = "fa-solid fa-clipboard-user"
    name = "Match Squad"
    name_plural = "Match Squads"

class InningsAdmin(ModelView, model=Innings):
    column_list = [Innings.id, Innings.match_id, Innings.innings_number, Innings.total_runs, Innings.total_wickets, Innings.total_overs]
    icon = "fa-solid fa-calculator"
    name = "Innings"
    name_plural = "Innings Records"

class BallAdmin(ModelView, model=Ball):
    column_list = [Ball.id, Ball.innings_id, Ball.over_number, Ball.ball_number, Ball.runs_batsman, Ball.runs_extras, Ball.is_wicket]
    icon = "fa-solid fa-circle"
    name = "Ball Log"
    name_plural = "Ball Logs"
