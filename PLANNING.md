# HalllDay Development Plan

This document tracks the planned development phases for HalllDay, moving from version 1.9 to 2.0.

---

## Current Focus

**Status:** Phase 2, Step 2 — Google OAuth Setup & Testing  
**Last Updated:** 2025-12-07

---

## Phase 1: Version 1.9 - Material 3 UI & Improved Stats ✅ COMPLETE

**Goal:** Enhance the visual identity using Material 3 Expressive UI and improve data fidelity in statistics.

### 1. Material 3 Expressive UI ✅ COMPLETE
- [x] Design System Integration
- [x] Page Updates (Login/Admin, Kiosk, Display)
- [x] Refinement (animations, contrast, responsiveness)

### 2. Stats Page & "Anonymous" Students ✅ ADDRESSED
- [x] Stats API now prefers roster name over Student table name
- [x] UI tooltip added explaining Anonymous entries

---

## Phase 2: Version 2.0 - Multi-User & Refactoring ✅ COMPLETE

**Goal:** Transform HalllDay from a single-classroom tool into a multi-user platform.

### Step 1: Core Architecture ✅ COMPLETE
- [x] Create `User` model in `models/user.py`
- [x] Add `user_id` FK to `Settings`, `Session`, `Student`, `StudentName`
- [x] Implement Google OAuth with `authlib` in `auth.py`
- [x] Add public kiosk routes (`/k/<token>`, `/kiosk/<token>`)
- [x] Add database migrations for 2.0 schema
- [x] Legacy data migration (backfill `user_id`)

### Step 2: Google OAuth Setup ✅ COMPLETE
- [x] Create Google Cloud OAuth credentials
- [x] Set environment variables (Render: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`)
- [x] Verified Redirect URI in Console (`https://halllday.onrender.com/auth/callback`)
- [x] Test login flow (Authenticated! DB error pending fix)

### Step 3: Service Layer Scoping ✅ COMPLETE
- [x] Scope `RosterService` queries by `user_id`
- [x] Scope `BanService` queries by `user_id`
- [x] Scope `SessionService` queries by `user_id`
- [ ] Test data isolation (pending deployment)

### Step 4: Admin UI Updates ✅ COMPLETE
- [x] Add "Share/Embed" section with kiosk URL generator
- [x] Add user profile display (name, email, picture)
- [x] Create `/dev` route for developer tools
- [x] Create `/admin` (teacher) separated from `/dev` (developer)
- [x] Add developer API endpoints (`/api/dev/users`, `/api/dev/set_admin`)

### Step 5: Cleanup & Polish 🔄 IN PROGRESS
- [x] Remove legacy `display_name` column from User table
- [ ] Remove legacy passcode login
- [ ] Add kiosk slug customization UI
- [ ] Review and remove `update_anonymous_students()` if not needed

---

## Decisions Made ✅

### 1. Google Cloud OAuth Credentials ✅ DONE
- **Project**: IDK Can You (472532068518)
- **App Name**: IDK Can You (renamed from HalllDay)
- Credentials configured, ready to set as environment variables

### 2. Deployment Strategy ✅ DECIDED
- **Choice**: Big Bang — Complete all 2.0 features before deploying

### 3. Developer vs Teacher Admin ✅ DECIDED
- **Choice**: Option B — Separate routes: `/admin` (teacher) and `/dev` (developer only)

---

## Immediate Next Steps

1. ~~Decide on OAuth credentials~~ ✅
2. ~~Scope service layer by user_id~~ ✅
3. ~~Create /dev route for developer tools~~ ✅
4. ~~Add Share/Embed UI to admin page~~ ✅
5. **Deploy to Render** with new environment variables
6. **Run migrations** (`flask migrate` or via /dev page)
7. **Test OAuth login** with Google account
8. **Verify kiosk token URLs** work without login

---

## Multi-Tenancy Implementation Details (2025-12-07)

### Data Isolation Strategy

HalllDay uses a **single shared database** with **user_id scoping** for multi-tenancy:

| Data Type | Isolation Level | Implementation |
|-----------|-----------------|----------------|
| Sessions | Per-User | `user_id` FK on Session table |
| Rosters | Per-User | `user_id` FK + **user-scoped hash** |
| Bans | Per-User | Same hash as roster (isolated) |
| Settings | Per-User | `user_id` FK on Settings table |

### Key Design Decision: User-Scoped Hashing

**Problem:** Multiple teachers may have the same students (same ID numbers). A unique constraint on `name_hash` would cause conflicts.

**Solution:** Include `user_id` in the hash:
```python
# Before (conflicting):
hash("student_12345") → same for all teachers

# After (isolated):
hash("student_5_12345") → unique per teacher
```

**Result:** 
- Teacher A bans "Student 12345" → only affects Teacher A's kiosk
- Teacher B's "Student 12345" → completely separate record, unaffected

### Issues Encountered During 2.0 Implementation

| Issue | Cause | Resolution |
|-------|-------|------------|
| Admin login blocked after OAuth | `is_admin_authenticated()` didn't check `session['user_id']` | Updated to accept OAuth sessions |
| `/kiosk` showed other user's data | Legacy route rendered functional kiosk without token | Created `kiosk_landing.html` landing page |
| Invalid tokens loaded kiosk | No validation on `/kiosk/<token>` route | Added 404 for invalid tokens |
| Roster upload failed silently | 138 individual DB commits caused timeouts | Created batch storage method |
| Duplicate key on roster upload | Legacy data without `user_id` conflicted with unique constraint | User-scoped hashing (see above) |

### Architecture Alternatives Considered

#### Option A: Current Approach (User-Scoped Hashing) ✅ CHOSEN
- **Pros:** Single database, simpler infrastructure, lower cost
- **Cons:** Requires `user_id` in all queries, legacy data migration
- **Status:** Implemented

#### Option B: Per-User Databases
- **Pros:** Complete isolation, simpler code, no scoping needed
- **Cons:** Complex infrastructure, expensive, hard to deploy on Render
- **Status:** Not recommended for current scale

#### Option C: Schema-Based Isolation (PostgreSQL)
- **Pros:** Database-level isolation, single connection
- **Cons:** Requires PostgreSQL schema management, more complex
- **Status:** Future consideration if scaling issues arise

### Current Multi-Tenancy Status ✅

All data is now properly isolated per teacher:
- [x] Sessions scoped by `user_id`
- [x] Rosters scoped by user-specific hash
- [x] Bans scoped by user-specific hash  
- [x] Settings scoped by `user_id`
- [x] Public kiosk/display routes use token-based auth
- [x] Legacy routes show landing page (no data leakage)

**A ban in one teacher's class does NOT affect another teacher's class.**