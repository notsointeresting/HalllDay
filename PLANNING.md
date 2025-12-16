# IDK Can You? Development Plan

**Last Updated:** 2025-12-15

---

# 🚨 Current Priorities (Immediate Focus)

## ⚙️ Phase 6: Admin & Dev Tools (Material 3 Port)
*Goal: Unified Material 3 Design for all surfaces.*

- [ ] **Admin Dashboard (`/admin`)**:
    - [x] **Roster Management**: Manual Ban List & View.
    - [x] **Pass Logs**: Ported to Flutter.
    - [ ] **Roster Clear**: Ensure session history is cleared (remove "Anonymous" ghost stats).
    - [ ] **CSV Import/Export**: Template instructions and export functionality.
    - [ ] **Data Tables**: Refine with Material 3 sorting/filtering.
- [ ] **Dev Dashboard (`/dev`)**:
    - [ ] **Port Tools**: Database Maintenance & System Status.
    - [ ] **Security**: PROTECT with PIN/Auth.
    - [ ] **User Management**: robust ability to manage users/active sessions.

---

# 🔮 Future Roadmap

## 🖥️ Phase 7: Passive Display (Enhancements)
- [ ] **Sync**: Ensure Display state perfect mirrors Kiosk state (latency < 2s via polling).
- [ ] **Customization**: School-specific branding/colors.

## 📅 Scheduling System
- [ ] Auto-suspend kiosks based on time/timezone.
- [ ] Admin panel for scheduling hours.

---

# ✅ Completed History

### Phase 9 - Real-Time Updates (Polling Strategy)
**Status**: Completed (2025-12-15) - *SSE Attempted & Reverted*
- [x] **Investigation**: Implemented SSE, encountered HTTP/2 protocol errors with Cloudflare/Proxies.
- [x] **Decision**: Reverted to **Polling** (2s interval).
    - **Why?** More reliable, simpler, scales perfectly for kiosk traffic (~15 req/s per school).
- [x] **Implementation**: Cleaned up `status_provider.dart` to use efficient timer-based polling.
- [x] **Backend**: Optimized Gunicorn with threads (`--workers=2 --threads=8`) to handle concurrent polling.
- [x] **Authentication Fix**: Removed `gevent` dependency which caused SSL recursion errors with Google Auth.

### Phase 8 - Landing Page Redesign
**Status**: Completed (2025-12-15)
- [x] **Visual Redesign**:
    - [x] **Hero**: Stronger copy ("Hall passes without the chaos").
    - [x] **Hierarchy**: Primary "Dashboard" vs Secondary "How it works".
    - [x] **Cards**: Sculptural "Enter your room" card with pill shapes.
- [x] **Assets**:
    - [x] **Logo Fix**: Switched to SVG for perfect scaling using `flutter_svg`.
    - [x] **Rendering**: Fixed "black box" SVG issue by inverting fill colors.
- [x] **FAQ**: Renamed to "Before you ask" with icons and refined answers.

### Phase 5 - Flutter Transition (Core & Polish)
**Status**: Core Functional Port Complete (2025-12-10)
- [x] **Kiosk UI**: Physics bubbles, sound synth, scanning engine.
- [x] **Responsiveness**: Adaptive layouts for mobile/desktop.
- [x] **State Management**: Provider-based architecture.
- [x] **API Layer**: Dart services for Flask backend.

### Phase 3 - UI/UX Overhaul (Web Version)
**Status**: Completed (2025-12-08)
- [x] **Motion**: Spring physics & shape morphing.
- [x] **Sound**: Custom soundscapes.
- [x] **Visuals**: Material 3 Expressive design.

### Phase 2 - Backend & Admin
**Status**: Completed (2025-12-07)
- [x] **Multi-Tenancy**: Isolated user settings.
- [x] **Security**: Roster encryption (Fernet).