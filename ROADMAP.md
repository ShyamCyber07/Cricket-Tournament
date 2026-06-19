# CRICUP Stabilization Sprint - Roadmap

## Phase Overview

### Phase 1: Codebase Audit (COMPLETED)
- Analyze entire project
- Identify bugs, incomplete features, dead code, security issues
- Generate: ROADMAP.md, BUGS.md, IMPROVEMENTS.md

### Phase 2: Scorer Timeline
**Status**: Not Started
- Implement professional ball-by-ball timeline
- Current Over display: `1 | 4 | WD | 0 | W | 6`
- Recent Balls display with coordinates
- Undo must update timeline instantly

### Phase 3: Viewer Mode Overhaul
**Status**: Not Started
- Ball-by-ball timeline
- Recent overs
- Partnership card
- Batter card
- Bowler card
- Match information
- Better spacing and typography

### Phase 4: Search
**Status**: Not Started
- Global search for teams, players, tournaments, matches
- Loading states and empty states

### Phase 5: Security Review
**Status**: Not Started
- CORS configuration
- Admin permissions
- SQLAdmin access
- Upload endpoints
- JWT auth

### Phase 6: Testing
**Status**: Not Started
- Build release APK
- Physical device verification
- Full walkthrough

---

## Implementation Priority

### P0 - Critical (Security & Core Functionality)
1. Fix CORS allow_origins (currently "*")
2. Secure/remove debug endpoints
3. Protect SQLAdmin access
4. Scorer timeline implementation
5. Undo timeline sync fix

### P1 - High (User Experience)
1. Viewer mode overhaul
2. Global search implementation
3. Loading/empty states

### P2 - Medium (Polish)
1. Performance optimization
2. Code cleanup
3. Documentation

---

## Notes
- Do not add new major features
- Do not work on fantasy league, live chat, ads, streaming, prediction systems, sponsor banners, or social features
- Preserve existing auth, scoring engine, and API contracts
- Verify everything on physical Android device