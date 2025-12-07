# HalllDay Development Plan

This document tracks the planned development phases for HalllDay, moving from version 1.9 to 2.0.

---

## Current Focus

**Status:** Phase 1, Goal 2 — Stats Page & "Anonymous" Students  
**Note:** While implementing Goal 2, keep an eye toward laying the groundwork for Phase 2 (2.0) architecture, but do not begin full 2.0 implementation yet.

---

## Phase 1: Version 1.9 - Material 3 UI & Improved Stats

**Goal:** Enhance the visual identity using Material 3 Expressive UI and improve data fidelity in statistics.

### 1. Material 3 Expressive UI ✅ COMPLETE
Use the assets and guidelines in `design_system/` to overhaul the frontend.
- [x] **Design System Integration**:
    - Update `style.css` to define CSS variables for Material 3 colors (primary, secondary, tertiary, surface, error, etc.) based on the provided design kit.
    - Implement M3 typography scales.
    - Apply M3 shapes (using the SVG shapes in `design_system/shapes/` as references or background masks) to cards, buttons, and containers.
    - Replace the pulsing animation of shapes to actually morph and move akin to Material 3 Expressive guidelines 
- [x] **Page Updates**:
    - **Login/Admin**: Re-style input fields, buttons, and "chips" for settings.
    - **Kiosk**: Make the "Scan ID" area a prominent, accessible M3 surface.
    - **Display**: Update the status cards and lists to match the new aesthetic.
    - **Responsiveness**: Ensure layouts adapt gracefully to mobile, tablet, and desktop (using flexbox/grid and M3 breakpoints).
- [x] **Refinement**:
    - Scale typography and shapes to fill the viewport for an immersive experience.
    - Add entrance animations for text and icons.
    - Increase contrast and saturation for better visibility from a distance.

### 2. Stats Page & "Anonymous" Students ✅ COMPLETE
**Goal:** Remove "Anonymous" student entries from stats and prioritize actual student data.

- [ ] **Current Behavior Analysis**:
    - Currently, if a student ID is scanned but not found in the uploaded roster, a `Student` record is created with the name `Anonymous_{ID}`.
    - The stats page queries the `Student` table directly.
    - Even if a roster is uploaded *later*, the `Student` record remains "Anonymous..." because the Roster Service (`StudentName` table) is decoupled from the `Session` foreign key (`Student` table).

- [ ] **Implementation Plan**:
    - **Retroactive Naming**: Implement a mechanism so that when a roster is uploaded, the system checks for any existing "Anonymous" students in the `Student` table with matching IDs and updates their names to the real values.
    - **UI Explanation**: Add a tooltip or note on the stats page explaining that "Anonymous" entries appear only when IDs are scanned without a loaded roster, and uploading a roster will fix them.
    - **Display**: Ensure the Stats API (`/api/stats/week`) prefers the Roster Service name (if available) over the fallback `Student` table name if they differ.

## Phase 2: Version 2.0 - Multi-User & Refactoring

> ⏳ **Not yet in active development.** Keep these goals in mind as groundwork when implementing Phase 1 features, but do not begin full implementation.

**Goal:** Transform HalllDay from a single-classroom tool into a multi-user platform.

### 1. Architecture Decisions
- **Multi-Tenancy**:
    - The database schema must be updated to associate `Sessions`, `Settings`, and `Students` (rosters) with a specific `User` (Teacher/Classroom).
    - Current: Global `Settings` (ID=1).
    - Future: `Settings` table will have a `user_id` FK.

- **Authentication**:
    - **Action**: Replace the simple passcode system with **Google Authentication** (OAuth2).
    - Allow users to "Sign Up/Login" with their Google Workspace account.

### 2. Routing & Displays
- **Decision**: How to route displays?
    - **Recommendation**: Hybrid approach.
        - **Admin/Dashboard**: Auto-routed based on logged-in user.
        - **Kiosk/Display**: Should *not* require Google Login (kiosks are often public/shared devices). Instead, generate **Unique Public URLs** (e.g., `halllday.com/kiosk/TOKEN` or `halllday.com/room/MrSmith`).
- [ ] **Iframe Generation**:
    - Add a "Share/Embed" button on the Admin page that generates an `<iframe>` code snippet pointing to the user's public Display URL.

### 3. Roster Management Strategy
- **Decision**: Campus vs. Teacher Roster?
    - **Selected Approach**: **Teacher-Uploaded Roster**.
    - **Reasoning**: This scales better for a multi-user app where a central campus database integration isn't feasible. It allows each teacher to manage their own students.
    - **Implication**: `Student` IDs might collide if two teachers use the same ID system (e.g., simple numbers "1", "2").
    - **Refactor**: Roster lookups must be scoped to the `User`. (e.g., Student ID "123" for Teacher A might be "John", but "123" for Teacher B might be "Jane").

### 4. Preparation Steps for 2.0
- [ ] Create a `User` model.
- [ ] Refactor `Settings` to link to `User`.
- [ ] Refactor `Session` queries to filter by current user.
- [ ] Implement `flask-dance` or `authlib` for Google Auth.
- [ ] **Refactor Note**: Review `update_anonymous_students()` in `services/roster.py` — may be legacy code to remove since stats API now does roster lookups directly.
- [ ] Remove legacy developer tools from admin page that will not be used in 2.0 by teachers (migration, etc)
- Still need an "admin" page for teachers to manage their classes, and an "admin" page for the HalllDay developer to manage the app. Need to determine the best route for this. 
- [ ] Remove legacy login logic from the Admin page.