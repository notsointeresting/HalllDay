# IDK Can You? Development Plan

**Last Updated:** 2025-12-07

---

## Current Status: Phase 2.1 - Critical Fixes

### P0 - Complete ✅
- [x] Settings isolated per user (room name, capacity, overdue, suspend)
- [x] Kiosk suspend keyboard shortcut working per user

### P1 - In Progress 🔄
- [ ] Remove Google Sheets integration
- [ ] Rebrand "HalllDay" → "IDK Can You?"
- [ ] Remove legacy passcode login

### P2 - Pending
- [ ] Developer dashboard (view users, rosters)
- [ ] Move "Database Maintenance" button to /dev (not /admin)

### P3 - Cleanup
- [ ] Full code audit
- [ ] Remove dead code

---

## Notes

### Known Issues
- **Ctrl+Shift+S double-registers**: Keyboard event may fire twice. Need to add debounce or check in `kiosk.js`

### Architecture Decisions
- **Database Maintenance**: Should be dev-only, not shown to teachers
- **Settings**: Each user gets auto-created Settings record on first login
- **Rosters**: User-scoped hash ensures same student ID doesn't conflict across teachers

---

## Multi-Tenancy Status ✅

| Data | Isolation |
|------|-----------|
| Sessions | Per-user |
| Rosters | User-scoped hash |
| Bans | User-scoped hash |
| Settings | Per-user (auto-created) |