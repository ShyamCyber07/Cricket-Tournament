import sys
import os

# Add backend directory to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend')))

from app.core.database import SessionLocal
from app.models.user import User
from app.core.security import get_password_hash

def create_or_update_user(email, username, display_name):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        hashed_password = get_password_hash("Password123")
        if user:
            print(f"User {email} exists. Updating details...")
            user.hashed_password = hashed_password
            user.email_verified = True
            user.is_active = True
            user.profile_completed = True
            user.display_name = display_name
            user.full_name = display_name
        else:
            print(f"User {email} does not exist. Creating new user...")
            user = User(
                email=email,
                username=username,
                hashed_password=hashed_password,
                email_verified=True,
                is_active=True,
                profile_completed=True,
                display_name=display_name,
                full_name=display_name,
                role="player"
            )
            db.add(user)
        db.commit()
        print(f"User {email} is ready.")
    finally:
        db.close()

if __name__ == "__main__":
    create_or_update_user("captain@cricup.com", "captain_user", "Captain User")
    create_or_update_user("player@cricup.com", "player_user", "Player User")
