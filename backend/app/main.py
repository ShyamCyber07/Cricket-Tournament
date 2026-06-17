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

from app.core.config import settings
from app.core.database import engine

from contextlib import asynccontextmanager
from app.models import Base

# Import routers
from app.routers import auth, players, teams, matches, tournaments, profile


@asynccontextmanager
async def lifespan(app: FastAPI):
    import asyncio
    from app.core.backup import daily_sqlite_backup_loop
    from sqlalchemy.engine import make_url
    
    # Run Alembic migrations programmatically on startup
    import alembic.config
    import alembic.command
    from alembic.config import Config
    
    try:
        ini_path = "alembic.ini"
        if not os.path.exists(ini_path):
            ini_path = os.path.join(os.path.dirname(__file__), "..", "alembic.ini")
            
        if os.path.exists(ini_path):
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

    # Launch daily backup loop in background
    asyncio.create_task(daily_sqlite_backup_loop())
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
app.add_middleware(

    CORSMiddleware,
    allow_origins=["*"],  # Adjust for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure static directories exist and mount static files
os.makedirs(os.path.join("static", "uploads"), exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

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
app.include_router(profile.router, prefix=f"{settings.API_V1_STR}/profile", tags=["profile"])

@app.get("/api/v1/debug-logs")
def debug_logs(secret: str = None):
    from fastapi import HTTPException
    if settings.APP_ENV.lower() in ["production", "prod"]:
        raise HTTPException(status_code=404, detail="Not Found")
    if secret != "cricup_e2e_secret_2026":
        return PlainTextResponse("Unauthorized", status_code=403)
    return PlainTextResponse(memory_handler.get_logs())

# End of debug routes


@app.get("/api/v1/debug-env")
def debug_env():
    from fastapi import HTTPException
    if settings.APP_ENV.lower() in ["production", "prod"]:
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
