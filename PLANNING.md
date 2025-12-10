# IDK Can You? Development Plan

**Last Updated:** 2025-12-10

---
## 🚨 Current Priorities (Immediate Focus)

### 1. Visual Polish & Haptics
- [ ] **Haptics/Feedback**: "Shake" screen on error.
- [ ] **Expressive Overdue**: Bubbles should rotate/wobble when overdue.

### 2. Critical Bug Fixes
- [ ] **Timer Lag**: Fix timer skipping seconds.
- [ ] **Color Logic**: Green for available, Yellow only for warning/overdue.
- [ ] **Layout**: Fix centering and single-element off-center issues.
- [ ] **Auto Ban**: Verify auto-ban logic in Flutter.

---

## 🔮 Future Roadmap

### ⚙️ Phase 6: Admin & Dev Tools (Material 3 Port)
*Goal: Unified Material 3 Design for all surfaces.*
- [ ] **Admin Dashboard (`/admin`)**:
    - [ ] Port "Roster Management" and "Pass Logs".
    - [ ] Material 3 Data Tables and Charts.
- [ ] **Dev Dashboard (`/dev`)**:
    - [ ] Port "Database Tools" and "System Status".
    - [ ] Secure with PIN/Auth.

### 🖥️ Phase 7: Passive Display (Enhancements)
- [ ] **Sync**: Ensure Display state perfectly mirrors Kiosk state (latency < 1s).

---

## ✅ Completed History

### Phase 5 - Flutter Transition (Core)
**Status**: Core Functional Port Complete (2025-12-10)
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