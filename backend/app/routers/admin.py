from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from uuid import UUID

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User, Report
from app.models.cricket import Team, Player, Tournament, Match
from app.schemas.user import UserResponse
from app.schemas.report import ReportCreate, ReportResponse

router = APIRouter()

def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required"
        )
    return current_user

# --- Public/User Report Endpoint ---

@router.post("/reports", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
def create_report(
    report_in: ReportCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Optional validation of content_type and existence of content_id
    if report_in.content_type == "tournament":
        content = db.query(Tournament).filter(Tournament.id == report_in.content_id).first()
    elif report_in.content_type == "match":
        content = db.query(Match).filter(Match.id == report_in.content_id).first()
    elif report_in.content_type == "team":
        content = db.query(Team).filter(Team.id == report_in.content_id).first()
    elif report_in.content_type == "player":
        content = db.query(Player).filter(Player.id == report_in.content_id).first()
    else:
        raise HTTPException(status_code=400, detail="Invalid content type")

    if not content:
        raise HTTPException(status_code=404, detail="Reported content not found")

    db_report = Report(
        reporter_id=current_user.id,
        content_type=report_in.content_type,
        content_id=report_in.content_id,
        reason=report_in.reason,
        status="pending",
        created_at=datetime.now(timezone.utc)
    )
    db.add(db_report)
    db.commit()
    db.refresh(db_report)
    return db_report

# --- Admin Panel Endpoints ---

@router.get("/admin/analytics", status_code=status.HTTP_200_OK)
def get_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    return {
        "total_users": db.query(User).count(),
        "total_teams": db.query(Team).count(),
        "total_players": db.query(Player).count(),
        "total_tournaments": db.query(Tournament).count(),
        "total_matches": db.query(Match).count()
    }

@router.get("/admin/users", response_model=List[UserResponse])
def get_users(
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    query = db.query(User)
    if search:
        search_term = f"%{search}%"
        query = query.filter(
            or_(
                User.username.ilike(search_term),
                User.email.ilike(search_term),
                User.full_name.ilike(search_term)
            )
        )
    return query.all()

@router.put("/admin/users/{id}/toggle-active", response_model=UserResponse)
def toggle_user_active(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    if id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot disable your own admin account"
        )
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.is_active = not user.is_active
    db.commit()
    db.refresh(user)
    return user

@router.delete("/admin/users/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    if id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot delete your own admin account"
        )
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    db.delete(user)
    db.commit()
    return None

@router.get("/admin/reports", response_model=List[ReportResponse])
def get_reports(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    return db.query(Report).order_by(Report.created_at.desc()).all()

@router.post("/admin/reports/{id}/resolve", response_model=ReportResponse)
def resolve_report(
    id: UUID,
    action: str = Query("resolved"), # resolved or dismissed
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    if action not in ["resolved", "dismissed"]:
        raise HTTPException(status_code=400, detail="Invalid action")

    report = db.query(Report).filter(Report.id == id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    report.status = action
    report.resolved_at = datetime.now(timezone.utc)
    report.resolved_by = current_user.id
    db.commit()
    db.refresh(report)
    return report
