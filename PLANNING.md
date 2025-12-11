# IDK Can You? Development Plan

**Last Updated:** 2025-12-10

---
# 🚨 resolved Issues
- [x] Room name not showing up in top.
- [x] Landing page / home page should be the default page when visiting idkcanyou.com, not the logged in kiosk. auto login is great, but we should have a way to navigate to the kiosk from the landing page and all the other pages should be accessible from every page in tabs or hamburger menu up to date with material design 3 expressive guidelines. 
- [x] Pass logs function but is not exportable to CSV. Need that implemented. 
- [x] https://www.idkcanu.com/logout is not working not a proper URL. should logout and then redirect to landing page. 

## 🚨 Current Priorities (Immediate Focus)

### ⚙️ Phase 6: Admin & Dev Tools (Material 3 Port)
*Goal: Unified Material 3 Design for all surfaces.*
- [ ] **Admin Dashboard (`/admin`)**:
    - [ ] **Roster Management**:
        - [x] Manual Ban List (View all students, toggle ban status).
        - [x] Roster Clear: Ensure session history is cleared (or properly handled) to remove "Anonymous" ghost stats.
    - [x] Port "Pass Logs".
    - [ ] Material 3 Data Tables and Charts.
    - [ ] A CSV template or instructions for uploading a roster properly (header row, id, name). 
- [ ] **Dev Dashboard (`/dev`)**:
    - [ ] Port "Database Tools" and "System Status".
    - [ ] Secure with PIN/Auth.
    - [ ] More robust ability to manage users, see active sessions/passes etc in /dev

---

## 🔮 Future Roadmap

### 🖥️ Phase 7: Passive Display (Enhancements)
- [ ] **Sync**: Ensure Display state perfectly mirrors Kiosk state (latency < 1s).
- [x] Build landing page with logo, sign up screen/login, and FAQ (explanation/introduction) or something. idkcanyou.com should default to the landing page (homepage) and have tabs or some way to navigate to the admin, kiosk and display pages. I think this may have already been started by an agent but it was not completed or not properly implemented. 
### 🖥️ Phase 8 [Optional Queue System]
- [] Allow students to queue up for a pass optionally enabled by teacher on their admin panel. Will automatically assign a pass to the first person in the queue and then assign the next person in the queue to the next available pass.
- [] Build a scheduling system for times when kiosk is active and auto suspend when not; connected to admin panel as option and timezone selection. T

### 📡 Phase 9: Server-Sent Events (SSE) Optimization
*Goal: Replace polling with push-based updates for efficiency.*
- [ ] **Backend**: Add `/api/stream` endpoint using Flask SSE (generator with `yield`).
- [ ] **Frontend**: Replace `Timer.periodic` polling with `EventSource` listener in Kiosk/Display.
- [ ] **Benefits**: ~99% fewer requests, instant updates (<100ms latency), reduced server load.


## ✅ Completed History

### Phase 5 - Flutter Transition (Core & Polish)
**Status**: Core Functional Port Complete (2025-12-10)

#### 🎨 Visual Polish & Haptics
- [x] **Haptics/Feedback**: "Shake" screen on error.
- [x] **Expressive Overdue**: Bubbles wobble when overdue.

#### 🐛 Critical Bug Fixes
- [x] **Timer Lag**: Fixed timer skipping seconds.
- [x] **Color Logic**: Green for available, Yellow only for warning/overdue.
- [x] **Layout**: Fixed centering and single-element off-center issues.
- [x] **Auto Ban**: Verify auto-ban logic in Flutter.

#### 🏗️ P0 - Foundation & Connectivity
- [x] **Project Setup**: Initialize `frontend` directory with a Flutter Web project.
- [x] **Asset Migration**: Port sounds and SVGs from `/static` to Flutter assets.
- [x] **API Layer**: Create a Dart service to communicate with existing Flask endpoints.
- [x] **State Management**: Set up a robust state manager (Provider/Riverpod).

#### 📱 P1 - The Kiosk (Interactive UI)
- [x] **Scanning Engine**: Implement a "keyboard listener" in Flutter.
- [x] **Home Screen (Idle)**:
    - [x] **Physics**: Custom Spring Simulation.
    - [x] **Bubbles**: "Cell Division" spawning.
    - [x] **Sound**: Web Audio API Synthesizer.

#### 🖥️ P2 - The Display (Passive UI)
- [x] **Display Port**: Read-only view with large typography (`/display`).

### Phase 3 - UI/UX Overhaul & Polish (Web Version)
**Status**: Completed (2025-12-08)
- [x] **Multi-Pass UI**: Split-screen and Grid Layouts.
- [x] **Shape Morphing**: CSS/JS implementation of squircle->star morphs.
- [x] **Expressive Motion**: Spring physics for web elements.
- [x] **Sound Design**: Custom soundscapes.
- [x] **Visual Refresh**: Bold colors and Inter typography.

### Phase 2.1 - Backend & Admin
**Status**: Completed (2025-12-07)
- [x] **Multi-Tenancy**: Isolated settings per user.
- [x] **Admin Ops**: Rebranded to "IDK Can You?", removed Sheets, fixed Kiosk suspend.
- [x] **Dev Dashboard**: Added DB maintenance tools.

### Phase 1 - Core Logic (Legacy)
- [x] Basic Check-in/Check-out.
- [x] Auto-Ban logic.
- [x] Roster encryption (Fernet).