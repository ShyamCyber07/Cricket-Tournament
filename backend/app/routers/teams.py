from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from uuid import UUID
import uuid
import os
from PIL import Image
import io

from app.core.storage import upload_image, delete_image

from app.core.database import get_db
from app.routers.auth import get_current_user
from app.models.user import User
from app.models.cricket import Team, Player, TeamPlayer, Match, Tournament, TournamentTeam, MatchSquad, TeamMember, Notification
from app.schemas.team import TeamCreate, TeamResponse, AddPlayerRequest, TeamStatsResponse, TeamUpdate, BulkAddPlayersRequest, TeamMemberResponse, MyTeamsResponse, AddMemberRequest, ApproveMemberRequest

router = APIRouter()

@router.post("/", response_model=TeamResponse, status_code=status.HTTP_201_CREATED)
def create_team(
    team_in: TeamCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Check if team name exists for this user (unique per owner, not globally)
    existing = db.query(Team).filter(
        Team.name == team_in.name,
        Team.created_by == current_user.id
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already have a team with this name"
        )

    # If captain_id is provided, check if player exists
    if team_in.captain_id:
        captain = db.query(Player).filter(Player.id == team_in.captain_id).first()
        if not captain:
            raise HTTPException(status_code=404, detail="Captain player not found")

    db_team = Team(
        name=team_in.name,
        logo_url=team_in.logo_url,
        captain_id=team_in.captain_id,
        description=team_in.description,
        created_by=current_user.id
    )
    db.add(db_team)
    db.flush()

    # Automatically add creator as captain in team_members
    creator_member = TeamMember(
        team_id=db_team.id,
        user_id=current_user.id,
        role="captain",
        status="active"
    )
    db.add(creator_member)
    db.commit()
    db.refresh(db_team)
        
    return db_team

@router.get("/my-teams", response_model=List[MyTeamsResponse])
def get_my_teams(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Fetch all teams where user is a member (either captain or player)
    memberships = db.query(TeamMember).filter(TeamMember.user_id == current_user.id).all()
    
    res = []
    for m in memberships:
        team = db.query(Team).filter(Team.id == m.team_id).first()
        if team:
            res.append(MyTeamsResponse(
                team=team,
                role=m.role,
                status=m.status
            ))
    return res

@router.get("/my-invitations", response_model=List[MyTeamsResponse])
def get_my_invitations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Fetch all invitations where user is invited
    memberships = db.query(TeamMember).filter(
        TeamMember.user_id == current_user.id,
        TeamMember.status == "invited"
    ).all()
    
    res = []
    for m in memberships:
        team = db.query(Team).filter(Team.id == m.team_id).first()
        if team:
            res.append(MyTeamsResponse(
                team=team,
                role=m.role,
                status=m.status
            ))
    return res

@router.post("/{id}/invitations/accept", response_model=TeamMemberResponse)
def accept_invitation(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    member = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.status == "invited"
    ).first()
    
    if not member:
        raise HTTPException(status_code=404, detail="Invitation not found")
        
    member.status = "active"
    
    # Notify all active captains of this team that the user accepted
    import json
    captains = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).all()
    
    for cap in captains:
        notif = Notification(
            user_id=cap.user_id,
            title="Invitation Accepted",
            message=f"{current_user.full_name or current_user.username} accepted your invitation to join {team.name}.",
            type="invitation_accepted",
            extra_data=json.dumps({"team_id": str(id)})
        )
        db.add(notif)
        
    db.commit()
    db.refresh(member)
    return TeamMemberResponse(
        id=member.id,
        team_id=member.team_id,
        user_id=member.user_id,
        user_email=current_user.email,
        user_full_name=current_user.full_name or current_user.username or "User",
        role=member.role,
        status=member.status,
        joined_at=member.joined_at
    )

@router.post("/{id}/invitations/reject", status_code=status.HTTP_204_NO_CONTENT)
def reject_invitation(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    member = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.status == "invited"
    ).first()
    
    if not member:
        raise HTTPException(status_code=404, detail="Invitation not found")
        
    db.delete(member)
    
    # Notify all active captains of this team that the user rejected
    import json
    captains = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).all()
    
    for cap in captains:
        notif = Notification(
            user_id=cap.user_id,
            title="Invitation Rejected",
            message=f"{current_user.full_name or current_user.username} rejected your invitation to join {team.name}.",
            type="invitation_rejected",
            extra_data=json.dumps({"team_id": str(id)})
        )
        db.add(notif)
        
    db.commit()
    return None

@router.get("/", response_model=List[TeamResponse])
def list_teams(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role == "admin":
        return db.query(Team).all()
    return db.query(Team).filter(Team.created_by == current_user.id).all()

@router.get("/{id}", response_model=TeamResponse)
def get_team(id: UUID, db: Session = Depends(get_db)):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    return team

@router.post("/{id}/players", response_model=TeamResponse)
def add_player_to_team(
    id: UUID,
    req: AddPlayerRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Check authorization (only creator can add players)
    if team.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Check if player exists
    player = db.query(Player).filter(Player.id == req.player_id).first()
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")

    # Check player ownership
    if player.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this player")

    # Check if player is already assigned to any team (duplicate active membership prevention)
    existing_membership = db.query(TeamPlayer).filter(TeamPlayer.player_id == req.player_id).first()
    if existing_membership:
        assigned_team = db.query(Team).filter(Team.id == existing_membership.team_id).first()
        team_name = assigned_team.name if assigned_team else "another team"
        if existing_membership.team_id == id:
            raise HTTPException(status_code=400, detail="Player already in this team")
        else:
            raise HTTPException(
                status_code=400,
                detail=f"Player already assigned to Team {team_name}"
            )

    assoc = TeamPlayer(team_id=id, player_id=req.player_id)
    db.add(assoc)
    db.commit()
    db.refresh(team)
    return team

@router.post("/{id}/players/bulk", response_model=TeamResponse)
def add_players_to_team_bulk(
    id: UUID,
    req: BulkAddPlayersRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Check authorization (only creator can add players)
    if team.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Validate all player IDs first
    for p_id in req.player_ids:
        player = db.query(Player).filter(Player.id == p_id).first()
        if not player:
            raise HTTPException(status_code=404, detail=f"Player {p_id} not found")

        # Check player ownership
        if player.created_by != current_user.id:
            raise HTTPException(status_code=403, detail=f"Not authorized to manage player {player.name}")

        # Check duplicate assignment
        existing_membership = db.query(TeamPlayer).filter(TeamPlayer.player_id == p_id).first()
        if existing_membership:
            assigned_team = db.query(Team).filter(Team.id == existing_membership.team_id).first()
            team_name = assigned_team.name if assigned_team else "another team"
            if existing_membership.team_id == id:
                raise HTTPException(status_code=400, detail=f"Player {player.name} already in this team")
            else:
                raise HTTPException(
                    status_code=400,
                    detail=f"Player already assigned to Team {team_name}"
                )

    # All validations passed, insert associations
    for p_id in req.player_ids:
        assoc = TeamPlayer(team_id=id, player_id=p_id)
        db.add(assoc)
        
    db.commit()
    db.refresh(team)
    return team

@router.get("/{id}/stats", response_model=TeamStatsResponse)
def get_team_stats(id: UUID, db: Session = Depends(get_db)):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    # Match count
    matches = db.query(Match).filter(
        (Match.team1_id == id) | (Match.team2_id == id)
    ).all()

    played = 0
    won = 0
    lost = 0
    tied = 0

    for m in matches:
        if m.status == "completed":
            played += 1
            if m.winner_id == id:
                won += 1
            elif m.winner_id is None:
                # No winner -> tie or no result (tied)
                tied += 1
            else:
                lost += 1

    return TeamStatsResponse(
        team_id=id,
        team_name=team.name,
        matches_played=played,
        matches_won=won,
        matches_lost=lost,
        matches_tied=tied,
        net_run_rate=0.0  # Optional NRR placeholder
    )


@router.put("/{id}", response_model=TeamResponse)
def update_team(
    id: UUID,
    team_in: TeamUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    # Check authorization (captain or admin)
    is_captain = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).first()
    if not is_captain and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Update name if provided and verify uniqueness per user
    if team_in.name is not None and team_in.name != team.name:
        existing = db.query(Team).filter(
            Team.name == team_in.name,
            Team.created_by == team.created_by,  # Same user
            Team.id != id  # Not the same team
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail="You already have a team with this name")
        team.name = team_in.name

    if team_in.description is not None:
        team.description = team_in.description

    # Update captain if provided and check membership
    if team_in.captain_id is not None:
        if team_in.captain_id == UUID(int=0):  # Handle clearing captain (e.g. empty or null)
            team.captain_id = None
        else:
            # Check if captain player is in the team
            member = db.query(TeamPlayer).filter(
                TeamPlayer.team_id == id,
                TeamPlayer.player_id == team_in.captain_id
            ).first()
            if not member:
                raise HTTPException(status_code=400, detail="Captain must be a member of the team")
            team.captain_id = team_in.captain_id

    db.add(team)
    db.commit()
    db.refresh(team)
    return team


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_team(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    # Check authorization (captain or admin)
    is_captain = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).first()
    if not is_captain and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Block deletion if team belongs to active tournament (status == ongoing)
    active_tour = db.query(Tournament).join(TournamentTeam).filter(
        TournamentTeam.team_id == id,
        Tournament.status == "ongoing"
    ).first()
    if active_tour:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete team because it is registered in an active tournament: {active_tour.name}."
        )

    # Block deletion if team has scheduled/ongoing matches (status not in completed/abandoned)
    active_match = db.query(Match).filter(
        ((Match.team1_id == id) | (Match.team2_id == id)),
        ~Match.status.in_(["completed", "abandoned"])
    ).first()
    if active_match:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete team because it has scheduled or active matches: {active_match.team1.name} vs {active_match.team2.name}."
        )

    if team.logo_url:
        delete_image(team.logo_url)
    db.delete(team)
    db.commit()
    return None


@router.delete("/{id}/players/{player_id}", response_model=TeamResponse)
def remove_player_from_team(
    id: UUID,
    player_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    # Check authorization
    if team.created_by != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    # Check if player is a member
    assoc = db.query(TeamPlayer).filter(
        TeamPlayer.team_id == id,
        TeamPlayer.player_id == player_id
    ).first()
    if not assoc:
        raise HTTPException(status_code=404, detail="Player is not a member of this team")

    # Block removal if player is in an active (non-completed/non-abandoned) match squad of this team
    active_squad = db.query(Match).join(MatchSquad).filter(
        MatchSquad.player_id == player_id,
        MatchSquad.team_id == id,
        ~Match.status.in_(["completed", "abandoned"])
    ).first()
    if active_squad:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot remove player because they are part of an active match squad: {active_squad.team1.name} vs {active_squad.team2.name}."
        )

    # Delete membership relation
    db.delete(assoc)

    # Set captain_id to None if the removed player was the captain
    if team.captain_id == player_id:
        team.captain_id = None

    db.add(team)
    db.commit()
    db.refresh(team)
    return team


# Helper to crop image to square and resize
def crop_and_resize_image(image_bytes: bytes, target_size=(256, 256)) -> bytes:
    img = Image.open(io.BytesIO(image_bytes))
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")
    width, height = img.size
    min_side = min(width, height)
    left = (width - min_side) // 2
    top = (height - min_side) // 2
    right = left + min_side
    bottom = top + min_side
    img = img.crop((left, top, right, bottom))
    img = img.resize(target_size, Image.Resampling.LANCZOS)
    out_io = io.BytesIO()
    img.save(out_io, format="JPEG", quality=90)
    return out_io.getvalue()


@router.post("/{id}/upload-logo")
def upload_team_logo(
    id: UUID,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
    # Check authorization (captain or admin)
    is_captain = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).first()
    if not is_captain and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to manage this team")

    ext = file.filename.split(".")[-1].lower()
    if ext not in ["jpg", "jpeg", "png", "gif", "webp"]:
        raise HTTPException(status_code=400, detail="Invalid file type. Only image files are allowed.")

    filename = f"team_{team.id}_{uuid.uuid4().hex}.jpg"

    try:
        content = file.file.read()
        processed_content = crop_and_resize_image(content)
        
        # Delete old logo if it exists
        if team.logo_url:
            delete_image(team.logo_url)
            
        url = upload_image(processed_content, filename, folder="teams")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to process or upload image: {str(e)}")

    team.logo_url = url
    db.add(team)
    db.commit()
    db.refresh(team)
    return {"url": url, "logo_url": url}


# --- Team Membership Endpoints ---

@router.get("/{id}/members", response_model=List[TeamMemberResponse])
def get_team_members(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Check if user is a member of the team to view members (Player or Captain)
    # Player/Captain permission: "View members"
    is_member = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.status == "active"
    ).first()
    
    if not is_member and team.created_by != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to view members of this team")

    members = db.query(TeamMember, User).join(User, TeamMember.user_id == User.id).filter(
        TeamMember.team_id == id
    ).all()

    res = []
    for member, user in members:
        res.append(TeamMemberResponse(
            id=member.id,
            team_id=member.team_id,
            user_id=member.user_id,
            user_email=user.email,
            user_full_name=user.full_name or user.username or "User",
            role=member.role,
            status=member.status,
            joined_at=member.joined_at
        ))
    return res


@router.post("/{id}/members", response_model=TeamMemberResponse)
def add_member_to_team(
    id: UUID,
    req: AddMemberRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Captain permissions: "Add member"
    is_captain = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).first()
    
    if not is_captain and team.created_by != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the captain can add members")

    # Find user by email
    user_to_add = db.query(User).filter(User.email == req.email).first()
    if not user_to_add:
        raise HTTPException(status_code=404, detail="User with this email not found")

    # Check if already a member or pending
    existing = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == user_to_add.id
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="User is already a member or request is pending")

    member = TeamMember(
        team_id=id,
        user_id=user_to_add.id,
        role="player",
        status="invited"
    )
    db.add(member)
    
    # Create notification for the user
    import json
    notif = Notification(
        user_id=user_to_add.id,
        title="Team Invitation",
        message=f"You have been invited to join team {team.name}",
        type="invitation_received",
        extra_data=json.dumps({"team_id": str(id)})
    )
    db.add(notif)
    
    db.commit()
    db.refresh(member)
    
    return TeamMemberResponse(
        id=member.id,
        team_id=member.team_id,
        user_id=member.user_id,
        user_email=user_to_add.email,
        user_full_name=user_to_add.full_name or user_to_add.username or "User",
        role=member.role,
        status=member.status,
        joined_at=member.joined_at
    )


@router.delete("/{id}/members/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_member_from_team(
    id: UUID,
    user_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Captain permissions: "Remove member"
    is_captain = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).first()
    
    if not is_captain and team.created_by != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the captain can remove members")

    # Cannot remove creator/owner
    if user_id == team.created_by:
        raise HTTPException(status_code=400, detail="The team creator/owner cannot be removed")

    member = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == user_id
    ).first()
    
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    db.delete(member)
    db.commit()
    return None


@router.post("/{id}/join-request", response_model=TeamMemberResponse)
def create_join_request(
    id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Check if already a member or pending
    existing = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="You are already a member or have a pending request")

    member = TeamMember(
        team_id=id,
        user_id=current_user.id,
        role="player",
        status="pending"
    )
    db.add(member)
    db.commit()
    db.refresh(member)
    
    return TeamMemberResponse(
        id=member.id,
        team_id=member.team_id,
        user_id=member.user_id,
        user_email=current_user.email,
        user_full_name=current_user.full_name or current_user.username or "User",
        role=member.role,
        status=member.status,
        joined_at=member.joined_at
    )


@router.post("/{id}/approve-request", response_model=TeamMemberResponse)
def approve_join_request(
    id: UUID,
    req: ApproveMemberRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Captain permissions: "Approve join requests"
    is_captain = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).first()
    
    if not is_captain and team.created_by != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the captain can approve requests")

    member = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == req.user_id,
        TeamMember.status == "pending"
    ).first()
    
    if not member:
        raise HTTPException(status_code=404, detail="Pending request not found")

    member.status = "active"
    
    # Create notification for approved user
    import json
    notif = Notification(
        user_id=req.user_id,
        title="Join Request Approved",
        message=f"Your request to join team {team.name} has been approved!",
        type="request_approved",
        extra_data=json.dumps({"team_id": str(id)})
    )
    db.add(notif)
    
    db.commit()
    db.refresh(member)
    
    user_approved = db.query(User).filter(User.id == req.user_id).first()
    return TeamMemberResponse(
        id=member.id,
        team_id=member.team_id,
        user_id=member.user_id,
        user_email=user_approved.email,
        user_full_name=user_approved.full_name or user_approved.username or "User",
        role=member.role,
        status=member.status,
        joined_at=member.joined_at
    )

@router.post("/{id}/reject-request", status_code=status.HTTP_204_NO_CONTENT)
def reject_join_request(
    id: UUID,
    req: ApproveMemberRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    team = db.query(Team).filter(Team.id == id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")
        
    # Captain permissions: "Reject join requests"
    is_captain = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == current_user.id,
        TeamMember.role == "captain",
        TeamMember.status == "active"
    ).first()
    
    if not is_captain and team.created_by != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the captain can reject requests")

    member = db.query(TeamMember).filter(
        TeamMember.team_id == id,
        TeamMember.user_id == req.user_id,
        TeamMember.status == "pending"
    ).first()
    
    if not member:
        raise HTTPException(status_code=404, detail="Pending request not found")

    db.delete(member)
    
    # Create notification for rejected user
    import json
    notif = Notification(
        user_id=req.user_id,
        title="Join Request Rejected",
        message=f"Your request to join team {team.name} has been rejected.",
        type="request_rejected",
        extra_data=json.dumps({"team_id": str(id)})
    )
    db.add(notif)
    
    db.commit()
    return None
