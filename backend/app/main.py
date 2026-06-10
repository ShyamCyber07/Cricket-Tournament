from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqladmin import Admin

from app.core.config import settings
from app.core.database import engine

from contextlib import asynccontextmanager
from app.models import Base

# Import routers
from app.routers import auth, players, teams, matches, tournaments

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Auto-create tables on startup (great for development)
    Base.metadata.create_all(bind=engine)
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
