import os
import sys

# Add backend to path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__) + '/../backend'))

from alembic.config import Config
from alembic import command
from app.core.config import settings

print("DATABASE_URL:", settings.DATABASE_URL)
ini_path = "alembic.ini" if os.path.exists("alembic.ini") else "backend/alembic.ini"
if os.path.exists(ini_path):
    print("Found alembic.ini")
    cfg = Config(ini_path)
    cfg.set_main_option("sqlalchemy.url", settings.DATABASE_URL)
    try:
        command.upgrade(cfg, "head")
        print("Success running alembic upgrade!")
    except Exception as e:
        print("Error running alembic:", e)
else:
    print("Could not find alembic.ini at:", ini_path)
