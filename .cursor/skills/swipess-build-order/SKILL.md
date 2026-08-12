---
name: swipess-build-order
description: Screen-by-screen build order for Flutter Swipess. Use when planning work, choosing the next surface, or when the user says continue, next screen, or close the design.
---

# Swipess Flutter build order

Close **design** from Capacitor before expanding product scope. Do not jump to map, concierge, or listings backend while earlier surfaces still look like a template.

## Order

| # | Surface | Capacitor reference | Flutter target |
|---|---------|---------------------|----------------|
| 1 | Secret code gate | `AccessCodeGate.tsx` | `lib/src/features/access/` |
| 2 | Welcome / landing | `LegendaryLandingPage` `LandingView` | `lib/src/features/auth/.../welcome_screen.dart` |
| 3 | Sign in / sign up options | `LegendaryLandingPage` `AuthView` | `lib/src/features/auth/.../auth_screen.dart` |
| 4 | Dashboard HUD + category deck | `TopBar`, `BottomNavigation`, `SwipeAllDashboard`, `PokerCategoryCard` | `lib/src/features/dashboard/` |
| 5 | Photo swipe deck | `SimpleSwipeCard`, `SwipeActionButtonBar` | `lib/src/features/swipes/` |
| 6 | Likes, messages, filters, profile | matching `src/pages/` + chrome | new feature folders |
| 7 | Passport map, AI concierge, events feed | `PassportMapModal`, concierge, `EventosFeed` | later; do not “simplify” map gestures |

## How to pick the next task

1. If the user names a screen, do that screen — still matching Capacitor.
2. Otherwise take the first step in the table that is missing or still generic (AppBar, gradient-only cards, two circular buttons).
3. Design lane first; bases (Supabase repositories, real OAuth) only when asked.

## Definition of done for a step

Someone who knows swipess.com would recognize the screen. Tokens, type, chrome, and motion match. Loading / empty / error are designed, not blank.
