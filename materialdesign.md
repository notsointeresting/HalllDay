# Material 3 Expressive — Reference Guide

## Introduction  
Material 3 Expressive (M3) evolves the core of Material Design 3 by adding deeper theming, expressive shapes, refined typography, and physics-driven motion. The goal: create UI that feels intentional, emotionally resonant, and accessible. :contentReference[oaicite:2]{index=2}

---

## Core Principles  

- **Emotion + Function**: The interface should convey tone (friendly, bold, calm, energetic…) while remaining usable. Expressiveness is not decoration. :contentReference[oaicite:3]{index=3}  
- **Visual clarity & perceptual hierarchy**: Typography, shapes, color and motion work together to guide user attention and distinguish importance. :contentReference[oaicite:4]{index=4}  
- **Accessibility & adaptability**: From dynamic colors to responsive typography, components must work for a variety of users, devices, and contexts. :contentReference[oaicite:5]{index=5}  

---

## Style Systems  

### 🎨 Color / Theming  
- Use M3’s tonal palettes (dynamic or brand-driven) rather than fixed color codes. Scheme should cover semantic roles: primary, secondary, background, surface, error, etc. :contentReference[oaicite:6]{index=6}  
- If dynamic coloring is used, derive colors algorithmically from a source (user wallpaper or brand color), then map to tonal palettes for cohesion and accessibility. :contentReference[oaicite:7]{index=7}  

### 🅰️ Typography  
- Adopt M3’s type scale: categories such as Display, Headline, Title, Body, Label — each available in large / medium / small variants. :contentReference[oaicite:8]{index=8}  
- Prefer variable fonts (with adjustable weight, width, etc.) to allow expressive typography that adapts to context — for emphasis, hierarchy, or responsive layout. :contentReference[oaicite:9]{index=9}  
- Use clearly defined typographic roles depending on UI context (e.g. headlines, body text, captions, labels) to maintain consistency across components. :contentReference[oaicite:10]{index=10}  

### ▭ Shape / Containers / Layout  
- M3 Expressive includes an expanded “shape language” — dozens of shapes, corner-radius tokens, and morphable containers. Use shape tokens rather than hard-coded border radii. :contentReference[oaicite:11]{index=11}  
- Combine shapes with typographic and color decisions to build harmonious, intentional layouts. Shape should help communicate hierarchy, containment, or interactivity. :contentReference[oaicite:12]{index=12}  
- Use container shapes that adapt: groups, cards, buttons, adaptive containers — especially important for responsive and cross-device UIs. :contentReference[oaicite:13]{index=13}  

---

## Motion & Interaction (Transitions, Animations, Physics)  

- M3 Expressive replaces static easing/duration animations with a **physics-based motion system**: springs, natural-decay, fluid transitions. Animations feel alive, responsive, and less mechanical. :contentReference[oaicite:14]{index=14}  
- Use motion to communicate function/state: transitions, shape-morphing, micro-interactions, feedback. Motion isn’t decoration — it clarifies interaction, not distracts. :contentReference[oaicite:15]{index=15}  
- Apply motion consistently across components: navigation, buttons, lists, state changes, transitions — coherence makes the “feel” part of the language. :contentReference[oaicite:16]{index=16}  

---

## Components & Patterns (Expressive-aware)  

M3 Expressive introduces (or updates) components designed to leverage its expanded style system. Examples: button groups, split-buttons, expressive FAB menus, adaptive toolbars, flexible containers. :contentReference[oaicite:17]{index=17}  

These components inherit theme, typography, shape, motion — making it easier to build cohesive, expressive UI rather than patchwork styles. :contentReference[oaicite:18]{index=18}  

---

## Implementation Recommendations  

- Use **design tokens** (colors, typography roles, shape tokens, motion tokens) instead of hard-coded values.  
- Adopt variable fonts when possible to enable expressive typography that adapts to context (emphasis, screen size, accessibility).  
- Use the shape system to drive container design: cards, buttons, groups, adaptive layouts — leverage corner-radius tokens and shape morphing where appropriate.  
- Implement motion using physics-based animation defaults: natural springs, fluid transitions — avoid arbitrary or purely decorative animations.  
- Always keep accessibility in mind: ensure contrast, touch-target sizes, readable typography, and support for dynamic theming or user preferences.  
- Prefer M3 Expressive–aware components (or design your components following the same patterns) to ensure consistency.  

---

## When to use (and when to pause)  

M3 Expressive adds personality and emotional resonance — ideal for products where branding, engagement, visual identity matter. But “expressive” ≠ always better. In contexts where clarity, minimal distraction, or familiarity are more important (e.g. enterprise tools, data-heavy dashboards, banking interfaces), a more restrained approach may serve better. :contentReference[oaicite:19]{index=19}  

Expressiveness must support functionality, not interfere with it.  

---

## Summary  

M3 Expressive offers a robust, research-grounded extension of Material Design: deeper theming, expressive shapes, variable typography, and motion grounded in physics — all layered to build UI that feels alive, intentional, and accessible. When used with discipline, these tools let you craft interfaces that don’t just function — they communicate mood, brand, and purpose.  

Use this guide as the anchor. Revisit official docs when updating or extending components.  
# Material 3 Expressive Design System: Agentic Guidelines

**STATUS:** MANDATORY  
**CONTEXT:** FLUTTER / DART  
**OBJECTIVE:** Override default "functional" Material 3 traits with "Expressive" traits (emotion, bounce, shape-shifting).

---

## 1. MOTION PHYSICS & SPRINGS (The "Bounce" Rule)
**Rule:** NEVER use standard easing curves (e.g., `Curves.easeIn`, `Curves.linear`) for interactive elements.
**Requirement:** ALL interactions must use **Spring Physics**.

### Agent Implementation Strategy:
Instead of `Duration` + `Curve`, use physical simulations (`stiffness` and `damping`).

**Standard vs. Expressive Mapping:**
* **Standard (Functional):** Low bounce. `damping: 1.0` (Critical Damping).
* **Expressive (Emotional):** Overshoots target. `damping: 0.7 - 0.8`.

#### Code Reference (Flutter):
Use `SpringSimulation` or `flutter_animate` for all state changes.

```dart
// BAD (Old Trope):
// AnimatedContainer(duration: Duration(milliseconds: 300), curve: Curves.easeOut);

// GOOD (Expressive):
// Use physics-based animation controllers.
final SpringDescription kExpressiveSpring = SpringDescription(
  mass: 1,
  stiffness: 150, // Higher = snappier
  damping: 12,    // Lower = more bounce/overshoot
);

// Or using 'flutter_animate' package:
// .animate().scale(curve: Curves.elasticOut, duration: 600.ms) // Simplified approximation
// Example: A Card that morphs shape on touch
AnimatedContainer(
  duration: Duration(milliseconds: 400),
  curve: Curves.fastLinearToSlowEaseIn, // Or use Spring
  decoration: BoxDecoration(
    color: isActive ? colorScheme.primaryContainer : colorScheme.surface,
    // Morphing Corner Radius
    borderRadius: isActive 
        ? BorderRadius.circular(4.0) // Becomes sharp/functional on focus
        : BorderRadius.circular(28.0), // Soft/playful at rest
  ),
);