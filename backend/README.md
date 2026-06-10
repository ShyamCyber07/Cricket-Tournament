# CricHeroes MVP - Backend API Server

This is the production-ready FastAPI backend for the Android-first cricket scoring application. It uses a Clean Architecture layer separation and provides a complete database scoring state machine, live statistics compilation, and an administrative dashboard interface.

---

## 1. Core Technologies

- **FastAPI**: Modern, high-performance web framework for APIs.
- **SQLAlchemy (ORM)**: Decoupled transactional database mapper.
- **SQLite (Local fallback)**: Zero-config file database used for instant local verification and testing.
- **PostgreSQL (Production target)**: Production-ready relational storage.
- **SQLAdmin**: Administrative web dashboard that integrates with SQLAlchemy models.

---

## 2. API Endpoints Reference

Once the server is running, the interactive visual documentation is automatically available at:
* **Swagger UI**: `http://localhost:8000/api/v1/docs`
* **Redoc**: `http://localhost:8000/api/v1/redoc`

### Primary Endpoints:
- `POST /api/v1/auth/signup` - Register scorer profile (automatically spawns corresponding player profile)
- `POST /api/v1/auth/login` - Retrieve access token via standard OAuth2 password flow
- `POST /api/v1/auth/google` - Sign in/register with Google credentials placeholder
- `GET /api/v1/players/{id}/stats` - Auto-compiled career batting (avg, strike rate, high score) & bowling (econ, wickets, hauls) statistics
- `POST /api/v1/teams/{id}/players` - Team roster member assignment
- `POST /api/v1/matches/{id}/balls` - Live scoring engine ball input (calculates score updates, boundary logs, wickets, over completions, and strike rotation)
- `POST /api/v1/matches/{id}/undo` - Full state rollback undo operation for the last logged ball

---

## 3. SQLAdmin Administrative Portal

You can manage all database tables (users, players, squads, match stats, and ball logs) via the admin panel.
* **URL**: `http://localhost:8000/admin`
* Visual list, search filters, and edit forms are auto-generated.

---

## 4. Local Quick Start

### 1. Set Up Environment
Ensure a stable production release of Python (**Python 3.10, 3.11, or 3.12**) is installed. *Note: Python 3.14+ is not recommended for local setup yet due to breaking C-API deprecations in Python that prevent compilation of Rust-based dependency wheels like Pydantic-Core.*

Create a virtual environment and install dependencies:
```bash
# Verify Python version (use python3.11 or python3.12 if available)
python --version

python -m venv venv
venv\Scripts\activate  # Windows
source venv/bin/activate  # macOS/Linux

# Install packages
pip install -r backend/requirements.txt
```

### 2. Run the App
Start the development server using Uvicorn:
```bash
uvicorn app.main:app --reload
```
On boot, the SQLite database `cricket.db` will automatically initialize.

---

## 5. PostgreSQL Production Setup

To switch from SQLite to production PostgreSQL:

1. Create a `.env` file in the `backend/` directory:
   ```env
   DATABASE_URL=postgresql://<user>:<password>@<host>:<port>/<db_name>
   SECRET_KEY=yoursecretkeyhere
   ```
2. Uncomment `psycopg2-binary` in `backend/requirements.txt` and install it.
3. Run the uvicorn command. The system will auto-initialize the database schema tables in PostgreSQL on startup.

---

## 6. Generated Database DDL (PostgreSQL Schema)

Below is the complete database schema DDL script for manual migration or setup:

```sql
-- Create custom tables for CricHeroes MVP

CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255),
    google_id VARCHAR(255) UNIQUE,
    full_name VARCHAR(255) NOT NULL,
    profile_photo_url VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE players (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL, -- batsman, bowler, all_rounder, wicket_keeper
    batting_style VARCHAR(50) NOT NULL,
    bowling_style VARCHAR(50) NOT NULL,
    profile_photo_url VARCHAR(255)
);

CREATE TABLE teams (
    id UUID PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    logo_url VARCHAR(255),
    captain_id UUID REFERENCES players(id) ON DELETE SET NULL,
    created_by UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE team_players (
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    player_id UUID REFERENCES players(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (team_id, player_id)
);

CREATE TABLE tournaments (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    organizer_id UUID REFERENCES users(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    format VARCHAR(50) NOT NULL, -- T20, ODI, Test, Custom
    banner_url VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tournament_teams (
    tournament_id UUID REFERENCES tournaments(id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    PRIMARY KEY (tournament_id, team_id)
);

CREATE TABLE matches (
    id UUID PRIMARY KEY,
    tournament_id UUID REFERENCES tournaments(id) ON DELETE SET NULL,
    team1_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    team2_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    match_date TIMESTAMP WITH TIME ZONE NOT NULL,
    venue VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'scheduled', -- scheduled, toss, team_selection, innings1, innings2, completed, abandoned
    match_type VARCHAR(50) NOT NULL,
    over_limit INTEGER NOT NULL,
    toss_winner_id UUID REFERENCES teams(id) ON DELETE SET NULL,
    toss_decision VARCHAR(10), -- bat, bowl
    winner_id UUID REFERENCES teams(id) ON DELETE SET NULL,
    win_margin_runs INTEGER,
    win_margin_wickets INTEGER,
    current_striker_id UUID REFERENCES players(id) ON DELETE SET NULL,
    current_non_striker_id UUID REFERENCES players(id) ON DELETE SET NULL,
    current_bowler_id UUID REFERENCES players(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE match_squads (
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    player_id UUID REFERENCES players(id) ON DELETE CASCADE,
    is_playing_xi BOOLEAN DEFAULT TRUE,
    is_captain BOOLEAN DEFAULT FALSE,
    is_wicketkeeper BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (match_id, team_id, player_id)
);

CREATE TABLE innings (
    id UUID PRIMARY KEY,
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    innings_number INTEGER NOT NULL, -- 1 or 2
    batting_team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    bowling_team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    total_runs INTEGER DEFAULT 0,
    total_wickets INTEGER DEFAULT 0,
    total_overs REAL DEFAULT 0.0,
    extras_byes INTEGER DEFAULT 0,
    extras_legbyes INTEGER DEFAULT 0,
    extras_wides INTEGER DEFAULT 0,
    extras_noballs INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE
);

CREATE TABLE balls (
    id UUID PRIMARY KEY,
    innings_id UUID REFERENCES innings(id) ON DELETE CASCADE,
    over_number INTEGER NOT NULL,
    ball_number INTEGER NOT NULL,
    bowler_id UUID REFERENCES players(id) ON DELETE CASCADE,
    batsman_id UUID REFERENCES players(id) ON DELETE CASCADE,
    non_striker_id UUID REFERENCES players(id) ON DELETE CASCADE,
    runs_batsman INTEGER DEFAULT 0,
    runs_extras INTEGER DEFAULT 0,
    extra_type VARCHAR(50) DEFAULT 'none', -- wide, no_ball, bye, leg_bye, none
    is_wicket BOOLEAN DEFAULT FALSE,
    wicket_type VARCHAR(50), -- bowled, caught, lbw, run_out, stumped, hit_wicket, retired_hurt, none
    player_dismissed_id UUID REFERENCES players(id) ON DELETE SET NULL,
    fielder_id UUID REFERENCES players(id) ON DELETE SET NULL,
    commentary TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```
