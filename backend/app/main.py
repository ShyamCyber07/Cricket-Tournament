from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqladmin import Admin

from app.core.config import settings
from app.core.database import engine

from contextlib import asynccontextmanager
from app.models import Base

# Import routers
from app.routers import auth, players, teams, matches, tournaments
from sqlalchemy import text

def patch_database_schema(db_engine):
    try:
        with db_engine.connect() as conn:
            has_changed = False
            
            # 1. Patch players table
            result = conn.execute(text("PRAGMA table_info(players)"))
            columns = [row[1] for row in result.fetchall()]
            new_player_cols = [
                ("career_runs", "INTEGER DEFAULT 0"),
                ("career_wickets", "INTEGER DEFAULT 0"),
                ("matches_played", "INTEGER DEFAULT 0"),
                ("batting_average", "REAL DEFAULT 0.0"),
                ("strike_rate", "REAL DEFAULT 0.0"),
                ("economy", "REAL DEFAULT 0.0"),
                ("highest_score", "INTEGER DEFAULT 0"),
                ("best_bowling_figures", "VARCHAR DEFAULT ''"),
                ("jersey_number", "INTEGER DEFAULT NULL")
            ]
            for col_name, col_type in new_player_cols:
                if col_name not in columns:
                    conn.execute(text(f"ALTER TABLE players ADD COLUMN {col_name} {col_type}"))
                    has_changed = True
            
            # 1b. Ensure unique index on team_players(player_id)
            conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS idx_team_players_player_id ON team_players(player_id)"))
            has_changed = True
            
            # 2. Patch tournaments table
            result_tour = conn.execute(text("PRAGMA table_info(tournaments)"))
            columns_tour = [row[1] for row in result_tour.fetchall()]
            new_tour_cols = [
                ("num_teams", "INTEGER DEFAULT 4"),
                ("status", "VARCHAR DEFAULT 'registration'"),
                ("winner_id", "CHAR(32)")
            ]
            for col_name, col_type in new_tour_cols:
                if col_name not in columns_tour:
                    conn.execute(text(f"ALTER TABLE tournaments ADD COLUMN {col_name} {col_type}"))
                    has_changed = True
            
            # 3. Patch matches table
            result_match = conn.execute(text("PRAGMA table_info(matches)"))
            columns_match = [row[1] for row in result_match.fetchall()]
            new_match_cols = [
                ("tournament_stage", "VARCHAR"),
                ("bracket_code", "VARCHAR")
            ]
            for col_name, col_type in new_match_cols:
                if col_name not in columns_match:
                    conn.execute(text(f"ALTER TABLE matches ADD COLUMN {col_name} {col_type}"))
                    has_changed = True
            
            if has_changed:
                conn.commit()
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
