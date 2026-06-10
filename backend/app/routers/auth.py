from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.config import settings
from app.core.database import get_db
from app.core.security import get_password_hash, verify_password, create_access_token
from app.models.user import User
from app.models.cricket import Player
from app.schemas.user import UserCreate, UserResponse, Token, GoogleLoginRequest

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")

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
    return user


@router.post("/signup", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def signup(user_in: UserCreate, db: Session = Depends(get_db)):
    # Check if user already exists
    user = db.query(User).filter(User.email == user_in.email).first()
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email already exists."
        )
    
    hashed_pwd = get_password_hash(user_in.password)
    db_user = User(
        email=user_in.email,
        hashed_password=hashed_pwd,
        full_name=user_in.full_name,
        created_at=datetime.now(timezone.utc)
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    # Auto-create a corresponding player profile for convenience
    # Set default values for style
    db_player = Player(
        user_id=db_user.id,
        name=db_user.full_name,
        role="all_rounder",
        batting_style="right_hand",
        bowling_style="right_arm_spin"
    )
    db.add(db_player)
    db.commit()
    
    return db_user

@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not user.hashed_password or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect email or password"
        )
    
    access_token = create_access_token(subject=user.id)
    return Token(access_token=access_token, token_type="bearer")

@router.post("/google", response_model=Token)
def google_login(login_req: GoogleLoginRequest, db: Session = Depends(get_db)):
    # MVP Placeholder: decode/verify token, but here we mock it
    # In production, use google-auth library to verify.
    # We will simulate verifying and generating a user from it.
    mock_email = f"{login_req.token.lower().replace(' ', '')}@gmail.com"
    mock_name = login_req.token if " " in login_req.token else "Google User"
    
    user = db.query(User).filter(User.email == mock_email).first()
    if not user:
        user = User(
            email=mock_email,
            full_name=mock_name,
            google_id=f"google_{login_req.token}",
            created_at=datetime.now(timezone.utc)
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        
        # Auto-create player profile
        db_player = Player(
            user_id=user.id,
            name=user.full_name,
            role="all_rounder",
            batting_style="right_hand",
            bowling_style="right_arm_spin"
        )
        db.add(db_player)
        db.commit()
        
    access_token = create_access_token(subject=user.id)
    return Token(access_token=access_token, token_type="bearer")

@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user
