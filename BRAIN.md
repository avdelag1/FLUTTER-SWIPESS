# Flutter Swipess — Brain

Standing memory for every agent in **FLUTTER-SWIPESS**. Read this before changing UI, navigation, or product flow.

## Mission

Close the **design of the live Capacitor app** onto this Flutter rewrite.

| Repo | Role |
|------|------|
| `avdelag1/swipess` | **Visual / UX source of truth.** Capacitor + React + Tailwind + Framer Motion. Live: https://www.swipess.com and https://swipess.app |
| `avdelag1/FLUTTER-SWIPESS` | Native Flutter shell. Must **look like** the Capacitor app. |
| `avdelag1/admin-swipess` | Admin. Not this app. |

The owner already has a finished look they like. Flutter is a **native port**, not a new brand and not a “cleaner Material redesign.”

If a screen would not be recognized by someone who uses swipess.com, it is not done.

## Why previous Flutter screens do not match

Earlier agents on `main` treated AGENTS.md’s “make it beautiful” line as permission to invent glass orbs, gradient icon tiles, and Tinder-style circular buttons.

That is the failure mode. **Do not continue it.**

| Surface | What Capacitor actually is | What `main` currently is (wrong) |
|---------|----------------------------|----------------------------------|
| Access gate | Black canvas, SWIPESS wordmark, lock card, pill code field, white Enter + key, “See What’s New” | Centered glass card, gradient swipe icon, colored orbs |
| Welcome | Centered italic **SWIPESS**, white **LOG IN**, orange-red **CREATE ACCOUNT**, tiny footer | Missing. Login is combined into one screen |
| Auth | Pill email/password, Remember me / Forgot, orange-red LOG IN, dark CREATE AN ACCOUNT, white Apple/Google | Glass card, social-first, gradient Sign In |
| Dashboard | Neon-glow search, colored category pills, photo grid, floating glowing dock | Generic AppBar + list / placeholder tabs |
| Swipe deck | Full-bleed rounded photo, floating glass HUD, side action rail, price overlay | Tinder card + five colored circular buttons |

Clone the source when matching UI:

```bash
git clone --depth 1 https://github.com/avdelag1/swipess.git /tmp/swipess
```

## Split of work

| Lane | Owns | Does not own |
|------|------|----------------|
| **Design** | Pixel-faithful screens, tokens, motion, chrome, copy, empty/loading/error looks | Production auth, RLS, edge functions, IAP |
| **Bases** | Repositories, Supabase, session persistence, OAuth, access-code API | Redesigning screens |

If the task is “make it look like Capacitor / the screenshots / swipess.com,” stay in the design lane. Leave `TODO` / notifier stubs where a repository should go.

## Design tokens (from Capacitor `src/styles/tokens.css` + `matte-themes.css`)

| Token | Value |
|-------|--------|
| Brand primary (CTA, YES, active) | `#FF4D00` |
| Brand primary 2 / 3 | `#FF6B35` / `#FF8C42` |
| Brand accent (pills, likes) | `#EC4899` / `#E4007C` |
| Brand gradient | `135deg` accent → primary |
| Gate / welcome / auth canvas | `#000000` + starfield |
| Dash bg / well / elevated | `#0A0A0D` / `#101014` / `#16161C` |
| Font | Plus Jakarta Sans (black / italic kickers, wide tracking on wordmark) |
| Pills | `borderRadius: 999` (stadium) |
| Cards | ~28–48 radius, hairline `rgba(255,255,255,0.10–0.28)` |
| Glass | white hairline + blur 16–40 + cinematic shadow |
| Glow | thin neon outline on search + bottom dock (`BoxShadow` blur, not a fat Material elevation) |

Landing / gate / auth sit on **black + shooting-star field**, not grey Material `scaffoldBackgroundColor`.

## Capacitor files to copy from

| Flutter surface | Capacitor source |
|-----------------|------------------|
| Access / secret code | `src/components/AccessCodeGate.tsx` |
| Welcome | `LegendaryLandingPage.tsx` → `LandingView` |
| Sign in / sign up | `LegendaryLandingPage.tsx` → `AuthView` |
| Stars / canvas | `LandingBackgroundEffects.tsx` |
| Dashboard HUD | `TopBar.tsx`, `BottomNavigation.tsx`, `src/utils/chromeStyles.ts` |
| Category deck | `swipe/SwipeAllDashboard.tsx`, `PokerCategoryCard.tsx`, `CardData.ts` |
| Events teaser | `swipe/EventsVideoQuickFilter.tsx` |
| Events feed | `pages/EventosFeed.tsx` |
| Swipe cards | `SimpleSwipeCard.tsx`, `SwipeActionButtonBar.tsx` |
| Tokens | `src/styles/tokens.css`, `matte-themes.css` |
| Wordmark / logo | `public/icons/Swipess-wordmark-white.svg`, `Swipess-brand-logo-transparent.png` |

Local override for the gate (Capacitor + Flutter): access code **`URDBEST`**.

## Build order (do not skip ahead)

Close **design** in this order. Finish the look of a step before starting the next, unless the user names a different screen.

1. Secret code / access gate
2. Welcome / landing (LOG IN + CREATE ACCOUNT)
3. Sign in + sign up options (email, Apple, Google, legal)
4. Dashboard HUD (search, category pills, photo grid / poker cards, floating dock)
5. Listing swipe deck (full-bleed photo, glass HUD, side rail, price overlay)
6. Remaining surfaces (likes, messages, filters, profile, map, concierge) — still matching Capacitor

## Flutter architecture (non-negotiable)

- Riverpod for business / session state (`setState` only for local animation)
- GoRouter for routes
- Feature-first folders under `lib/src/features/`
- Supabase only behind repositories (when bases land)
- `flutter analyze` clean after every change
- Handle loading and error states; never a blank screen

## Current Flutter map on `main` (starting point, not the target)

```
/gate       AccessCodeGateScreen   — restyle to Capacitor gate
/login      LoginScreen            — split into /welcome + /auth
/dashboard  DashboardShell         — restyle to HUD + category deck
swipe tab   SwipeTabContent        — restyle to full-bleed reel card
events tab  EventsScreen           — restyle to neon search + photo grid
```

Target flow after the design port:

```
/access  →  /welcome  →  /auth  →  /dashboard  →  swipe deck
```

## What “done” looks like for a screen

Someone who uses swipess.com would recognize it: same hierarchy, type, color, chrome, and motion — not merely brand orange on a default AppBar.

See `docs/DESIGN_CONTRACT.md` for the visual checklist of the five primary surfaces.
