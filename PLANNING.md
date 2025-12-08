# IDK Can You? Development Plan

**App Name:** IDK Can You? (formerly HalllDay)  
**Last Updated:** 2025-12-07

---

## Current Status: Phase 2.1 - Critical Fixes

### Issues Identified

| Priority | Issue | Status |
|----------|-------|--------|
| P0 | Settings shared across all users | 🔴 |
| P0 | Kiosk suspend (Ctrl+Shift+S) broken | 🔴 |
| P1 | Google Sheets tracking needs removal | 🟡 |
| P1 | App still branded "HalllDay" | 🟡 |
| P2 | No dev page to manage users | 🟡 |
| P3 | Dead code needs cleanup | ⚪ |

---

## Phase 2.1 Roadmap

### 1. Fix Settings Isolation 🔴 CRITICAL
- Each user gets their own Settings record
- Room name, capacity, overdue limit, kiosk_suspended isolated per user
- Remove fallback to global Settings (ID=1)

### 2. Fix Kiosk Suspend 🔴 CRITICAL  
- Keyboard shortcut must pass user token
- Per-user suspend state (not global)

### 3. Remove Sheets Integration
- Delete all Sheets-related code
- Keep CSV export as alternative

### 4. Rebrand to "IDK Can You?"
- Update landing page, templates, titles
- New logo/branding throughout

### 5. Developer Dashboard
- View all users, their data
- Manage users, reset rosters
- System statistics

### 6. Code Audit & Refactor
- Ensure all queries filter by `user_id`
- Remove dead code
- Document architecture

---

## Multi-Tenancy Architecture (Implemented)

| Data | Isolation Method |
|------|------------------|
| Sessions | `user_id` FK |
| Rosters | User-scoped hash |
| Bans | User-scoped hash |
| Settings | `user_id` FK (needs fix) |

**Key:** Each teacher's data is completely isolated. Same student ID in different classes = different database records.

---

## Completed Phases

- ✅ Phase 1: Material 3 UI
- ✅ Phase 2.0: Multi-user architecture, OAuth, public kiosk URLs