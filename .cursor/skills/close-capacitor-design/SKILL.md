---
name: close-capacitor-design
description: Close Flutter Swipess UI to match the Capacitor swipess.com design. Use when building or restyling screens, chrome, tokens, motion, or when the user mentions Capacitor, swipess repo, visual parity, or “the design I like.”
---

# Close Capacitor design onto Flutter

## Goal

Make **this Flutter app look like** the production Capacitor app (`avdelag1/swipess`, https://www.swipess.com). The owner wants that design kept. Flutter is the native rewrite, not a new brand.

Read `BRAIN.md` first. Follow `AGENTS.md` for Riverpod / GoRouter / feature folders.

## Before writing widgets

1. Open the matching Capacitor file (table in `BRAIN.md`). Clone `https://github.com/avdelag1/swipess` to `/tmp/swipess` if it is not already available.
2. Note layout, type (Plus Jakarta Sans, italic kickers, tracking), color, radius, glass, and motion.
3. Port **look and interaction**, not React structure. Do not wrap a Material `AppBar` + two buttons and call it done.
4. Keep session/API as stubs if bases are not in scope (`SessionNotifier`, fake delays, snackbars on HUD icons).

## Hard rules

- Source of truth is Capacitor, not Material defaults and not a “cleaner” redesign.
- Reuse tokens in `lib/src/core/theme/app_theme.dart` (`#FF4D00`, `#EC4899`, black matte, glass pills).
- Gate / welcome / auth: black canvas + starfield, not `scaffoldBackgroundColor` grey.
- Dashboard: glass HUD + events teaser + photo category cards + floating dock.
- Copy brand assets from Capacitor `public/icons` and `public/images/filters` into `assets/` when needed.
- `flutter analyze` must stay clean. Prefer small widgets over giant `build` methods.

## Out of scope unless the user asks

Supabase auth, `validate-access-code`, OAuth, Mapbox, IAP, edge functions. Leave a short comment that bases will wire it.

## After the change

Walk the GoRouter flow (`/access` → `/welcome` → `/auth` → `/dashboard`). Gate demo code is `URDBEST`.
