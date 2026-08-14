# Flutter Swipess — parity audit (Aug 2026)

Snapshot of what is **shipped on this branch vs Capacitor `avdelag1/swipess`**. Pixel-faithful means a screenshot could be mistaken for swipess.app. Radio is out of scope.

## 100% enough to use (core loop)

| Surface | Status | Notes |
|---------|--------|--------|
| Access gate | **Done** | Black canvas, SWIPESS, lock card, `URDBEST`. |
| Welcome | **Done** | Italic wordmark, SIGN IN + CREATE ACCOUNT, Rosa Mexicano. |
| Auth (email) | **Done** | Pill fields, LOG IN / CREATE, Apple/Google buttons present. |
| Dashboard HUD | **Done** | Search glow, date/guest/location chips, floating dock, hide-on-scroll chrome. |
| Bento category grid | **Done** | Cap card order/sizes; extra **IN YOUR RADIUS** listings under the grid so the page actually scrolls. |
| Listing detail | **Done on this PR** | Long-form gallery + specs / about / amenities / neighborhood / match protocol. Header + MESSAGE dock hide on scroll down, return on scroll up. |
| Swipe deck | **Mostly done** | Full-bleed Cap card, side rail, price overlay. Not a Tinder button row. |
| Bottom dock | **Done** | Scrollable pill, Cap icon order, AI robot, coral +. |
| Intel Core sheet | **On PR #37, not this branch** | Bottom card + MENU peek. Merge that PR for the overlay fix. |
| Live map | **On main via PR #34** | Colorful basemap, 3D pitch, combined pins. Open from dashboard globe — do not deep-link `/map` while gated. |
| Likes | **Mostly done** | Cap segmented chrome, listing cards. |
| Messages | **Mostly done** | Thread chrome; document send API unblocked on this branch so web compiles. |
| Profile / PEARL / VAP | **Mostly done** | Cap layout; vault rows exist. |
| Filters | **Mostly done** | White sheet, category cards, SCAN DECK. |
| Events feed | **Mostly done** | Photo/video grid, teaser on dash. |
| Listing Control (owner) | **Mostly done** | Asset terminal chrome. |
| Gate/auth redirect | **Fixed on this PR** | Signed-in + no grant no longer loops `/client/dashboard` ⇔ `/gate`. |

## Partial — looks like Cap but not finished

| Surface | Missing |
|---------|---------|
| Native Apple/Google OAuth | Web redirect path exists; device ID-token path still thin vs Cap. |
| Intel Core | Streaming, voice, listing-control overflow — see other PRs. Merge #37. |
| Map | Clustering/padding and 3D are on main; some HUD density vs Cap still off. |
| Escrow / contracts / lawyer | Screens exist; not a full Cap legal desk. |
| Push notifications | Prompt chrome; delivery depends on native shell. |
| i18n ES | Partial `app_locale`, not the full Cap pack. |
| Seekers / roommates / video tours / price intel | Routes and shells exist; content density below Cap. |
| Public share previews | Routes are public; styling is simpler than in-app listing. |

## Not done / out of scope

| Item | Why |
|------|-----|
| Radio | Explicitly excluded. |
| Admin consoles | Separate `admin-swipess` repo. |
| RevenueCat / IAP production | Entitlements stubbed for demo grant. |
| OpenAI keys in client | Edge functions only; no keys in the app. |
| Termux / phone preview of this cloud VM | Isolated `localhost:8080`. Run Flutter on a machine you control, or open this agent chat for screenshots. |

## Known footguns

- Demo gate: **`URDBEST`**.
- Do not open `/#/map` or `/#/client/dashboard` until the gate is passed **and** you are signed in — otherwise you used to hit a GoRouter redirect loop (fixed here: ungated sessions stay on `/gate`).
- Listing deep links `/listing/:id` still require gate + sign-in; `/preview/listing/:id` is public.
