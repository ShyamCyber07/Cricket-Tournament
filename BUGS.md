# BUGS.md - Identified Issues

## Critical Issues (P0)

### 1. CORS Allows All Origins
**Location**: `backend/app/main.py:166-171`
**Description**: CORS is configured with `allow_origins=["*"]`, allowing any domain to access the API
**Impact**: Security vulnerability - API can be accessed from any website
**Fix**: Restrict to specific domains or use environment-based configuration

### 2. Debug Endpoints Exposed
**Location**: `backend/app/main.py:219-276`
**Description**: Debug endpoints `/api/v1/debug-logs` and `/api/v1/debug-env` are accessible with a hardcoded secret
**Impact**: Information disclosure in production
**Fix**: Remove or properly secure these endpoints

### 3. SQLAdmin Accessible Without Authentication
**Location**: `backend/app/main.py:177-199`
**Description**: The `/admin` endpoint uses sqladmin but doesn't appear to have authentication middleware
**Impact**: Full database access without login
**Fix**: Add authentication to admin panel

### 4. Hardcoded Default Secrets
**Location**: `backend/app/core/config.py:10`
**Description**: Default SECRET_KEY is hardcoded: `"supersecretkeyforcricketscoringapp2026"`
**Impact**: If environment variable is not set, app uses insecure default
**Fix**: Require SECRET_KEY to be set in environment

---

## High Priority Issues (P1)

### 5. Timeline Does Not Update Instantly on Undo
**Location**: `frontend/lib/features/matches/screens/scoring_screen.dart:1142-1155`
**Description**: After undo, the timeline refreshes via API but may not show instant feedback
**Impact**: User confusion - undo feels sluggish
**Fix**: Update local state immediately before API call returns

### 6. Viewer Mode Shows Empty Container
**Location**: `frontend/lib/features/matches/screens/scoring_screen.dart:1926-1957`
**Description**: Viewer mode displays minimal UI - just "VIEWER MODE" text
**Impact**: Poor user experience for non-scorers
**Fix**: Implement full viewer mode with timeline, cards, stats

### 7. No Global Search
**Location**: Frontend - missing feature
**Description**: No search functionality for teams, players, tournaments, matches
**Impact**: Difficult to find entities
**Fix**: Implement global search with loading/empty states

---

## Medium Priority Issues (P2)

### 8. Stats Card Shows Fake Data
**Location**: `frontend/lib/features/dashboard/screens/dashboard_screen.dart:867-869`
**Description**: Stats show hardcoded values: `(_matches.length * 142)` and `(_matches.length * 8)`
**Impact**: Misleading statistics display
**Fix**: Calculate real statistics from backend

### 9. Potential Memory Leak in WebSocket
**Location**: `frontend/lib/features/matches/screens/scoring_screen.dart:393-439`
**Description**: WebSocket reconnect timer may not be cleared on dispose
**Impact**: Memory leak after navigating away
**Fix**: Cancel timers in dispose()

### 10. Missing Error Boundaries
**Location**: Frontend - general issue
**Description**: No global error boundaries for crash recovery
**Impact**: App may crash unexpectedly
**Fix**: Add Flutter error handling

---

## Minor Issues (P3)

### 11. Unused Scratch Files
**Location**: `scratch/` directory
**Description**: Over 150+ scratch files from testing
**Impact**: cluttered project
**Fix**: Clean up or archive scratch files

### 12. Inconsistent Naming
**Location**: Various files
**Description**: Mix of "CricUP", "CricHeroes", "Cricket Scorer" in project
**Impact**: Brand inconsistency
**Fix**: Standardize naming

### 13. Console Print Statements in Production Code
**Location**: Multiple files
**Description**: `print()` statements used for debugging
**Impact**: Performance impact, information leakage
**Fix**: Use proper logging

---

## Incomplete Features

### 14. Fantasy League (Not In Scope)
- Mentioned but should not be developed per requirements

### 15. Live Chat (Not In Scope)
- Not implemented, should remain out of scope

### 16. Prediction Systems (Not In Scope)
- Not implemented, should remain out of scope

---

## Summary
- **Critical**: 4 issues
- **High**: 3 issues  
- **Medium**: 3 issues
- **Minor**: 3 issues
- **Total**: 13 identified bugs/issues

**Recommended Focus**: Address P0 issues (security) before proceeding to Phase 2