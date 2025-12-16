# IDK Can You? Development Plan

**Last Updated:** 2025-12-15

---

# 🚨 Current Priorities (Immediate Focus)
[x] Biggest Priority: For some reason the flutter implementation is causing the input to stop registering at times through the day... **FIXED**: Implemented aggressive focus reclamation on app resume and a periodic 2s timer to ensure the hidden input field always has focus on the kiosk screen. 


[x] Admin Charts: Fixed "Most Overdue" and "Top Users" graphs by moving aggregation to Python and ensuring proper name resolution for active/historic sessions.
[x] Active Session Management: added "Live Activity" section to Admin Dashboard with list of active sessions (with End/Ban buttons) and Waitlist (with Remove/Reorder capability). Fixed bugs where section was not visible and added auto-refresh.
[X] Auth page looks kinda ugly Fixed: Took care of with CSS 
[x] Refined/Animated Logo: Fixed transparency (using SVG mask) and added "float" animation. Using `currentColor` for context-aware styling.
[] Unified Navigation: Implemented `AppNavDrawer` (Hamburger Menu) available on Landing, Admin, and Dev screens. Includes links to Home, Dashboard -- Still need links to kiosk and display for that user. 
- [] admin page not responsive on mobile 
- [] No "account creation" step. Google Auth seems to work but no account creation step to customize experience and feel like you are establishing a account. If that makes sense. it works...but it just feels so automatic I don't even know if it's a true account Almost makes it feel insecure even if it is secure. If that makes sense. Profile picture, slug option, optional name, etc. I am not sure if this is a good idea and don't want to mess up already made accounts. 
- [] Fleshed out Dev dashboard with ability to see active users (teachers) and details about sessions while not exposing student data (maintain FERPA compliance). See statistics or active passes without being attached to a specific student data so dev can see usage statistics and activity. 
- [ ] Dev Dashboard should not be in menu navigation. That is private. It should only be landing page, kiosk, display, admin to travel between eachother.

## ⚙️ Phase 6: Admin & Dev Tools (Material 3 Port)
*Goal: Unified Material 3 Design for all surfaces.*

- [ ] **Admin Dashboard (`/admin`)**:
    - [x] **Admin Login UI**: Revamped with Material 3 card layout.
    - [x] **Roster Management**: Manual Ban List & View.
    - [x] **Pass Logs**: Ported to Flutter.
    - [x] **Roster Clear**: Implemented backend endpoint and frontend controls for clearing session history and roster data.
    - [ ] **CSV Import/Export**: Template instructions and export functionality.
    - [ ] **Data Tables**: Refine with Material 3 sorting/filtering.
- [ ] **Dev Dashboard (`/dev`)**:
    - [ ] **Port Tools**: Database Maintenance & System Status.
    - [ ] **Security**: PROTECT with PIN/Auth and/or Google Auth to maintain FERPA compliance.
    - [ ] **User Management**: robust ability to manage users/active sessions.

---

# 🔮 Future Roadmap

- [] Dark mode option 


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