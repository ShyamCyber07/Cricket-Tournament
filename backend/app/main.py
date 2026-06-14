import os
import logging
from fastapi.responses import PlainTextResponse

class MemoryHandler(logging.Handler):
    def __init__(self, capacity=2000):
        super().__init__()
        self.capacity = capacity
        self.buffer = []

    def emit(self, record):
        self.buffer.append(self.format(record))
        if len(self.buffer) > self.capacity:
            self.buffer.pop(0)

    def get_logs(self):
        return "\n".join(self.buffer)

memory_handler = MemoryHandler()
memory_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))

# Hook into root and uvicorn loggers to intercept production outputs
for logger_name in ["", "uvicorn", "uvicorn.access", "uvicorn.error", "app.routers.auth", "app.core.email"]:
    l = logging.getLogger(logger_name)
    l.addHandler(memory_handler)
    l.setLevel(logging.INFO)

logger = logging.getLogger(__name__)

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
                if is_postgres:
                    conn.execute(text("UPDATE users SET email_verified = TRUE WHERE email_verified IS NULL OR email_verified = FALSE"))
                    conn.execute(text("UPDATE users SET profile_completed = TRUE WHERE profile_completed IS NULL OR profile_completed = FALSE"))
                else:
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
    import asyncio
    from app.core.backup import daily_sqlite_backup_loop
    from sqlalchemy.engine import make_url
    
    try:
        db_url = make_url(settings.DATABASE_URL)
        print("Database Dialect:", db_url.drivername)
        print("DATABASE_DIALECT =", db_url.drivername)
        print("DATABASE_HOST =", db_url.host)
        print("DATABASE_NAME =", db_url.database)
        if settings.DATABASE_URL.startswith("sqlite"):
            print("DATABASE_URL =", settings.DATABASE_URL)
    except Exception as e:
        print("Error parsing database URL diagnostics:", e)
        
    print("SMTP_HOST =", settings.BREVO_SMTP_HOST)
    print("SMTP_PORT =", settings.BREVO_SMTP_PORT)
    print("SMTP_USER =", settings.BREVO_SMTP_USER)
    print("FROM_EMAIL =", settings.BREVO_FROM_EMAIL)
    
    # Production SQLite warning
    if settings.DATABASE_URL.startswith("sqlite") and settings.APP_ENV.lower() in ["production", "prod"]:
        print("\n" + "="*80)
        print("  WARNING: RUNNING WITH SQLITE IN PRODUCTION!")
        print("  SQLite is not recommended for production environments due to potential data")
        print("  loss, concurrency limits, and ephemeral filesystem on Railway.")
        print("  Please migrate to PostgreSQL as soon as possible.")
        print("="*80 + "\n")
        
    import os
    env_keys = sorted(list(os.environ.keys()))
    logger.info(f"Loaded environment variables: {', '.join(env_keys)}")
    
    # settings prefix print
    logger.info(f"BREVO_API_KEY_PREFIX={settings.BREVO_API_KEY[:10] if settings.BREVO_API_KEY else 'None'}")
    logger.info(f"BREVO_SMTP_PASSWORD_PREFIX={settings.BREVO_SMTP_PASSWORD[:10] if settings.BREVO_SMTP_PASSWORD else 'None'}")
    
    # raw os prefix print
    raw_api_key = os.getenv("BREVO_API_KEY")
    raw_smtp_password = os.getenv("BREVO_SMTP_PASSWORD")
    logger.info(f"RAW_BREVO_API_KEY_PREFIX={raw_api_key[:10] if raw_api_key else 'None'}")
    logger.info(f"RAW_BREVO_SMTP_PASSWORD_PREFIX={raw_smtp_password[:10] if raw_smtp_password else 'None'}")

    # Launch daily backup loop in background
    asyncio.create_task(daily_sqlite_backup_loop())
    
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

from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi import Request
from fastapi.encoders import jsonable_encoder

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    try:
        body = await request.body()
        body_str = body.decode("utf-8")
    except Exception as e:
        body_str = f"Could not decode body: {e}"
        
    errors_list = jsonable_encoder(exc.errors())
    print(f"[ValidationError] Path: {request.url.path}")
    print(f"[ValidationError] Request payload: {body_str}")
    print(f"[ValidationError] Errors: {errors_list}")
    
    return JSONResponse(
        status_code=422,
        content={"detail": errors_list}
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

@app.get("/api/v1/debug-logs")
def debug_logs(secret: str = None):
    if secret != "cricup_e2e_secret_2026":
        return PlainTextResponse("Unauthorized", status_code=403)
    return PlainTextResponse(memory_handler.get_logs())


@app.get("/api/v1/debug-env")
def debug_env():
    # 1. Print prefixes to logs
    logger.info(f"DIAGNOSTIC - BREVO_API_KEY_PREFIX={settings.BREVO_API_KEY[:10] if settings.BREVO_API_KEY else 'None'}")
    logger.info(f"DIAGNOSTIC - RAW_BREVO_API_KEY_PREFIX={os.getenv('BREVO_API_KEY')[:10] if os.getenv('BREVO_API_KEY') else 'None'}")
    
    # 2. Test Brevo API account endpoint directly
    import httpx
    account_status = None
    account_body = None
    try:
        headers = {
            "api-key": settings.BREVO_API_KEY,
            "accept": "application/json"
        }
        with httpx.Client(timeout=10.0) as client:
            res = client.get("https://api.brevo.com/v3/account", headers=headers)
            account_status = res.status_code
            account_body = res.text
            logger.info(f"DIAGNOSTIC - BREVO account status: {res.status_code}")
            logger.info(f"DIAGNOSTIC - BREVO account response: {res.text}")
    except Exception as e:
        account_status = 500
        account_body = f"Error: {str(e)}"
        logger.error(f"DIAGNOSTIC - BREVO account error: {str(e)}")

    return {
        "APP_ENV": settings.APP_ENV,
        "BREVO_FROM_EMAIL": settings.BREVO_FROM_EMAIL,
        "BREVO_FROM_NAME": settings.BREVO_FROM_NAME,
        "BREVO_API_KEY_prefix": settings.BREVO_API_KEY[:12] if settings.BREVO_API_KEY else None,
        "BREVO_API_KEY_suffix": settings.BREVO_API_KEY[-6:] if settings.BREVO_API_KEY else None,
        "BREVO_API_KEY_len": len(settings.BREVO_API_KEY) if settings.BREVO_API_KEY else 0,
        "BREVO_SMTP_PASSWORD_len": len(settings.BREVO_SMTP_PASSWORD) if settings.BREVO_SMTP_PASSWORD else 0,
        "BREVO_SMTP_USER": settings.BREVO_SMTP_USER,
        "RAILWAY_SERVICE_NAME": os.getenv("RAILWAY_SERVICE_NAME"),
        "RAILWAY_DEPLOYMENT_ID": os.getenv("RAILWAY_DEPLOYMENT_ID"),
        "RAILWAY_ENVIRONMENT_NAME": os.getenv("RAILWAY_ENVIRONMENT_NAME"),
        "RAILWAY_PROJECT_NAME": os.getenv("RAILWAY_PROJECT_NAME"),
        "BREVO_ACCOUNT_TEST_STATUS": account_status,
        "BREVO_ACCOUNT_TEST_BODY": account_body,
    }
