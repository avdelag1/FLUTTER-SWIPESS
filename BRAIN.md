# Flutter Swipess — Brain

This file is the standing memory for agents working in **FLUTTER-SWIPESS**.
Read it before changing UI, navigation, or product flow.

## Mission

Close the **design** of the live Capacitor app onto this Flutter rewrite.

- **Visual source of truth:** `avdelag1/swipess` (Capacitor + React + Tailwind + Framer Motion), live at https://www.swipess.com
- **This repo:** `avdelag1/FLUTTER-SWIPESS` — native Flutter shell
- **Admin (not this app):** `avdelag1/admin-swipess`

The Capacitor look is what the owner likes and wants kept. Do **not** invent a new visual language. Do **not** “simplify” glass, starfields, HUD chrome, or swipe physics into a generic Material demo.

A separate **bases** agent (or later pass) wires real Supabase, persistence, and native plugins. Design work may use in-memory session stubs so screens can be judged.

## Split of work

| Lane | Owns | Does not own |
|------|------|----------------|
| **Design (this brain)** | Pixel-faithful screens, tokens, motion, chrome, copy, empty/loading/error looks | Production auth, RLS, edge functions, IAP |
| **Bases** | Repositories, Supabase, session persistence, OAuth, access-code API | Redesigning screens |

If a task is “make it look like Capacitor,” stay in the design lane. Leave `TODO` / notifier stubs where a repository should go.

## Design tokens (must match Capacitor `src/styles/tokens.css`)

| Token | Value |
|-------|--------|
| Brand primary | `#FF4D00` |
| Brand primary 2 / 3 | `#FF6B35` / `#FF8C42` |
| Brand accent | `#EC4899` / `#E4007C` |
| Black matte / dash bg | `#0A0A0C` / `#0A0A0D` |
| Dash well | `#101014` |
| Font | Plus Jakarta Sans (black / italic kickers) |
| Card radius | ~40–48 |
| Glass | white hairline + blur + cinematic shadow |

Landing / gate / auth sit on **black + shooting-star field**, not a grey Material scaffold.

## Capacitor files to copy from

Clone or fetch `avdelag1/swipess` when matching UI. Primary references:

| Flutter surface | Capacitor source |
|-----------------|------------------|
| Access / secret code | `src/components/AccessCodeGate.tsx` |
| Welcome | `LegendaryLandingPage.tsx` → `LandingView` |
| Sign in / sign up | `LegendaryLandingPage.tsx` → `AuthView` |
| Dashboard HUD | `TopBar.tsx`, `BottomNavigation.tsx`, `chromeStyles.ts` |
| Category deck | `swipe/SwipeAllDashboard.tsx`, `PokerCategoryCard.tsx`, `CardData.ts` |
| Events teaser | `swipe/EventsVideoQuickFilter.tsx` |
| Swipe cards | `SimpleSwipeCard.tsx`, `SwipeActionButtonBar.tsx` |
| Stars | `LandingBackgroundEffects.tsx` |
| Tokens | `src/styles/tokens.css`, `matte-themes.css` |

Local override for the gate (Capacitor + current Flutter stub): access code **`URDBEST`**.

## Build order (do not skip ahead)

Close design in this order. Finish the look of a step before starting the next, unless the user names a different screen.

1. Secret code / access gate
2. Welcome / landing
3. Sign in + sign up options (email, Apple, Google, legal sheet)
4. Dashboard HUD (top glass pills, events teaser, category poker cards, bottom dock)
5. Listing / profile swipe deck (photo cards, LIKE/NOPE, glass action rail)
6. Remaining product surfaces (likes, messages, filters, profile, map, concierge) — still matching Capacitor, still design-first unless asked for bases

## Flutter architecture (non-negotiable)

- Riverpod for business / session state (`setState` only for local animation)
- GoRouter for routes
- Feature-first folders under `lib/src/features/`
- Supabase only behind repositories (when bases land)
- `flutter analyze` clean after every change
- Handle loading and error states; never a blank screen

## Current Flutter map

```
/access     AccessCodeScreen     (design stub)
/welcome    WelcomeScreen
/auth       AuthScreen
/dashboard  DashboardScreen
/swipes     existing CardSwiper demo (not yet Capacitor photo cards)
```

Session is in-memory (`SessionNotifier`). Real auth is a bases task.

## What “done” looks like for a screen

A Flutter screen is design-closed when someone who uses swipess.com would recognize it: same hierarchy, type, color, chrome, and motion — not merely the same brand orange on a default AppBar.
