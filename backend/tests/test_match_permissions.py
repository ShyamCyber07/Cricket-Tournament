import pytest
from app.models.cricket import Match, Team, Player, Tournament
from app.models.user import User
from app.core.security import get_password_hash
import uuid

def create_user(client, db, email, username, password="Password123!"):
    user = User(
        email=email,
        username=username,
        hashed_password=get_password_hash(password),
        full_name=username.capitalize(),
        email_verified=True,
        profile_completed=True
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Login to get token
    response = client.post(
        "/api/v1/auth/login",
        data={"username": email, "password": password}
    )
    token = response.json()["access_token"]
    return user, {"Authorization": f"Bearer {token}"}

def test_match_ownership_and_scorer_permissions(client, db):
    # 1. Create three users: user1 (creator), user2 (unrelated), user3 (assigned scorer)
    u1, h1 = create_user(client, db, "u1@example.com", "user1")
    u2, h2 = create_user(client, db, "u2@example.com", "user2")
    u3, h3 = create_user(client, db, "u3@example.com", "user3")

    # Seed teams for match creation
    t1 = Team(name="Team A", created_by=u1.id)
    t2 = Team(name="Team B", created_by=u1.id)
    db.add_all([t1, t2])
    db.commit()

    # 2. Test Match Creator (Requirement 2):
    # User 1 creates match.
    match_res = client.post(
        "/api/v1/matches/",
        json={
            "venue": "Test Venue",
            "match_date": "2026-06-15T12:00:00Z",
            "match_type": "T20",
            "over_limit": 20,
            "team1_id": str(t1.id),
            "team2_id": str(t2.id)
        },
        headers=h1
    )
    assert match_res.status_code == 201
    match_id = match_res.json()["id"]

    # Creator (User 1) has permission to submit toss:
    toss_res = client.post(
        f"/api/v1/matches/{match_id}/toss",
        json={"toss_winner_id": str(t1.id), "toss_decision": "bat"},
        headers=h1
    )
    assert toss_res.status_code == 200

    # Unrelated user (User 2) does not have permission (Requirement 4):
    toss_res = client.post(
        f"/api/v1/matches/{match_id}/toss",
        json={"toss_winner_id": str(t1.id), "toss_decision": "bat"},
        headers=h2
    )
    assert toss_res.status_code == 403

    # 3. Test Assigned Scorer (Requirement 3):
    # Create another match with User 3 as the assigned scorer
    match_res2 = client.post(
        "/api/v1/matches/",
        json={
            "venue": "Test Venue 2",
            "match_date": "2026-06-15T12:00:00Z",
            "match_type": "T20",
            "over_limit": 20,
            "team1_id": str(t1.id),
            "team2_id": str(t2.id),
            "assigned_scorer_id": str(u3.id)
        },
        headers=h1
    )
    assert match_res2.status_code == 201
    match_id2 = match_res2.json()["id"]

    # Assigned Scorer (User 3) has permission to submit toss:
    toss_res = client.post(
        f"/api/v1/matches/{match_id2}/toss",
        json={"toss_winner_id": str(t1.id), "toss_decision": "bat"},
        headers=h3
    )
    assert toss_res.status_code == 200

    # 4. Test Tournament Creator Scorer Privileges (Requirement 1):
    from datetime import date
    tournament = Tournament(
        name="Test Tournament",
        organizer_id=u1.id,
        start_date=date(2026, 6, 15),
        end_date=date(2026, 6, 20),
        format="League",
        num_teams=2,
        status="registration"
    )
    db.add(tournament)
    db.commit()

    # Create a match under User 1's tournament, but created_by is None (or another user)
    match_res3 = client.post(
        "/api/v1/matches/",
        json={
            "venue": "Tournament Venue",
            "match_date": "2026-06-15T12:00:00Z",
            "match_type": "T20",
            "over_limit": 20,
            "team1_id": str(t1.id),
            "team2_id": str(t2.id),
            "tournament_id": str(tournament.id)
        },
        headers=h2 # created by user2
    )
    assert match_res3.status_code == 201
    match_id3 = match_res3.json()["id"]

    # Verify that in DB, created_by is User 2
    db_match = db.query(Match).filter(Match.id == uuid.UUID(match_id3)).first()
    assert db_match.created_by == u2.id
    assert db_match.tournament_id == tournament.id

    # Tournament Creator/Organizer (User 1) has scorer privileges:
    toss_res = client.post(
        f"/api/v1/matches/{match_id3}/toss",
        json={"toss_winner_id": str(t1.id), "toss_decision": "bat"},
        headers=h1
    )
    assert toss_res.status_code == 200

    # Non-authorized user (User 3) does not have privileges for this match:
    toss_res = client.post(
        f"/api/v1/matches/{match_id3}/toss",
        json={"toss_winner_id": str(t1.id), "toss_decision": "bat"},
        headers=h3
    )
    assert toss_res.status_code == 403
