from datetime import datetime, timedelta, timezone
import secrets
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.config import settings
from app.core.database import get_db
from app.core.security import get_password_hash, verify_password, create_access_token
from app.models.user import User, RefreshToken
from app.models.cricket import Player
from app.schemas.user import (
    UserSignup, UserResponse, Token, TokenRefreshRequest,
    GoogleLoginRequest, VerifyOTPRequest, ResendOTPRequest,
    CompleteProfileRequest, ForgotPasswordRequest, ResetPasswordRequest
)
from app.core.email import send_otp_email

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")

def get_utc_now():
    return datetime.now(timezone.utc).replace(tzinfo=None)

def get_current_user(db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id_str = payload.get("sub")
        if user_id_str is None:
            raise credentials_exception
        try:
            user_id = UUID(user_id_str)
        except ValueError:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
        
    # Check if lockout is still active (just in case they have a token but got locked out)
    if user.lockout_until and user.lockout_until > get_utc_now():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is temporarily locked. Please try again later."
        )
        
    return user

def create_refresh_token(db: Session, user_id: UUID) -> str:
    token_str = secrets.token_urlsafe(64)
    expires_at = get_utc_now() + timedelta(days=30)
    db_refresh = RefreshToken(
        user_id=user_id,
        token=token_str,
        expires_at=expires_at,
        created_at=get_utc_now()
    )
    db.add(db_refresh)
    db.commit()
    db.refresh(db_refresh)
    return token_str

@router.post("/signup", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def signup(user_in: UserSignup, db: Session = Depends(get_db)):
    # 1. Unique email check
    email_user = db.query(User).filter(User.email == user_in.email).first()
    if email_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email already exists."
        )
    
    # 2. Unique username check
    username_user = db.query(User).filter(User.username == user_in.username).first()
    if username_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this username already exists."
        )
        
    # Generate 6-digit OTP code
    otp_code = f"{secrets.randbelow(900000) + 100000:06d}"
    otp_expiry = get_utc_now() + timedelta(minutes=10)
    
    # Send verification email via Brevo
    send_otp_email(user_in.email, otp_code, subject="Verify your CricUP account")
    
    hashed_pwd = get_password_hash(user_in.password)
    db_user = User(
        email=user_in.email,
        username=user_in.username,
        hashed_password=hashed_pwd,
        full_name="", # empty string to avoid SQLite null issues, completed in profile completion
        display_name=user_in.username, # default to username
        email_verified=False,
        profile_completed=False,
        provider="local",
        otp_code=otp_code,
        otp_expiry=otp_expiry,
        last_otp_sent_at=get_utc_now(),
        created_at=get_utc_now()
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    # Auto-create corresponding player profile
    db_player = Player(
        user_id=db_user.id,
        created_by=db_user.id,
        name=db_user.username,
        role="all_rounder",
        batting_style="right_hand",
        bowling_style="right_arm_spin"
    )
    db.add(db_player)
    db.commit()
    
    return db_user

@router.post("/verify-otp", response_model=Token)
def verify_otp(req: VerifyOTPRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )
        
    if not user.otp_code or user.otp_code != req.otp_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP verification code."
        )
        
    if not user.otp_expiry or user.otp_expiry < get_utc_now():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP verification code has expired."
        )
        
    user.email_verified = True
    user.otp_code = None
    user.otp_expiry = None
    db.commit()
    
    access_token = create_access_token(subject=user.id)
    refresh_token = create_refresh_token(db, user.id)
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        email_verified=user.email_verified,
        profile_completed=user.profile_completed
    )

@router.post("/resend-otp")
def resend_otp(req: ResendOTPRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )
        
    # Rate limit check (60 seconds)
    if user.last_otp_sent_at and (get_utc_now() - user.last_otp_sent_at) < timedelta(seconds=60):
        remaining = 60 - int((get_utc_now() - user.last_otp_sent_at).total_seconds())
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Please wait {remaining} seconds before requesting a new OTP."
        )
        
    otp_code = f"{secrets.randbelow(900000) + 100000:06d}"
    otp_expiry = get_utc_now() + timedelta(minutes=10)
    
    # Send verification email via Brevo
    send_otp_email(user.email, otp_code, subject="Verify your CricUP account")
    
    user.otp_code = otp_code
    user.otp_expiry = otp_expiry
    user.last_otp_sent_at = get_utc_now()
    db.commit()
    
    return {"message": "Verification code resent successfully."}

@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user:
        # Prevent user enumeration information leakage, but keep error simple
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect email or password"
        )
        
    # Lockout check
    if user.lockout_until and user.lockout_until > get_utc_now():
        remaining = int((user.lockout_until - get_utc_now()).total_seconds() / 60) + 1
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account is locked due to too many failed attempts. Try again in {remaining} minutes."
        )
        
    if not user.hashed_password or not verify_password(form_data.password, user.hashed_password):
        user.failed_login_attempts += 1
        if user.failed_login_attempts >= 5:
            user.lockout_until = get_utc_now() + timedelta(minutes=15)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect email or password"
        )
        
    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not verified"
        )
        
    # Reset failed attempts on success
    user.failed_login_attempts = 0
    user.lockout_until = None
    user.last_login = get_utc_now()
    db.commit()
    
    access_token = create_access_token(subject=user.id)
    refresh_token = create_refresh_token(db, user.id)
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        email_verified=user.email_verified,
        profile_completed=user.profile_completed
    )

@router.post("/refresh", response_model=Token)
def refresh(req: TokenRefreshRequest, db: Session = Depends(get_db)):
    db_token = db.query(RefreshToken).filter(RefreshToken.token == req.refresh_token).first()
    if not db_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token."
        )
        
    if db_token.expires_at < get_utc_now():
        # Clean expired refresh token
        db.delete(db_token)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Expired refresh token. Please login again."
        )
        
    user = db.query(User).filter(User.id == db_token.user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found."
        )
        
    access_token = create_access_token(subject=user.id)
    return Token(
        access_token=access_token,
        refresh_token=req.refresh_token, # keep existing refresh token
        token_type="bearer",
        email_verified=user.email_verified,
        profile_completed=user.profile_completed
    )

@router.post("/logout")
def logout(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Delete all refresh tokens for the current user
    db.query(RefreshToken).filter(RefreshToken.user_id == current_user.id).delete()
    db.commit()
    return {"message": "Logged out successfully."}

@router.post("/forgot-password")
def forgot_password(req: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user:
        # To avoid enumeration, return success even if email does not exist
        return {"message": "If the email is registered, a reset code has been sent."}
        
    # Rate limit check (60 seconds)
    if user.last_otp_sent_at and (get_utc_now() - user.last_otp_sent_at) < timedelta(seconds=60):
        remaining = 60 - int((get_utc_now() - user.last_otp_sent_at).total_seconds())
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Please wait {remaining} seconds before requesting a new reset OTP."
        )
        
    otp_code = f"{secrets.randbelow(900000) + 100000:06d}"
    otp_expiry = get_utc_now() + timedelta(minutes=10)
    
    # Send password reset email via Brevo
    send_otp_email(user.email, otp_code, subject="Reset your CricUP password")
    
    user.otp_code = otp_code
    user.otp_expiry = otp_expiry
    user.last_otp_sent_at = get_utc_now()
    db.commit()
    
    return {"message": "Password reset OTP has been sent."}

@router.post("/reset-password")
def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )
        
    if not user.otp_code or user.otp_code != req.otp_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid password reset OTP."
        )
        
    if not user.otp_expiry or user.otp_expiry < get_utc_now():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password reset OTP has expired."
        )
        
    # Reset password
    user.hashed_password = get_password_hash(req.new_password)
    user.otp_code = None
    user.otp_expiry = None
    
    # Invalidate sessions
    db.query(RefreshToken).filter(RefreshToken.user_id == user.id).delete()
    db.commit()
    
    return {"message": "Password has been reset successfully."}

@router.post("/complete-profile", response_model=UserResponse)
def complete_profile(req: CompleteProfileRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    current_user.full_name = req.full_name
    current_user.display_name = req.display_name
    if req.profile_picture:
        current_user.profile_picture = req.profile_picture
        current_user.profile_photo_url = req.profile_picture
        
    current_user.profile_completed = True
    db.commit()
    db.refresh(current_user)
    
    # Update linked Player profile
    player = db.query(Player).filter(Player.user_id == current_user.id).first()
    if player:
        player.name = req.full_name
        if req.profile_picture:
            player.profile_photo_url = req.profile_picture
        db.commit()
    else:
        db_player = Player(
            user_id=current_user.id,
            created_by=current_user.id,
            name=req.full_name,
            role="all_rounder",
            batting_style="right_hand",
            bowling_style="right_arm_spin",
            profile_photo_url=req.profile_picture
        )
        db.add(db_player)
        db.commit()
        
    return current_user

@router.post("/google", response_model=Token)
def google_login(login_req: GoogleLoginRequest, db: Session = Depends(get_db)):
    # Support token as email directly or build email from nickname
    raw_token = login_req.token
    if "@" in raw_token:
        email = raw_token.lower().strip()
        name = email.split("@")[0].capitalize()
    else:
        email = f"{raw_token.lower().replace(' ', '')}@gmail.com"
        name = raw_token
        
    user = db.query(User).filter(User.email == email).first()
    
    if user:
        # Link Google account if not linked
        if not user.google_id:
            user.google_id = f"google_{email}"
        # Google account is verified pre-verification
        user.email_verified = True
        user.provider = "google"
        db.commit()
        db.refresh(user)
    else:
        username = email.split("@")[0]
        # Check if username is taken, append random sequence if so
        existing_username = db.query(User).filter(User.username == username).first()
        if existing_username:
            username = f"{username}_{secrets.token_hex(4)}"
            
        user = User(
            email=email,
            username=username,
            full_name="", # to be set in profile completion
            display_name=name,
            google_id=f"google_{email}",
            provider="google",
            email_verified=True,
            profile_completed=False,
            created_at=get_utc_now()
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        
        # Create Player profile
        db_player = Player(
            user_id=user.id,
            created_by=user.id,
            name=user.username,
            role="all_rounder",
            batting_style="right_hand",
            bowling_style="right_arm_spin"
        )
        db.add(db_player)
        db.commit()
        
    access_token = create_access_token(subject=user.id)
    refresh_token = create_refresh_token(db, user.id)
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        email_verified=user.email_verified,
        profile_completed=user.profile_completed
    )

@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.get("/debug-db")
def debug_db(db: Session = Depends(get_db)):
    import os
    from app.core.config import settings
    return {
        "database_url": settings.DATABASE_URL,
        "database_dialect": db.bind.dialect.name,
        "database_url_from_env": os.getenv("DATABASE_URL"),
        "app_env": settings.APP_ENV
    }

