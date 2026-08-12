# AI Agent Instructions (AGENTS.md)

Welcome, fellow AI Agent. This is **Flutter Swipess** — a native rewrite of the Capacitor app **Swipess**.

**Read `BRAIN.md` first.** Then `docs/DESIGN_CONTRACT.md`. Those files are the project brain: mission, design source of truth, and screen order.

## 0. Design source of truth (non-negotiable)

We are **closing the Capacitor design onto Flutter**, not inventing a new look.

- Visual / UX source of truth: GitHub `avdelag1/swipess` (live: https://www.swipess.com and https://swipess.app)
- Clone it (`git clone --depth 1 https://github.com/avdelag1/swipess.git /tmp/swipess`) and match the Capacitor file for the screen you are building.
- This repo must look like that app: italic **SWIPESS** wordmark, black canvas, pill chrome, orange-red `#FF4D00` CTAs, glass HUD, photo category cards, floating glowing dock, full-bleed swipe reel.
- If it looks like a generic Flutter demo (Material AppBar, gradient orbs, Tinder circles, missing wordmark), it is **wrong**.
- “Aesthetics are paramount” means **pixel-faithful to Capacitor**, not a new glassmorphism concept.
- Always-on rule: `.cursor/rules/match-capacitor-design.mdc`
- Skills: `.cursor/skills/close-capacitor-design/SKILL.md` and `.cursor/skills/swipess-build-order/SKILL.md`
- Copy-paste prompts for the owner: `docs/PROMPTS.md`

**Build order:** access gate → welcome → sign in/sign up → dashboard → photo swipe deck → remaining surfaces.

Design passes may stub auth. A **bases** agent wires Supabase repositories, real OAuth, and persistence — without restyling.

## 1. Core Architecture
- **State Management**: We use **Riverpod** (`flutter_riverpod`). Do NOT use raw `setState` for anything beyond simple local UI animations. All business logic must live in Notifier/AsyncNotifier classes.
- **Routing**: We use **GoRouter** for clean, declarative, and deep-linkable navigation.
- **Backend integration**: We use **Supabase**. All Supabase queries must be abstracted behind a Repository layer (e.g., `UserRepository`, `SwipeRepository`). Never call Supabase directly from the UI.

## 2. Folder Structure (Feature-First)
We organize code by feature, NOT by type.
```text
lib/
  src/
    features/
      swipes/
        presentation/ (Widgets, Screens, Controllers)
        domain/ (Models, Entities)
        data/ (Repositories, API calls)
      auth/
        ...
    core/
      theme/ (Colors, Typography)
      utils/ (Helpers)
      constants/
      services/ (Supabase initialization, logging)
```

## 3. UI / UX Principles
- **Match Capacitor first**: tokens, type, chrome, glow, and motion from `avdelag1/swipess`. See `docs/DESIGN_CONTRACT.md`.
- **Performance**: Ensure 60fps (or 120fps) by avoiding expensive rebuilds. Use `const` widgets everywhere possible.
- **Components**: Break down complex UI into small, reusable, stateless widgets. Avoid giant `build` methods.

## 4. Code Quality
- All new files must be completely free of analyzer warnings. Run `flutter analyze` after every modification.
- Document any complex business logic with clear docstrings.
- Always handle loading states and error states gracefully (never just show a blank screen).

Follow these rules exactly. Close the Swipess design. Do not invent a replacement.
