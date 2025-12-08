# IDK Can You? Development Plan

**Last Updated:** 2025-12-07

---

## Phase 2.1 - Complete ✅

### P0 - Critical Fixes ✅
- [x] Settings isolated per user
- [x] Kiosk suspend shortcut fixed

### P1 - Cleanup & Rebranding ✅
- [x] Remove Google Sheets UI
- [x] Rebrand to "IDK Can You?"
- [x] Suspend button on admin
- [x] Embed code for /display
- [x] OAuth only (passcode removed)

### P2 - Dev Dashboard ✅
- [x] User roster counts added
- [x] DB maintenance on /dev

### P3 - Code Audit ✅
- [x] Full code audit
- [x] Remove dead code (Sheets integration removed)

---

## Multi-Tenancy Architecture ✅

| Data | Isolation | Status |
|------|-----------|--------|
| Sessions | Per-user | ✅ Secure |
| Rosters | User-scoped hash | ✅ Secure |
| Settings | Per-user | ✅ Secure |

---

## Pre-Launch Verification 🚀

**Status: READY FOR LAUNCH**

### 🛡️ Security & Isolation
- **Data Isolation**: Verified. Queries scope strictly to `user_id`.
- **Real-time State**: Verified. SSE streams are user-scoped; no cross-tenant leakage.
- **Kiosk Security**: Verified. Public routes enforce valid tokens.

### ⚠️ Implementation Notes
1.  **Eventual Consistency**: Multi-worker setups may have slight delays in cache updates (roster names). Use restart if critical.
2.  **Concurrency**: PostgreSQL transaction rollback in SSE loop ensures freshness.

### 📋 Pre-Flight Checklist
- [x] **OAuth**: Add `idkcanu.com` & `halllday.onrender.com` to Google Console.
- [ ] **Env Vars**: Verify `SECRET_KEY` strength in production.
- [ ] **Backup**: Optional DB snapshot via Render/Dev tools.