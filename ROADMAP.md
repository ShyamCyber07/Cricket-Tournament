# CRICUP Stabilization Sprint - Roadmap

## Phase Overview

### Phase 1: Codebase Audit (COMPLETED)
- Analyze entire project
- Identify bugs, incomplete features, dead code, security issues
- Generate: ROADMAP.md, BUGS.md, IMPROVEMENTS.md

### Phase 2: Scorer Timeline (COMPLETED)
- ✅ Professional ball-by-ball timeline
- ✅ Current Over display with coordinates (12.1, 12.2, etc.)
- ✅ Recent Balls display with coordinates
- ✅ Last 2 Overs summary panel
- ✅ Undo shows instant feedback

### Phase 3: Viewer Mode Overhaul
**Status**: In Progress
- Ball-by-ball timeline ✅ (from Phase 2)
- Recent overs ✅ (from Phase 2)
- Partnership card (existing)
- Batter card (existing)
- Bowler card (existing)
- Match information
- Better spacing and typography

### Phase 4: Search
**Status**: Not Started
- Global search for teams, players, tournaments, matches
- Loading states and empty states

### Phase 5: Security Review (COMPLETED)
- ✅ CORS configuration restricted
- ✅ Admin permissions protected
- ✅ SQLAdmin access with auth
- ✅ Debug endpoints disabled in production
- ✅ SECRET_KEY validation
- Generated: SECURITY_AUDIT.md, SECURITY_DEPLOYMENT_VERIFICATION.md

### Phase 6: Testing
**Status**: Not Started
- Build release APK
- Physical device verification
- Full walkthrough

---

## Implementation Priority

### P0 - Critical (Security & Core Functionality)
1. ✅ Fix CORS allow_origins
2. ✅ Secure/remove debug endpoints
3. ✅ Protect SQLAdmin access
4. ✅ Scorer timeline implementation
5. ✅ Undo timeline sync fix

### P1 - High (User Experience)
1. Viewer mode overhaul (in progress)
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