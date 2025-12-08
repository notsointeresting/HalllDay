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
- [x] Google Cloud OAuth credentials created (IDK Can You project)
- [x] Environment variables ready (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`)
- [ ] Test login flow on staging/production (pending deployment)

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

### Step 5: Cleanup & Polish ⏳ PENDING (after deployment test)
- [ ] Remove legacy passcode login (after OAuth verified)
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