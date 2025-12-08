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
- [ ] Default Landing Page for the website for sign in/sign up/FAQ what is the app/Joke on "Can I use the restroom;IDK Can You?" currently at halllday.onrender.com but will be moved to idkcanyou.com. 
- [ ] Move "Database Maintenance" button to /dev (not /admin)
- [ ] Make suspend kiosk button on admin page more prominent towards the top, have tip for command shortcut next to it or under.
- [ ] Embed Code for iframe generation should be for /display and not for /kiosk 

### P3 - Cleanup
- [ ] Full code audit
- [ ] Remove dead code

---

## Notes



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