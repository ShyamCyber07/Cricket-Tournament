import os
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "Cricket Scorer API"
    API_V1_STR: str = "/api/v1"
    
    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "supersecretkeyforcricketscoringapp2026")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL", 
        "sqlite:///./cricket.db"
    )

    # Brevo API Configurations
    BREVO_API_KEY: str = os.getenv("BREVO_API_KEY", os.getenv("BREVO_SMTP_PASSWORD", "uH9TnpaUep3an3eFqx")).strip().strip("\"'")
    BREVO_FROM_EMAIL: str = os.getenv("BREVO_FROM_EMAIL", "nafa6ilszojywomn@ethereal.email").strip().strip("\"'")
    BREVO_FROM_NAME: str = os.getenv("BREVO_FROM_NAME", "CricUP").strip().strip("\"'")

    # SMTP Configuration (falls back to Ethereal if not set in environment or dotenv)
    BREVO_SMTP_HOST: str = os.getenv("BREVO_SMTP_HOST", "smtp.ethereal.email")
    BREVO_SMTP_PORT: int = int(os.getenv("BREVO_SMTP_PORT", "587"))
    BREVO_SMTP_USER: str = os.getenv("BREVO_SMTP_USER", "nafa6ilszojywomn@ethereal.email")
    BREVO_SMTP_PASSWORD: str = os.getenv("BREVO_SMTP_PASSWORD", "uH9TnpaUep3an3eFqx")

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

    model_config = SettingsConfigDict(
        case_sensitive=True,
        env_file=".env",
        env_file_encoding="utf-8"
    )

settings = Settings()

