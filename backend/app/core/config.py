import os
import secrets
from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "Cricket Scorer API"
    API_V1_STR: str = "/api/v1"

    # Security - SECRET_KEY validation handled in model_validator
    SECRET_KEY: str = ""
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "sqlite:///./cricket.db"
    )

    # Match Day Automation timining configurations (in hours/minutes)
    REMINDER_24H_OFFSET_HOURS: int = 24
    REMINDER_2H_OFFSET_HOURS: int = 2
    REMINDER_30M_OFFSET_MINUTES: int = 30
    REMINDER_10M_OFFSET_MINUTES: int = 10
    AUTO_LOCK_OFFSET_MINUTES: int = 0

    # Brevo API Configurations - production requires these to be set
    BREVO_API_KEY: str = os.getenv("BREVO_API_KEY", "").strip().strip("\"'")
    BREVO_FROM_EMAIL: str = os.getenv("BREVO_FROM_EMAIL", "").strip().strip("\"'")
    BREVO_FROM_NAME: str = os.getenv("BREVO_FROM_NAME", "CricUP").strip().strip("\"'")

    # SMTP Configuration - defaults for development only
    BREVO_SMTP_HOST: str = os.getenv("BREVO_SMTP_HOST", "smtp.ethereal.email")
    BREVO_SMTP_PORT: int = int(os.getenv("BREVO_SMTP_PORT", "587"))
    BREVO_SMTP_USER: str = os.getenv("BREVO_SMTP_USER", "")
    BREVO_SMTP_PASSWORD: str = os.getenv("BREVO_SMTP_PASSWORD", "")

    # Google OAuth
    GOOGLE_CLIENT_ID: str | None = os.getenv("GOOGLE_CLIENT_ID", None)

    # Cloudinary Persistent Storage Configuration
    CLOUDINARY_URL: str = os.getenv("CLOUDINARY_URL", "")
    CLOUDINARY_CLOUD_NAME: str = os.getenv("CLOUDINARY_CLOUD_NAME", "")
    CLOUDINARY_API_KEY: str = os.getenv("CLOUDINARY_API_KEY", "")
    CLOUDINARY_API_SECRET: str = os.getenv("CLOUDINARY_API_SECRET", "")

    # Environment
    APP_ENV: str = os.getenv("APP_ENV", os.getenv("ENV", "development"))

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def assemble_db_connection(cls, v: str) -> str:
        if isinstance(v, str) and v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql://", 1)
        return v

    @model_validator(mode="after")
    def validate_security(self):
        # Extract Cloudinary credentials from CLOUDINARY_URL if they are not explicitly set
        parsed_via_url = False
        if self.CLOUDINARY_URL and not (self.CLOUDINARY_CLOUD_NAME and self.CLOUDINARY_API_KEY and self.CLOUDINARY_API_SECRET):
            try:
                import urllib.parse
                url_parsed = urllib.parse.urlparse(self.CLOUDINARY_URL)
                if url_parsed.scheme == "cloudinary":
                    self.CLOUDINARY_API_KEY = url_parsed.username or ""
                    self.CLOUDINARY_API_SECRET = url_parsed.password or ""
                    self.CLOUDINARY_CLOUD_NAME = url_parsed.hostname or ""
                    parsed_via_url = True
            except Exception as e:
                print(f"[STARTUP] Warning: Failed parsing CLOUDINARY_URL: {e}")

        # Clear logs about the config method
        if parsed_via_url:
            print(f"[STARTUP] Cloudinary configured using Method A: CLOUDINARY_URL (Cloud Name parsed: {self.CLOUDINARY_CLOUD_NAME})")
        elif self.CLOUDINARY_CLOUD_NAME and self.CLOUDINARY_API_KEY and self.CLOUDINARY_API_SECRET:
            print(f"[STARTUP] Cloudinary configured using Method B: Separate credentials (Cloud Name: {self.CLOUDINARY_CLOUD_NAME})")
        else:
            print("[STARTUP] Cloudinary configuration missing or incomplete.")

        app_env = self.APP_ENV.lower() if self.APP_ENV else "development"

        # Verify Cloudinary configuration in production mode
        if app_env in ["production", "prod"]:
            missing_vars = []
            if not self.CLOUDINARY_CLOUD_NAME:
                missing_vars.append("CLOUDINARY_CLOUD_NAME (or host in CLOUDINARY_URL)")
            if not self.CLOUDINARY_API_KEY:
                missing_vars.append("CLOUDINARY_API_KEY (or username in CLOUDINARY_URL)")
            if not self.CLOUDINARY_API_SECRET:
                missing_vars.append("CLOUDINARY_API_SECRET (or password in CLOUDINARY_URL)")

            if missing_vars:
                print("\n" + "="*80)
                print("  ERROR: Cloudinary configuration is missing or incomplete.")
                print(f"  Missing fields: {', '.join(missing_vars)}")
                print("  Please configure CLOUDINARY_URL or CLOUDINARY_CLOUD_NAME/API_KEY/API_SECRET.")
                print("="*80 + "\n")
                # Graceful exit with exit code 1 to avoid raw Pydantic validation tracebacks
                import sys
                sys.exit(1)

        # Check SECRET_KEY
        if not self.SECRET_KEY:
            if app_env in ["production", "prod"]:
                # WARNING: Generate a key but warn loudly
                self.SECRET_KEY = secrets.token_urlsafe(32)
                print("\n" + "="*80)
                print("  WARNING: SECRET_KEY not set in production!")
                print("  Using auto-generated key (sessions will be invalid on restart)")
                print("  Set SECRET_KEY environment variable for persistent sessions")
                print("="*80 + "\n")
            else:
                # Generate random key for development
                self.SECRET_KEY = secrets.token_urlsafe(32)
                print(f"\n[DEV] Generated random SECRET_KEY for development")

        return self

    model_config = SettingsConfigDict(
        case_sensitive=True,
        env_file=".env",
        env_file_encoding="utf-8"
    )

settings = Settings()

