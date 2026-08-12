# Reusable prompts

Paste these into a new agent when starting a pass. They assume this repo (`FLUTTER-SWIPESS`) plus the Capacitor app `avdelag1/swipess`.

---

## Close the design (Flutter ← Capacitor)

```text
You are working in FLUTTER-SWIPESS. Read BRAIN.md, AGENTS.md, and the skills
close-capacitor-design + swipess-build-order before writing code.

Mission: close the DESIGN of the production Capacitor app onto Flutter.
Source of truth is avdelag1/swipess (https://www.swipess.com) — the look I
already like. Do not invent a new visual system. Do not ship generic Material
(AppBar + two round buttons) and call it Swipess.

Clone or inspect avdelag1/swipess and match the current step’s screens
(layout, type, color, glass, motion, copy).

Build order unless I name a screen:
1) secret code / access gate
2) welcome / landing
3) sign in + sign up options (email, Apple, Google, legal)
4) dashboard HUD (top glass pills, events teaser, category poker cards, dock)
5) photo swipe deck
6) rest of the product, still matching Capacitor

Architecture: Riverpod, GoRouter, feature-first folders, flutter analyze clean.
Keep auth/Supabase as stubs unless I ask for bases — another agent will wire
repositories, real access-code validation, and OAuth.

Gate demo code: URDBEST.
```

---

## Bases only (do not restyle)

```text
You are the bases agent for FLUTTER-SWIPESS. Read BRAIN.md and AGENTS.md.

Do not restyle screens. The Capacitor design is already being ported and I
want that look kept.

Wire real foundations under the existing UI:
- Repository layer for Supabase (never call Supabase from widgets)
- Persist access grant and session
- Real access-code validation and auth (email, Apple, Google)
- Loading / error against live data, same visual chrome

Match existing Riverpod / GoRouter / feature-first structure.
```
