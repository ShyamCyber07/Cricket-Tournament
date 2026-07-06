import os
import logging
from fastapi.responses import PlainTextResponse
from fastapi.staticfiles import StaticFiles

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
for logger_name in ["", "uvicorn", "uvicorn.access", "uvicorn.error", "app.routers.auth", "app.core.email", "app.main"]:
    l = logging.getLogger(logger_name)
    l.addHandler(memory_handler)
    l.setLevel(logging.INFO)

logger = logging.getLogger(__name__)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqladmin import Admin
from sqladmin.authentication import AuthenticationBackend
from starlette.requests import Request
from starlette.responses import RedirectResponse, Response, FileResponse

from app.core.config import settings
from app.core.database import engine

from contextlib import asynccontextmanager
from app.models import Base

# Import routers
from app.routers import auth, players, teams, matches, tournaments, profile, notifications
from app.routers.admin import router as admin_router



@asynccontextmanager
async def lifespan(app: FastAPI):
    import asyncio
    from app.core.backup import daily_sqlite_backup_loop
    from sqlalchemy.engine import make_url
    from sqlalchemy import inspect, text

    # ---- STARTUP: APP_VERSION (commit SHA) ---------------------------------
    try:
        commit_sha = os.getenv("RAILWAY_GIT_COMMIT_SHA") or os.getenv("GIT_COMMIT_SHA") or "unknown"
        print(f"APP_VERSION = {commit_sha}")
        logger.info(f"APP_VERSION = {commit_sha}")
    except Exception as e:
        print(f"APP_VERSION lookup error: {e}")

    # ---- STARTUP: alembic current version + dialect + table column checks --
    try:
        db_url = make_url(settings.DATABASE_URL)
        dialect = db_url.drivername
        print(f"DATABASE_DIALECT = {dialect}")
        logger.info(f"DATABASE_DIALECT = {dialect}")

        # Read alembic version directly from the DB.
        with engine.connect() as conn:
            try:
                row = conn.execute(text("SELECT version_num FROM alembic_version")).first()
                alembic_ver = row[0] if row else "EMPTY"
            except Exception as e:
                alembic_ver = f"ERROR: {e}"
            print(f"ALEMBIC_VERSION = {alembic_ver}")
            logger.info(f"ALEMBIC_VERSION = {alembic_ver}")

            # Check that critical columns the User model depends on actually
            # exist. This catches the "stale deploy / unrun migration" case
            # where the ORM model references a column the table doesn't have.
            required = {
                "users": [
                    "id", "email", "google_id", "email_verified", "profile_completed",
                    "provider", "role", "is_active", "is_deleted",
                    "joined_at", "created_at",
                ],
                "refresh_tokens": ["id", "user_id", "token", "expires_at", "created_at"],
                "players": ["id", "user_id", "created_by", "name", "role", "batting_style", "bowling_style"],
            }
            insp = inspect(engine)
            for table, cols in required.items():
                if not insp.has_table(table):
                    print(f"SCHEMA_CHECK FAIL: table {table!r} does not exist")
                    logger.error(f"SCHEMA_CHECK FAIL: table {table!r} does not exist")
                    continue
                actual = {c["name"] for c in insp.get_columns(table)}
                missing = [c for c in cols if c not in actual]
                if missing:
                    print(f"SCHEMA_CHECK FAIL: {table} missing columns: {missing}")
                    logger.error(f"SCHEMA_CHECK FAIL: {table} missing columns: {missing}")
                else:
                    print(f"SCHEMA_CHECK OK: {table} has all required columns")
                    logger.info(f"SCHEMA_CHECK OK: {table} has all required columns")
    except Exception as e:
        print(f"Startup schema-check error: {e}", flush=True)
        logger.error(f"Startup schema-check error: {e}", exc_info=True)

    # Dispose engine to release connections before running alembic migration
    engine.dispose()

    # Run Alembic migrations programmatically on startup
    import alembic.config
    import alembic.command
    from alembic.config import Config

    try:
        ini_path = "alembic.ini"
        if not os.path.exists(ini_path):
            ini_path = os.path.join(os.path.dirname(__file__), "..", "alembic.ini")

        if os.path.exists(ini_path):
            if settings.DATABASE_URL.startswith("sqlite"):
                logger.info("SQLite database detected. Skipping programmatic startup migrations to prevent file locks.")
            else:
                logger.info(f"Running database migrations from config: {ini_path}")
                cfg = Config(ini_path)
                cfg.set_main_option("sqlalchemy.url", settings.DATABASE_URL)
                alembic.command.upgrade(cfg, "head")
                logger.info("Database migrations upgraded to head successfully.")
        else:
            logger.warning(f"alembic.ini not found at {ini_path}, skipping startup migrations.")
    except Exception as e:
        logger.error(f"Error running database migrations: {e}", exc_info=True)

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

    # Matchday reminder loop
    def playing_xi_reminder_check_loop(db):
        import json
        from datetime import datetime, timezone, timedelta
        from app.models.cricket import Match, Notification, TeamMember
        
        now = datetime.now(timezone.utc)
        active_matches = db.query(Match).filter(
            Match.status.in_(["scheduled", "toss", "team_selection"]),
            Match.match_date <= now
        ).all()
        
        for m in active_matches:
            if not m.team1_squad_locked:
                match_id_str = str(m.id)
                last_notif = db.query(Notification).filter(
                    Notification.type == "playing_xi_matchday_reminder",
                    Notification.extra_data.like(f"%{match_id_str}%")
                ).order_by(Notification.created_at.desc()).first()
                
                if not last_notif or (now - last_notif.created_at.replace(tzinfo=timezone.utc) if last_notif.created_at.tzinfo is None else now - last_notif.created_at) >= timedelta(hours=6):
                    caps = db.query(TeamMember).filter(
                        TeamMember.team_id == m.team1_id,
                        TeamMember.role == "captain",
                        TeamMember.status == "active"
                    ).all()
                    for cap in caps:
                        notif = Notification(
                            user_id=cap.user_id,
                            title="Final Reminder: Lock Playing XI",
                            message="Playing XI must be locked before Toss.",
                            type="playing_xi_matchday_reminder",
                            extra_data=json.dumps({"match_id": match_id_str})
                        )
                        db.add(notif)
                    db.commit()
                    
            if not m.team2_squad_locked:
                match_id_str = str(m.id)
                last_notif = db.query(Notification).filter(
                    Notification.type == "playing_xi_matchday_reminder",
                    Notification.extra_data.like(f"%{match_id_str}%")
                ).order_by(Notification.created_at.desc()).first()
                
                if not last_notif or (now - last_notif.created_at.replace(tzinfo=timezone.utc) if last_notif.created_at.tzinfo is None else now - last_notif.created_at) >= timedelta(hours=6):
                    caps = db.query(TeamMember).filter(
                        TeamMember.team_id == m.team2_id,
                        TeamMember.role == "captain",
                        TeamMember.status == "active"
                    ).all()
                    for cap in caps:
                        notif = Notification(
                            user_id=cap.user_id,
                            title="Final Reminder: Lock Playing XI",
                            message="Playing XI must be locked before Toss.",
                            type="playing_xi_matchday_reminder",
                            extra_data=json.dumps({"match_id": match_id_str})
                        )
                        db.add(notif)
                    db.commit()

    async def matchday_reminder_notification_loop():
        from app.core.database import SessionLocal
        while True:
            try:
                with SessionLocal() as db:
                    playing_xi_reminder_check_loop(db)
            except Exception as e:
                logger.error(f"Error in matchday reminder loop: {e}", exc_info=True)
            await asyncio.sleep(60) # check every minute

    # Launch daily backup loop in background
    asyncio.create_task(daily_sqlite_backup_loop())
    asyncio.create_task(matchday_reminder_notification_loop())
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
from fastapi import Request, HTTPException
from fastapi.encoders import jsonable_encoder

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    try:
        body = await request.body()
        body_str = body.decode("utf-8")
    except Exception as e:
        body_str = f"Could not decode body: {e}"
        
    errors_list = jsonable_encoder(exc.errors())
    logger.error(f"[ValidationError] Path: {request.url.path} | Request payload: {body_str} | Errors: {errors_list}")
    
    return JSONResponse(
        status_code=422,
        content={"detail": errors_list}
    )

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    logger.error(f"[HTTPException] Path: {request.url.path} | Status: {exc.status_code} | Detail: {exc.detail}")
    return JSONResponse(
        status_code=exc.status_code,
        headers=exc.headers,
        content={"detail": exc.detail}
    )

@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    logger.error(f"[GenericException] Path: {request.url.path} | Error: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": f"Internal Server Error: {str(exc)}"}
    )


# Set up CORS middleware
# Get allowed origins from environment (comma-separated)
allowed_origins_str = os.getenv("ALLOWED_ORIGINS", "")
if settings.APP_ENV.lower() in ["production", "prod"]:
    # In production, require ALLOWED_ORIGINS to be set
    allowed_origins = [origin.strip() for origin in allowed_origins_str.split(",") if origin.strip()]
    if not allowed_origins:
        print("\n" + "="*80)
        print("  WARNING: CORS - ALLOWED_ORIGINS not set in production!")
        print("  Set ALLOWED_ORIGINS env var (comma-separated domains)")
        print("  Defaulting to restrictive CORS - only same origin allowed")
        print("="*80 + "\n")
        allowed_origins = ["http://localhost:3000", "http://127.0.0.1:3000"]
else:
    # Development: allow localhost and common dev ports
    allowed_origins = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:5000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:5000",
        "http://10.0.2.2:8000",  # Android emulator
        "http://10.0.2.2:3000",  # Android emulator
    ]
    if allowed_origins_str:
        allowed_origins.extend([origin.strip() for origin in allowed_origins_str.split(",") if origin.strip()])

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    import time
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    log_line = f"{request.method} {request.url.path} {response.status_code}"
    logger.info(log_line)
    try:
        import os
        os.makedirs("static", exist_ok=True)
        with open("static/requests.log", "a") as f:
            f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {log_line}\n")
    except Exception:
        pass
    return response

# Ensure static directories exist and mount static files
os.makedirs(os.path.join("static", "uploads"), exist_ok=True)

class FallbackStaticFiles(StaticFiles):
    async def get_response(self, path: str, scope) -> Response:
        try:
            return await super().get_response(path, scope)
        except Exception as exc:
            if "uploads" in path:
                fallback_path = os.path.join(self.directory, "fallback_team.png")
                if os.path.exists(fallback_path):
                    return FileResponse(fallback_path)
            raise exc

app.mount("/static", FallbackStaticFiles(directory="static"), name="static")

# Set up SQLAdmin with authentication
class AdminAuthBackend(AuthenticationBackend):
    async def login(self, request: Request) -> Response:
        """Handle admin login - check credentials against admin users"""
        from app.models.user import User
        from app.core.security import verify_password
        from app.core.database import SessionLocal

        username = request.form.get("username", "")
        password = request.form.get("password", "")

        db = SessionLocal()
        try:
            # Check if user exists and is admin
            user = db.query(User).filter(User.email == username).first()
            if user and user.role == "admin" and verify_password(password, user.password_hash):
                # Create simple session - set a cookie
                from app.core.security import create_access_token
                token = create_access_token(str(user.id))
                response = RedirectResponse(request.url_for("admin:index"), status_code=302)
                response.set_cookie(
                    key="cricup_admin_session",
                    value=token,
                    httponly=True,
                    samesite="lax",
                    max_age=60 * 60 * 24  # 24 hours
                )
                return response
            return Response("Invalid credentials", status_code=401)
        finally:
            db.close()

    async def logout(self, request: Request) -> Response:
        response = RedirectResponse(request.url_for("admin:login"))
        response.delete_cookie("cricup_admin_session")
        return response

    async def authenticate(self, request: Request) -> bool:
        """Check if user is authenticated as admin"""
        from jose import jwt, JWTError

        token = request.cookies.get("cricup_admin_session")
        if not token:
            return False

        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
            user_id_str = payload.get("sub")
            if not user_id_str:
                return False

            from app.models.user import User
            from app.core.database import SessionLocal

            db = SessionLocal()
            try:
                user = db.query(User).filter(User.id == user_id_str).first()
                return user is not None and user.role == "admin"
            finally:
                db.close()
        except JWTError:
            return False

# Create admin with authentication
admin = Admin(app, engine, title="CricHeroes Admin Panel")
admin.authentication_backend = AdminAuthBackend(secret_key=settings.SECRET_KEY)

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
        "admin": "/admin",
        "commit_sha": os.getenv("RENDER_GIT_COMMIT") or os.getenv("GIT_COMMIT_SHA") or os.getenv("RAILWAY_GIT_COMMIT_SHA") or "unknown"
    }

@app.get("/api/v1/debug-teams")
def debug_teams(secret: str = None):
    from fastapi import HTTPException
    from app.core.database import SessionLocal
    if secret != "cricup_e2e_secret_2026":
        raise HTTPException(status_code=403, detail="Forbidden")
    from app.models.cricket import Team
    db = SessionLocal()
    try:
        teams = db.query(Team).all()
        result = []
        for t in teams:
            result.append({
                "id": str(t.id),
                "name": t.name,
                "team_code": t.team_code,
                "created_by": str(t.created_by),
                "created_at": str(t.created_at) if t.created_at else None,
            })
        return {
            "total_teams": len(teams),
            "teams": result
        }
    finally:
        db.close()

# Include routers
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(players.router, prefix=f"{settings.API_V1_STR}/players", tags=["players"])
app.include_router(teams.router, prefix=f"{settings.API_V1_STR}/teams", tags=["teams"])
app.include_router(notifications.router, prefix=f"{settings.API_V1_STR}/notifications", tags=["notifications"])
app.include_router(matches.router, prefix=f"{settings.API_V1_STR}/matches", tags=["matches"])
app.include_router(tournaments.router, prefix=f"{settings.API_V1_STR}/tournaments", tags=["tournaments"])
app.include_router(profile.router, prefix=f"{settings.API_V1_STR}/profile", tags=["profile"])
app.include_router(admin_router, prefix=f"{settings.API_V1_STR}", tags=["admin"])


@app.get("/api/v1/debug-logs")
def debug_logs(secret: str = None):
    from fastapi import HTTPException
    # Debug endpoints disabled in production
    if settings.APP_ENV.lower() in ["production", "prod"]:
        raise HTTPException(status_code=404, detail="Not Found")
    # Also check for debug flag
    if os.getenv("ENABLE_DEBUG_ENDPOINTS", "").lower() != "true":
        raise HTTPException(status_code=404, detail="Not Found")
    if secret != "cricup_e2e_secret_2026":
        return PlainTextResponse("Unauthorized", status_code=403)
    return PlainTextResponse(memory_handler.get_logs())

# End of debug routes


@app.get("/api/v1/debug-env")
def debug_env():
    from fastapi import HTTPException
    # Debug endpoints disabled in production
    if settings.APP_ENV.lower() in ["production", "prod"]:
        raise HTTPException(status_code=404, detail="Not Found")
    # Also check for debug flag
    if os.getenv("ENABLE_DEBUG_ENDPOINTS", "").lower() != "true":
        raise HTTPException(status_code=404, detail="Not Found")

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
