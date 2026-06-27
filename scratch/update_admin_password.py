import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))

os.environ["DATABASE_URL"] = "postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway"
os.environ["APP_ENV"] = "development"

from app.core.database import SessionLocal
from app.models.user import User

def update_pwd():
    db = SessionLocal()
    try:
        admin_user = db.query(User).filter(User.email == "cricupservice@gmail.com").first()
        if admin_user:
            admin_user.hashed_password = "$2b$12$kXHad0SLRVQxDgz9D/t2O.JBVfFj5wBeg0IQK954o3WBVTk83SaYq"
            db.commit()
            print("Successfully updated admin password to Password123!")
        else:
            print("Admin user not found!")
    finally:
        db.close()

if __name__ == "__main__":
    update_pwd()
