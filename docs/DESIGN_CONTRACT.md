# Design contract — five primary surfaces

This is what “the design we already have” means. Match these, not a Flutter reinterpretation.

Source: live Capacitor app (`avdelag1/swipess`, swipess.com / swipess.app).

## Shared rules

- Canvas: near-black (`#000` on gate/welcome/auth; `#0A0A0D` on dashboard).
- Type: Plus Jakarta Sans. Wordmark is bold italic all-caps **SWIPESS**.
- Controls: stadium / pill shapes (`BorderRadius.circular(999)` or very large radii).
- Chrome: hairline light borders, glass blur, optional thin neon glow — not fat Material shadows.
- Primary CTA: `#FF4D00` (orange-red). Secondary on black: solid white with black text.
- Do not add a gradient square “app icon” above the wordmark unless Capacitor has it.

---

## 1. Access / secret code

Capacitor: `src/components/AccessCodeGate.tsx`

- Black canvas. Brand **SWIPESS** (italic wordmark).
- Headline: “The exclusive ecosystem for visionaries.” plus grey supporting copy.
- Right or center: dark rounded **card** with lock icon, title **Enter Access Code**, subtitle **Authorized users only**.
- Pill input: search/lock affordance, placeholder “Enter access code”, optional scan icon.
- Solid **white** stadium button with key icon + **Enter**.
- Footer control: “See What’s New / What’s Old” (or request-access row).
- Optional App Store badge on marketing/desktop layout.
- Demo unlock: `URDBEST`.

## 2. Welcome / landing

Capacitor: `LegendaryLandingPage.tsx` → `LandingView`

- Everything centered on black.
- Large italic **SWIPESS** wordmark (use brand PNG/SVG, not a Material icon).
- White stadium **LOG IN** / **SIGN IN** (black text).
- Orange-red stadium **CREATE ACCOUNT** (white text).
- Tiny faint footer (forgot / terms).
- Optional: swipe the logo to enter.

## 3. Sign in / sign up

Capacitor: `LegendaryLandingPage.tsx` → `AuthView`

- Centered column on black (subtle radial wash OK).
- Pill fields: Email (envelope), Password (lock + eye).
- Row: Remember me (left) + Forgot your password? (right).
- Wide orange-red stadium **LOG IN**.
- Dark stadium **CREATE AN ACCOUNT** under it.
- “or” divider.
- White stadium **CONTINUE WITH APPLE** and **CONTINUE WITH GOOGLE** (brand marks, black text).
- Faint Privacy / Terms footer. Legal sheet, not a new page, if Capacitor uses a sheet.

## 4. Dashboard / category home

Capacitor: `TopBar.tsx`, `BottomNavigation.tsx`, `SwipeAllDashboard.tsx`, `PokerCategoryCard.tsx`

- Top: pill search with **thin glowing** (neon) outline.
- Under search: 3+ pill category chips with small circular colored icons (red / blue / gold).
- Main: large rounded **photo cards** in a grid or poker stack — real photos, labels on the card, hairline border.
- Floating **pill bottom dock** with glowing outline and circular icon slots (not a Material `BottomNavigationBar` glued to the screen edge).
- Sparse HUD icons in corners — glass pills, not a solid AppBar.

## 5. Swipe / listing reel

Capacitor: `SimpleSwipeCard.tsx`, `SwipeActionButtonBar.tsx`

- Full-bleed vertical photo card, large corner radius.
- Floating **bottom** glass pill bar (nav / primary actions).
- Floating **side** glass pill rail (like / share / comments).
- Bottom-left overlay: price (e.g. **$15,000**), details, small avatar — white text on the photo.
- Circular outline icons in the top corners of the card.
- Not a row of five colored Tinder circles under a small card.

---

## Pass / fail

**Pass:** a screenshot of the Flutter screen could be mistaken for swipess.app.

**Fail:** generic dark Flutter demo, gradient orbs, Material AppBar, Tinder button row, missing wordmark, or “inspired by” glass that is not in Capacitor.
