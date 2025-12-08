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

### P3 - Future Cleanup
- [ ] Full code audit
- [ ] Remove dead code

---

## Multi-Tenancy ✅

| Data | Isolation |
|------|-----------|
| Sessions | Per-user |
| Rosters | User-scoped hash |
| Settings | Per-user |