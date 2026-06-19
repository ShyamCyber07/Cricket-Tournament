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

    # Environment
    APP_ENV: str = os.getenv("APP_ENV", "development")

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def assemble_db_connection(cls, v: str) -> str:
        if isinstance(v, str) and v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql://", 1)
        return v

    @model_validator(mode="after")
    def validate_security(self):
        app_env = self.APP_ENV.lower() if self.APP_ENV else "development"

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

