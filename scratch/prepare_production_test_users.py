import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add backend directory to path
sys.path.append(os.path.abspath('backend'))

from app.models.user import User
from app.models.cricket import Team, TeamMember, Notification
from app.core.security import get_password_hash

prod_db_url = 'postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway'
engine = create_engine(prod_db_url)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def create_or_update_user(db, email, username, display_name, role):
    user = db.query(User).filter(User.email == email).first()
    hashed_password = get_password_hash("Password123")
    if user:
        print(f"User {email} exists. Updating details...")
        user.username = username
        user.hashed_password = hashed_password
        user.email_verified = True
        user.is_active = True
        user.is_deleted = False
        user.profile_completed = True
        user.display_name = display_name
        user.full_name = display_name
        user.role = role
    else:
        print(f"User {email} does not exist. Creating new user...")
        user = User(
            email=email,
            username=username,
            hashed_password=hashed_password,
            email_verified=True,
            is_active=True,
            is_deleted=False,
            profile_completed=True,
            display_name=display_name,
            full_name=display_name,
            role=role
        )
        db.add(user)
    db.commit()
    db.refresh(user)
    print(f"User {email} is ready. ID: {user.id}")
    return user

def clean_database(db, captain_id, player_id):
    print("Cleaning existing test teams and members from production...")
    # Find all teams named 'Test Automation Team' or created by captain
    teams = db.query(Team).filter(
        (Team.name == 'Test Automation Team') | (Team.created_by == captain_id)
    ).all()
    
    for t in teams:
        print(f"Deleting team {t.name} (ID: {t.id})...")
        db.delete(t)
        
    # Delete notifications for captain and player
    db.query(Notification).filter(
        Notification.user_id.in_([captain_id, player_id])
    ).delete(synchronize_session=False)
    
    db.commit()
    print("Database cleaned successfully.")

def main():
    db = SessionLocal()
    try:
        captain = create_or_update_user(db, "captain@cricup.com", "captain_user", "Captain User", "player")
        player = create_or_update_user(db, "player@cricup.com", "player_user", "Player User", "player")
        testuser = create_or_update_user(db, "testuser@cricup.com", "testuser", "Test User", "scorer")
        
        clean_database(db, captain.id, player.id)
    finally:
        db.close()

if __name__ == "__main__":
    main()
