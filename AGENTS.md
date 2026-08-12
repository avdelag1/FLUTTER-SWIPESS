# AI Agent Instructions (AGENTS.md)

Welcome, fellow AI Agent. This is **Flutter Swipess** — a native rewrite of the Capacitor app **Swipess**.

**Read `BRAIN.md` first.** It is the project brain: mission, design source of truth, and screen order.

## 0. Design source of truth

We are **closing the Capacitor design onto Flutter**, not inventing a new look.

- Visual / UX source of truth: GitHub `avdelag1/swipess` (live: https://www.swipess.com)
- This repo must look like that app (glass HUD, starfield gate/welcome/auth, category poker cards, brand tokens).
- If it looks like a generic Flutter demo, it is wrong.
- Skills: `.cursor/skills/close-capacitor-design/SKILL.md` and `.cursor/skills/swipess-build-order/SKILL.md`
- Copy-paste prompts: `docs/PROMPTS.md`

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
- **Match Capacitor first**: tokens, type, chrome, and motion from `avdelag1/swipess`.
- **Aesthetics are paramount**: Use smooth, native-feeling animations, gradients, glassmorphism, and micro-interactions. If it looks basic, you have failed.
- **Performance**: Ensure 60fps (or 120fps) by avoiding expensive rebuilds. Use `const` widgets everywhere possible.
- **Components**: Break down complex UI into small, reusable, stateless widgets. Avoid giant `build` methods.

## 4. Code Quality
- All new files must be completely free of analyzer warnings. Run `flutter analyze` after every modification.
- Document any complex business logic with clear docstrings.
- Always handle loading states and error states gracefully (never just show a blank screen).

Follow these rules exactly, and we will build the best native swiping app in the world.
