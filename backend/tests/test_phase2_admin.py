import pytest
from app.models.user import User
from app.models.cricket import Team, Match, Tournament, TeamMember
from app.core.security import get_password_hash
from uuid import UUID

@pytest.fixture(scope="function")
def admin_headers(client, db):
    # Create admin user
    admin_user = User(
        email="admin@example.com",
        username="adminuser",
        hashed_password=get_password_hash("AdminPassword123!"),
        full_name="System Admin",
        email_verified=True,
        profile_completed=True,
        role="admin"
    )
    db.add(admin_user)
    db.commit()
    db.refresh(admin_user)

    # Login to get token
    response = client.post(
        "/api/v1/auth/login",
        data={"username": "admin@example.com", "password": "AdminPassword123!"}
    )
    assert response.status_code == 200
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_admin_analytics_and_team_members(client, db, admin_headers):
    # 1. Seed two users, one team, and make them members
    u1 = User(
        email="member1@example.com",
        username="member1",
        hashed_password=get_password_hash("Password123!"),
        full_name="Member One",
        email_verified=True,
        profile_completed=True
    )
    u2 = User(
        email="member2@example.com",
        username="member2",
        hashed_password=get_password_hash("Password123!"),
        full_name="Member Two",
        email_verified=True,
        profile_completed=True
    )
    db.add_all([u1, u2])
    db.commit()

    # Create team owned by u1
    team = Team(
        name="Dynamic Warriors",
        created_by=u1.id
    )
    db.add(team)
    db.commit()

    # Add both to team members
    tm1 = TeamMember(team_id=team.id, user_id=u1.id, role="captain", status="active")
    tm2 = TeamMember(team_id=team.id, user_id=u2.id, role="player", status="active")
    db.add_all([tm1, tm2])
    db.commit()

    # 2. Query admin analytics
    res_analytics = client.get("/api/v1/admin/analytics", headers=admin_headers)
    assert res_analytics.status_code == 200
    data = res_analytics.json()
    assert "total_team_members" in data
    assert data["total_team_members"] == 2
    assert "total_players" in data  # Backwards compatibility check

    # 3. Query admin team members list
    res_members = client.get("/api/v1/admin/team-members", headers=admin_headers)
    assert res_members.status_code == 200
    members = res_members.json()
    assert len(members) == 2
    assert any(m["user_email"] == "member1@example.com" for m in members)
    assert any(m["user_email"] == "member2@example.com" for m in members)

    # 4. Search team members
    res_search = client.get("/api/v1/admin/team-members?search=Warriors", headers=admin_headers)
    assert res_search.status_code == 200
    assert len(res_search.json()) == 2

    res_search_email = client.get("/api/v1/admin/team-members?search=member2", headers=admin_headers)
    assert res_search_email.status_code == 200
    assert len(res_search_email.json()) == 1
    assert res_search_email.json()[0]["user_email"] == "member2@example.com"

    # 5. Delete team member
    member_to_delete = res_search_email.json()[0]["id"]
    res_del = client.delete(f"/api/v1/admin/team-members/{member_to_delete}", headers=admin_headers)
    assert res_del.status_code == 204

    # Verify count in db
    assert db.query(TeamMember).count() == 1


def test_admin_bulk_delete(client, db, admin_headers):
    # Setup users
    u1 = User(email="t1@example.com", username="t1", hashed_password=get_password_hash("Password123!"), role="user")
    u2 = User(email="t2@example.com", username="t2", hashed_password=get_password_hash("Password123!"), role="user")
    db.add_all([u1, u2])
    db.commit()

    # Setup teams
    team1 = Team(name="Team A", created_by=u1.id)
    team2 = Team(name="Team B", created_by=u2.id)
    db.add_all([team1, team2])
    db.commit()

    # Setup matches
    from datetime import datetime, timezone
    m1 = Match(venue="Ground A", team1_id=team1.id, team2_id=team2.id, status="scheduled", created_by=u1.id, match_date=datetime.now(timezone.utc), match_type="T20", over_limit=20)
    m2 = Match(venue="Ground B", team1_id=team1.id, team2_id=team2.id, status="scheduled", created_by=u2.id, match_date=datetime.now(timezone.utc), match_type="T20", over_limit=20)
    db.add_all([m1, m2])
    db.commit()

    # Setup tournaments
    from datetime import date
    tour1 = Tournament(name="Tour A", format="knockout", organizer_id=u1.id, status="upcoming", start_date=date.today(), end_date=date.today())
    tour2 = Tournament(name="Tour B", format="round_robin", organizer_id=u2.id, status="upcoming", start_date=date.today(), end_date=date.today())
    db.add_all([tour1, tour2])
    db.commit()

    # 1. Bulk Delete Tournaments
    res_t = client.post(
        "/api/v1/admin/tournaments/bulk-delete",
        json={"ids": [str(tour1.id), str(tour2.id)]},
        headers=admin_headers
    )
    assert res_t.status_code == 204
    assert db.query(Tournament).count() == 0

    # 2. Bulk Delete Matches
    res_m = client.post(
        "/api/v1/admin/matches/bulk-delete",
        json={"ids": [str(m1.id), str(m2.id)]},
        headers=admin_headers
    )
    assert res_m.status_code == 204
    assert db.query(Match).count() == 0

    # 3. Bulk Delete Teams
    res_team = client.post(
        "/api/v1/admin/teams/bulk-delete",
        json={"ids": [str(team1.id), str(team2.id)]},
        headers=admin_headers
    )
    assert res_team.status_code == 204
    assert db.query(Team).count() == 0

    # 4. Bulk Delete Users (Should soft-delete and exclude calling admin)
    admin_id = db.query(User).filter(User.email == "admin@example.com").first().id
    res_user = client.post(
        "/api/v1/admin/users/bulk-delete",
        json={"ids": [str(u1.id), str(u2.id), str(admin_id)]},
        headers=admin_headers
    )
    assert res_user.status_code == 204

    # Verify users are permanently deleted
    assert db.query(User).filter(User.id == u1.id).first() is None
    assert db.query(User).filter(User.id == u2.id).first() is None

    # Verify admin is NOT deleted
    admin_user = db.query(User).filter(User.email == "admin@example.com").first()
    assert admin_user.is_deleted is False
    assert admin_user.is_active is True
