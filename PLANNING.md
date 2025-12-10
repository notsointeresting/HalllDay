# IDK Can You? Development Plan

**Last Updated:** 2025-12-10

---
# 🚨 Current Issues
- Display Cache versus Roster Cache. Sometimes roster is in roster cache but not in display cache and scanning doesn't work. Not sure why there are two caches and why they are different, what the purpose is, if it is justified or not. 

## 🚨 Current Priorities (Immediate Focus)

### ⚙️ Phase 6: Admin & Dev Tools (Material 3 Port)
*Goal: Unified Material 3 Design for all surfaces.*
- [ ] **Admin Dashboard (`/admin`)**:
    - [ ] Port "Roster Management" and "Pass Logs".
    - [ ] Material 3 Data Tables and Charts.
- [ ] **Dev Dashboard (`/dev`)**:
    - [ ] Port "Database Tools" and "System Status".
    - [ ] Secure with PIN/Auth.

---

## 🔮 Future Roadmap

### 🖥️ Phase 7: Passive Display (Enhancements)
- [ ] **Sync**: Ensure Display state perfectly mirrors Kiosk state (latency < 1s).
- [] Build landing page with logo, sign up screen/login, and FAQ (explanation/introduction) or something. idkcanyou.com should default to the landing page (homepage)
### 🖥️ Phase 8 [Optional Queue System]
- [] Allow students to queue up for a pass optionally enabled by teacher on their admin panel. Will automatically assign a pass to the first person in the queue and then assign the next person in the queue to the next available pass.
- [] Build a scheduling system for times when kiosk is active and auto suspend when not; connected to admin panel as option and timezone selection. 

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