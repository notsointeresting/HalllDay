# IDK Can You? Development Plan

**Last Updated:** 2025-12-08

---

## 🚀 Phase 5: The Flutter Transition (Current Focus)
- Always maintain design consistency with material design materialdesign.md 
**Objective**: Migrate the frontend from vanilla HTML/JS/CSS to **Flutter Web** to achieve native app-like performance, Material 3 consistency, and complex animations (morphing shapes) without DOM limitations.

### 🏗️ P0 - Foundation & Connectivity ✅
- [x] **Project Setup**: Initialize `frontend` directory with a Flutter Web project.
- [x] **Asset Migration**: Port sounds and SVGs from `/static` to Flutter assets.
- [x] **API Layer**: Create a Dart service to communicate with existing Flask endpoints:
    - `POST /api/scan`: Handle barcode scans.
    - `GET /api/status`: Fetch initial state.
    - `GET /events`: Consume SSE (Server-Sent Events) for real-time updates.
- [x] **State Management**: Set up a robust state manager (Provider/Riverpod) to handle the "Session" and "Roster" data.

### 📱 P1 - The Kiosk (Interactive UI) ✅
*Goal: A fluid, touch-first experience for the iPad.*
- [x] **Scanning Engine**: Implement a "keyboard listener" in Flutter to capture barcode scanner input (HID mode).
- [x] **Home Screen (Idle)**:
    - Implement the "Breathing/Morphing" background shapes using Flutter `CustomPainter` or Lottie.
    - Status Indicator: "Available" vs "Occupied" with smooth color transitions.
- [ ] **Action Feedback**:
    - **Success**: satisfying "pop" animation and sound when a pass is granted.
    - **Failure/Ban**: "Shake" or "Burst" animation with strict haptic/visual feedback.
- [ ] **Timer/Session View**: A clear countdown or elapsed time view for the active pass.

### 🖥️ P2 - The Display (Passive UI)
*Goal: The "Always On" classroom board.*
- [ ] **Read-Only Mode**: A simplified view that consumes the `/events` stream.
- [x] **Visual Overhaul**: Switch to **Colored Backgrounds** + **White Bubbles** to match the original "light" aesthetic. <!-- id: 11 -->
- [ ] **Final Polish**: Fix black flash on transitions. Replace gradient with Material-aligned color interpolation. <!-- id: 13 -->
- [ ] **Big Typography**: Ensure names and timers are legible from the back of the room.
- [ ] **Sync**: Ensure Display state perfectly mirrors Kiosk state (latency < 1s).

## P3: Display & Audio
- [ ] **Display App Port**: Migrate the public `display.html` view to Flutter (`/display` route). <!-- id: 14 -->
- [ ] **Sound Effects**: Port custom sounds (Grant, Deny, Ban) to Flutter. <!-- id: 15 -->
- [ ] **Build Pipeline**: Script to build Flutter Web (`flutter build web --renderer html`) and copy artifacts to Flask's `/static` folder.
- [ ] **Flask Routing**: Update `app.py` to serve the Flutter `index.html` for `/kiosk` and `/display` routes.
- [ ] **Cleanup**: Remove legacy `kiosk.js`, `display.js`, and `shapes` folders once verify.

---

## ✅ Completed History

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