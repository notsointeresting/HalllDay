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

## Phase 3 - UI/UX Overhaul & Polish (Fluid Motion) ✅
**Status**: Completed (2025-12-08)

### P0 - Core UX Improvements ✅
- [x] **Multi-Pass UI**: Split-screen (2 students) and Grid Layout (3+ students) with fluid transitions.
- [x] **Shape Morphing**: "Alive" bubbles that squash/stretch based on velocity and state.
- [x] **Expressive Motion**: Physics-based springs for all interactions (entry, exit, state change).
- [x] **Sound Design**: Custom soundscapes for positive (scan) and negative (ban/deny) actions.

### P1 - Visual Consistency ✅ 
- [x] **Banned State**: Distinct "Red/Black" banned UI to clearly differentiate from "Limit Reached".
- [x] **Bold Colors**: Switched from pastel containers to **Vibrant/Saturated** backgrounds (Deep Green, Strong Red, Amber).
- [x] **Typography**: Switched to **Inter** for cleaner, professional legibility.
- [x] **Iconography**: Fixed "Pass_" glitch and removed overlapping background icons.

### P2 - Documentation ✅
- [x] **Replaced README**: Fully rewritten to reflect current feature set (Multi-Pass, Fernet Encryption, Dev Dashboard).
- [x] **Removed Legacy**: Deleted all references to Google Sheets integration.

---

## Phase 4 - Future Roadmap (Next Steps) 🔮

### P1 - Mobile & PWA
- [ ] **Manifest & Service Worker**: Make the Kiosk a true PWA (installable on iPad home screen).
- [ ] **Offline Resilience**: Queue scans if network drops and sync when back online.
- [ ] **Wake Lock**: Prevent Kiosk screen from dimming/sleeping during class.

### P2 - Deployment Hardening
- [ ] **Production Config**: Verify `gunicorn` worker settings for SSE scaling (gevent/eventlet recommended).
- [ ] **Database Migration**: Ensure proper migration scripts for `alembic` if schema evolves further.
- [ ] **Stress Testing**: Simulate 30+ simultaneous kiosks to verify SSE connection stability.

### P3 - Advanced Features
- [ ] **Insights Dashboard**: "Who leaves the most?" analytics for teachers.
- [ ] **Digital Passes**: Apple Wallet / Google Wallet pass integration for students (long-term).