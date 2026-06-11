from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqladmin import Admin

from app.core.config import settings
from app.core.database import engine

from contextlib import asynccontextmanager
from app.models import Base

# Import routers
from app.routers import auth, players, teams, matches, tournaments
from sqlalchemy import inspect, text

def patch_database_schema(db_engine):
    try:
        inspector = inspect(db_engine)
        is_postgres = db_engine.dialect.name == 'postgresql'
        uuid_type = "UUID" if is_postgres else "CHAR(32)"
        
        # 0. Patch users table
        if 'users' in inspector.get_table_names():
            columns_user = [col['name'] for col in inspector.get_columns('users')]
            bool_type = "BOOLEAN DEFAULT FALSE" if is_postgres else "BOOLEAN DEFAULT 0"
            int_type = "INTEGER DEFAULT 0"
            timestamp_type = "TIMESTAMP" if is_postgres else "DATETIME"
            
            new_user_cols = [
                ("username", "VARCHAR DEFAULT NULL"),
                ("display_name", "VARCHAR DEFAULT NULL"),
                ("profile_picture", "VARCHAR DEFAULT NULL"),
                ("email_verified", bool_type),
                ("profile_completed", bool_type),
                ("provider", "VARCHAR DEFAULT 'local'"),
                ("otp_code", "VARCHAR DEFAULT NULL"),
                ("otp_expiry", timestamp_type),
                ("last_login", timestamp_type),
                ("failed_login_attempts", int_type),
                ("lockout_until", timestamp_type),
                ("last_otp_sent_at", timestamp_type)
            ]
            with db_engine.begin() as conn:
                for col_name, col_type in new_user_cols:
                    if col_name not in columns_user:
                        conn.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}"))
                if is_postgres:
                    try:
                        conn.execute(text("ALTER TABLE users ALTER COLUMN full_name DROP NOT NULL"))
                        conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username)"))
                    except Exception:
                        pass
                else:
                    try:
                        conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username)"))
                    except Exception:
                        pass
            
            # Backwards compatibility migration for legacy users
            with db_engine.begin() as conn:
                conn.execute(text("UPDATE users SET username = email WHERE username IS NULL"))
                conn.execute(text("UPDATE users SET email_verified = 1 WHERE email_verified IS NULL OR email_verified = 0"))
                conn.execute(text("UPDATE users SET profile_completed = 1 WHERE profile_completed IS NULL OR profile_completed = 0"))

        # 1. Patch players table
        if 'players' in inspector.get_table_names():
            columns = [col['name'] for col in inspector.get_columns('players')]
            new_player_cols = [
                ("career_runs", "INTEGER DEFAULT 0"),
                ("career_wickets", "INTEGER DEFAULT 0"),
                ("matches_played", "INTEGER DEFAULT 0"),
                ("batting_average", "REAL DEFAULT 0.0"),
                ("strike_rate", "REAL DEFAULT 0.0"),
                ("economy", "REAL DEFAULT 0.0"),
                ("highest_score", "INTEGER DEFAULT 0"),
                ("best_bowling_figures", "VARCHAR DEFAULT ''"),
                ("jersey_number", "INTEGER DEFAULT NULL"),
                ("created_by", f"{uuid_type} DEFAULT NULL")
            ]
            with db_engine.begin() as conn:
                for col_name, col_type in new_player_cols:
                    if col_name not in columns:
                        conn.execute(text(f"ALTER TABLE players ADD COLUMN {col_name} {col_type}"))
                
                # 1b. Ensure unique index on team_players(player_id)
                conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS idx_team_players_player_id ON team_players(player_id)"))
            
        # 2. Patch tournaments table
        if 'tournaments' in inspector.get_table_names():
            columns_tour = [col['name'] for col in inspector.get_columns('tournaments')]
            new_tour_cols = [
                ("num_teams", "INTEGER DEFAULT 4"),
                ("status", "VARCHAR DEFAULT 'registration'"),
                ("winner_id", f"{uuid_type}"),
                ("created_by", f"{uuid_type} DEFAULT NULL")
            ]
            with db_engine.begin() as conn:
                for col_name, col_type in new_tour_cols:
                    if col_name not in columns_tour:
                        conn.execute(text(f"ALTER TABLE tournaments ADD COLUMN {col_name} {col_type}"))
            
        # 3. Patch matches table
        if 'matches' in inspector.get_table_names():
            columns_match = [col['name'] for col in inspector.get_columns('matches')]
            new_match_cols = [
                ("tournament_stage", "VARCHAR"),
                ("bracket_code", "VARCHAR"),
                ("created_by", f"{uuid_type} DEFAULT NULL")
            ]
            with db_engine.begin() as conn:
                for col_name, col_type in new_match_cols:
                    if col_name not in columns_match:
                        conn.execute(text(f"ALTER TABLE matches ADD COLUMN {col_name} {col_type}"))

        # 4. Migrate null created_by fields to enforce backwards compatibility
        with db_engine.begin() as conn:
            # Tournaments organizer -> created_by
            conn.execute(text("UPDATE tournaments SET created_by = organizer_id WHERE created_by IS NULL"))
            # Matches in tournaments
            conn.execute(text("UPDATE matches SET created_by = (SELECT organizer_id FROM tournaments WHERE tournaments.id = matches.tournament_id) WHERE tournament_id IS NOT NULL AND created_by IS NULL"))
            # Matches outside tournaments (default to team1 creator)
            conn.execute(text("UPDATE matches SET created_by = (SELECT created_by FROM teams WHERE teams.id = matches.team1_id) WHERE created_by IS NULL"))
            # Players linked to a user
            conn.execute(text("UPDATE players SET created_by = user_id WHERE user_id IS NOT NULL AND created_by IS NULL"))
            # Fallback for remaining players (default to first user)
            conn.execute(text("UPDATE players SET created_by = (SELECT id FROM users LIMIT 1) WHERE created_by IS NULL"))

    except Exception as e:
        print(f"Error patching database schema: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Auto-create tables on startup (great for development)
    Base.metadata.create_all(bind=engine)
    # Patch schema to add columns to existing tables
    patch_database_schema(engine)
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    lifespan=lifespan,
)

# Set up CORS middleware
app.add_middleware(

    CORSMiddleware,
    allow_origins=["*"],  # Adjust for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Set up SQLAdmin
admin = Admin(app, engine, title="CricHeroes Admin Panel")

# Register admin views
from app.admin.views import (
    UserAdmin,
    PlayerAdmin,
    TeamAdmin,
    TournamentAdmin,
    MatchAdmin,
    MatchSquadAdmin,
    InningsAdmin,
    BallAdmin
)

admin.add_view(UserAdmin)
admin.add_view(PlayerAdmin)
admin.add_view(TeamAdmin)
admin.add_view(TournamentAdmin)
admin.add_view(MatchAdmin)
admin.add_view(MatchSquadAdmin)
admin.add_view(InningsAdmin)
admin.add_view(BallAdmin)

@app.get("/")
def read_root():
    return {
        "message": f"Welcome to {settings.PROJECT_NAME}!",
        "docs": f"{settings.API_V1_STR}/docs",
        "admin": "/admin"
    }

# Include routers
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(players.router, prefix=f"{settings.API_V1_STR}/players", tags=["players"])
app.include_router(teams.router, prefix=f"{settings.API_V1_STR}/teams", tags=["teams"])
app.include_router(matches.router, prefix=f"{settings.API_V1_STR}/matches", tags=["matches"])
app.include_router(tournaments.router, prefix=f"{settings.API_V1_STR}/tournaments", tags=["tournaments"])
