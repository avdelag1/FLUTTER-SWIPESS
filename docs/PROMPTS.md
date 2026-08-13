# How to brief the next agent

Agents only follow what is **in this repo** plus **the prompt you paste**. Merging the brain/rules is step one. Pasting one of these prompts is step two.

---

## Core design prompt (attach to EVERY request)

Neo-naive / Cap tokens. Source of truth is still `avdelag1/swipess` — clone to `/tmp/swipess` and match the real screen. Do not invent radio (removed). Do not ship Material AppBars.

```text
UI / UX AESTHETIC DIRECTIVE: Flutter Swipess uses a neo-naive aesthetic.
Match the original React/Capacitor project.

Canvas: Colors.black / Color(0xFF0A0A0D). Use AmbientPageBackground
(monochrome wells — no colorful orbs).
Brand primary: #FF4D00 for CTAs, active tabs, highlights.
Type: GoogleFonts.plusJakartaSans. Headers w900 italic letterSpacing: -1.0.
Cards: frosted glass Colors.white.withAlpha(12), border white.withAlpha(25),
radius 24 — or Cap neo-naive ink-stamp frames (NeoNaiveCard / NeoNaiveGroup).
Buttons: stadium pills (radius 999), #FF4D00, bold caps letterSpacing 2.0.
Inputs: GlassTextField only. Never Material TextField chrome.
If it looks like a standard Material app, it failed.
```

Shared widgets: `AmbientPageBackground`, `NeoNaiveScaffold`, `NeoNaiveCard`,
`NeoNaiveGroup`, `NeoNaiveChip`, `GlassTextField`, `BrandPrimaryButton`,
`PulsingVerifiedBadge`.

---

## Close the design (Flutter ← Capacitor)

Use this when you want screens to look like swipess.com / the screenshots you already have.

```text
You are working in FLUTTER-SWIPESS. Before writing any UI, read BRAIN.md,
docs/DESIGN_CONTRACT.md, AGENTS.md, and the skills close-capacitor-design
+ swipess-build-order.

Mission: close the DESIGN of the production Capacitor app onto Flutter.
Source of truth is avdelag1/swipess (https://www.swipess.com / swipess.app)
— the look I already like and screenshotted. Do not invent a new visual
system. Do not ship generic Material (AppBar, gradient orbs, Tinder circles)
and call it Swipess.

Clone avdelag1/swipess to /tmp/swipess and match the current step’s screens
(layout, type, color, glass, glow, motion, copy, wordmark).

Build order unless I name a screen:
1) secret code / access gate
2) welcome / landing (LOG IN + CREATE ACCOUNT)
3) sign in + sign up options (email, Apple, Google, legal)
4) dashboard HUD (glow search, category pills, photo cards, floating dock)
5) photo swipe deck (full-bleed card, glass HUD, side rail, price overlay)
6) rest of the product, still matching Capacitor

Architecture: Riverpod, GoRouter, feature-first folders, flutter analyze clean.
Keep auth/Supabase as stubs unless I ask for bases.

Gate demo code: URDBEST.
```

---

## One named screen only

```text
You are working in FLUTTER-SWIPESS. Read BRAIN.md and docs/DESIGN_CONTRACT.md.

Restyle THIS screen to match avdelag1/swipess (clone to /tmp/swipess):
[NAME THE SCREEN: access gate | welcome | auth | dashboard | swipe deck]

Do not invent a new look. Do not restyle other screens. Do not wire new
Supabase unless I ask. flutter analyze must stay clean.
```

---

## Bases only (do not restyle)

```text
You are the bases agent for FLUTTER-SWIPESS. Read BRAIN.md and AGENTS.md.

Do not restyle screens. The Capacitor design is the look I want kept.

Wire real foundations under the existing UI:
- Repository layer for Supabase (never call Supabase from widgets)
- Persist access grant and session
- Real access-code validation and auth (email, Apple, Google)
- Loading / error against live data, same visual chrome

Match existing Riverpod / GoRouter / feature-first structure.
```
