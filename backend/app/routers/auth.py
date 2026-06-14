from datetime import datetime, timedelta, timezone
import secrets
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

logger = logging.getLogger(__name__)
from jose import JWTError, jwt
from sqlalchemy import func
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
    CompleteProfileRequest, ForgotPasswordRequest, ResetPasswordRequest,
    VerifyResetOTPRequest
)
from app.core.email import send_verification_otp, send_password_reset_otp

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
    print("[SIGNUP REQUEST RECEIVED]")
    logger.info("[SIGNUP REQUEST RECEIVED]")
    
    # 1. Unique email check
    email_user = db.query(User).filter(func.lower(func.trim(User.email)) == func.lower(user_in.email.strip())).first()
    if email_user:
        if not email_user.email_verified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Account exists but is not verified"
            )
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
    print("[OTP GENERATED]")
    logger.info("[OTP GENERATED]")
    
    otp_expiry = get_utc_now() + timedelta(minutes=10)
    
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
    print("[USER CREATED]")
    logger.info("[USER CREATED]")
    
    db.commit()
    db.refresh(db_user)
    print("[OTP SAVED TO DATABASE]")
    logger.info("[OTP SAVED TO DATABASE]")
    
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
    
    print("[EMAIL SEND STARTED]")
    logger.info("[EMAIL SEND STARTED]")
    
    email_success = send_verification_otp(user_in.email, otp_code)
    if email_success:
        print("[EMAIL SEND SUCCESS]")
        logger.info("[EMAIL SEND SUCCESS]")
    else:
        print("[EMAIL SEND FAILED]")
        logger.info("[EMAIL SEND FAILED]")
    
    return db_user

@router.post("/verify-otp", response_model=Token)
def verify_otp(req: VerifyOTPRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(func.lower(func.trim(User.email)) == func.lower(req.email.strip())).first()
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
    print("[RESEND REQUEST RECEIVED]")
    logger.info("[RESEND REQUEST RECEIVED]")
    
    user = db.query(User).filter(func.lower(func.trim(User.email)) == func.lower(req.email.strip())).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )
        
    print("[USER FOUND]")
    logger.info("[USER FOUND]")
        
    # Rate limit check (60 seconds)
    if user.last_otp_sent_at and (get_utc_now() - user.last_otp_sent_at) < timedelta(seconds=60):
        remaining = 60 - int((get_utc_now() - user.last_otp_sent_at).total_seconds())
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Please wait {remaining} seconds before requesting a new OTP."
        )
        
    otp_code = f"{secrets.randbelow(900000) + 100000:06d}"
    print("[NEW OTP GENERATED]")
    logger.info("[NEW OTP GENERATED]")
    
    otp_expiry = get_utc_now() + timedelta(minutes=10)
    
    user.otp_code = otp_code
    user.otp_expiry = otp_expiry
    user.last_otp_sent_at = get_utc_now()
    db.commit()
    print("[OTP SAVED]")
    logger.info("[OTP SAVED]")
    
    print("[EMAIL SEND STARTED]")
    logger.info("[EMAIL SEND STARTED]")
    
    email_success = send_verification_otp(user.email, otp_code)
    if email_success:
        print("[EMAIL SEND SUCCESS]")
        logger.info("[EMAIL SEND SUCCESS]")
    else:
        print("[EMAIL SEND FAILED]")
        logger.info("[EMAIL SEND FAILED]")
    
    return {"message": "Verification code resent successfully."}

@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    email = form_data.username.strip().lower() if form_data.username else ""
    user = db.query(User).filter(func.lower(func.trim(User.email)) == func.lower(email)).first()
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
    user = db.query(User).filter(func.lower(func.trim(User.email)) == func.lower(req.email.strip())).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )
        
    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is not verified. Please verify your email first."
        )
        
    # Rate limit check (60 seconds)
    if user.last_otp_sent_at and (get_utc_now() - user.last_otp_sent_at) < timedelta(seconds=60):
        remaining = 60 - int((get_utc_now() - user.last_otp_sent_at).total_seconds())
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Please wait {remaining} seconds before requesting a new reset OTP."
        )
        
    otp_code = f"{secrets.randbelow(900000) + 100000:06d}"
    otp_expiry = get_utc_now() + timedelta(minutes=10)
    
    # Send password reset email via Brevo API
    send_password_reset_otp(user.email, otp_code)
    
    user.otp_code = otp_code
    user.otp_expiry = otp_expiry
    user.last_otp_sent_at = get_utc_now()
    db.commit()
    
    return {"message": "Password reset OTP has been sent."}

@router.post("/verify-reset-otp")
def verify_reset_otp(req: VerifyResetOTPRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(func.lower(func.trim(User.email)) == func.lower(req.email.strip())).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )
        
    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is not verified. Please verify your email first."
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
        
    return {"message": "OTP verified successfully."}

@router.post("/reset-password")
def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(func.lower(func.trim(User.email)) == func.lower(req.email.strip())).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )
        
    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is not verified. Please verify your email first."
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
    if req.username:
        # Verify unique username
        existing = db.query(User).filter(User.username == req.username, User.id != current_user.id).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username is already taken."
            )
        current_user.username = req.username

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
    
    role_to_set = "all_rounder"
    if req.role:
        valid_roles = ["batsman", "bowler", "all_rounder", "wicket_keeper"]
        if req.role not in valid_roles:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid player role."
            )
        role_to_set = req.role
        
    if player:
        player.name = req.full_name
        player.role = role_to_set
        if req.profile_picture:
            player.profile_photo_url = req.profile_picture
        db.commit()
    else:
        db_player = Player(
            user_id=current_user.id,
            created_by=current_user.id,
            name=req.full_name,
            role=role_to_set,
            batting_style="right_hand",
            bowling_style="right_arm_spin",
            profile_photo_url=req.profile_picture
        )
        db.add(db_player)
        db.commit()
        
    return current_user

def verify_google_id_token(token: str, client_id: str | None) -> dict:
    import httpx
    from jose import jwt, JWTError

    print(f"[GOOGLE TOKEN RECEIVED] Token length: {len(token)} | Prefix: {token[:15]}... Suffix: {token[-15:]}")

    if not client_id:
        if settings.APP_ENV == "production":
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="GOOGLE_CLIENT_ID is not configured."
            )
        client_id = "test_google_client_id"

    # 1. Fetch Google's public certificates
    try:
        response = httpx.get("https://www.googleapis.com/oauth2/v3/certs", timeout=5.0)
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to retrieve Google public certificates."
            )
        jwks = response.json()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Network error fetching Google certificates: {str(e)}"
        )

    # 2. Extract key ID (kid) from token header
    try:
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid token format: {str(e)}"
        )

    if not kid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token header is missing 'kid'."
        )

    # 3. Locate matching key in JWKS
    key = None
    for k in jwks.get("keys", []):
        if k.get("kid") == kid:
            key = k
            break

    if not key:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google public certificate not found for specified 'kid'."
        )

    # 4. Decode and verify signature, issuer, audience, and expiry
    allowed_issuers = ["accounts.google.com", "https://accounts.google.com"]
    payload = None
    last_err = None

    for iss in allowed_issuers:
        try:
            payload = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                audience=client_id,
                issuer=iss
            )
            print(f"[AUDIENCE VALIDATION] Target Client ID: {client_id} | Token Aud: {payload.get('aud')} | Status: SUCCESS")
            print(f"[ISSUER VALIDATION] Allowed Issuers: {allowed_issuers} | Token Iss: {payload.get('iss')} | Status: SUCCESS")
            break
        except JWTError as e:
            last_err = e

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Google ID token verification failed: {str(last_err)}"
        )

    return payload

@router.post("/google", response_model=Token)
def google_login(login_req: GoogleLoginRequest, db: Session = Depends(get_db)):
    # Verify the real Google ID token
    payload = verify_google_id_token(login_req.token, settings.GOOGLE_CLIENT_ID)
    
    email = payload.get("email")
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google ID token payload does not contain an email."
        )
    email = email.lower().strip()
    name = payload.get("name", "")
    picture = payload.get("picture", "")
    google_sub = payload.get("sub")
    
    if not google_sub:
         raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google ID token payload does not contain a subject (sub) identifier."
        )

    masked_sub = f"{google_sub[:4]}***{google_sub[-4:]}" if len(google_sub) > 8 else "***"
    print(f"[GOOGLE SUBJECT ID] {masked_sub}")
    print(f"[GOOGLE EMAIL] {email}")

    # Ensure user is found by Google subject ID or email
    user = db.query(User).filter(
        (User.google_id == google_sub) | 
        (func.lower(func.trim(User.email)) == func.lower(email.strip()))
    ).first()
    
    if user:
        # Link Google ID if not linked, update verification state
        user.google_id = google_sub
        user.email_verified = True
        user.provider = "google"
        if picture and not user.profile_photo_url:
            user.profile_photo_url = picture
            user.profile_picture = picture
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
            full_name=name,
            display_name=name,
            profile_photo_url=picture,
            profile_picture=picture,
            google_id=google_sub,
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
            name=name if name else user.username,
            role="all_rounder",
            batting_style="right_hand",
            bowling_style="right_arm_spin",
            profile_photo_url=picture
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

