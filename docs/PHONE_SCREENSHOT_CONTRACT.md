# Design contract — Capacitor phone screenshots (Aug 2026)

Source of truth: user phone screenshots of live Capacitor Swipess + `avdelag1/swipess`.
Flutter must pass the “could be mistaken for swipess.app” test.

## Shared chrome

- Canvas: pure black / `#0A0A0D`.
- Type: Plus Jakarta Sans. Labels often **ALL CAPS**.
- Primary accent: orange→pink gradient `#FF4D00` → `#EB4898` / `#FF4D6A`.
- Hairline white borders on glass cards; large radii (20–32, pills 999).
- **Bottom dock (critical):**
  - Floating pill, ~`90vw` / max ~340px centered, white/light outline.
  - Icons **narrow/small** (~18–20px glyph in ~36px wash circle).
  - **Horizontally scrollable** left↔right (`gap` ~6px, min tap ~44×44).
  - Order: Zap · Flame · **AI robot** · **+ (coral/pink)** · Chat · Shield/ID · Seekers · Filter · Legal · Events…
  - Add button is coral/pink (`#FF4D6A`), slightly larger.

## Surfaces from screenshots

### Dashboard
- Top glass HUD pills (avatar name, sparkles, crown badge, globe, moon, bell).
- AI search: dark pill with **cyan/blue neon glow** border; “Ask AI to find anything…”.
- Tiny AI disclaimer under search.
- Filter pills: Location / Any date / Guests (colored wash icons).
- Masonry photo/video cards; events-like cards have story dots + mute.

### Profile (ClientProfile)
- Gradient ring avatar + camera edit chip.
- Name + email uppercase.
- Stats: Likes / Total Matches / Messages in bordered squares.
- Daily Quests row.
- Full-width **MAGIC AI PROFILE** cyan gradient CTA.
- 2-col gradient action grid: Edit Profile, Promote Event, Seekers, Tokens, Settings, Sign Out.
- Full-width **PREMIUM** orange.
- Share & Earn card + invite + social row.
- Send Feedback card.
- Resident ID / Global Registry card.
- Seeker Requests card + Profile Completeness + Language flags.

### Likes
- Segmented: **LIKED LISTINGS** | **LIKED PEOPLE** (active = orange→pink fill).
- Category chips: All Favorites, Properties, vehicles… + refresh.
- Search + sort chips (NEWEST active gradient).
- Large listing cards: image, PROPERTY tag, trash, title, location pink, MESSAGE (pink) + VIEW (outline).

### Create listing
1. Chooser: **MAGIC AI LISTING** (purple, FASTEST) then OR MANUAL MODE categories (Property POPULAR, Motorcycle, Bicycle, Yacht, Jobs).
2. Property listing type: For Rent / For Sale / Both.
3. Wizard steps: **MEDIA → CATEGORY → DETAILS → PUBLISH** with green completed pills, red active pill, gradient progress line.
4. AI Listing Builder: purple theme, category grid, photos, location, description + AI Enhance, CREATE AI LISTING.

### Filters (ClientFilters — white sheet)
- Full-height **white / soft gray** sheet (`#F7F7F8`), not dark glass.
- Title: **SWIPESS FILTER** (FILTER in coral).
- Step 1: large white category cards (Properties, Motos, Bikes, Yachts, Workers, Buyers, Renters, Leads).
- Step 2: italic category title + coral **FILTERS**, rent/sale/both, budget pills, property extras, city, radius, **SCAN DECK** CTA.

### PEARL / VAP ID
- Custom header: flame · **PEARL** · edit · close (no main AppTopBar).
- Title **PEARL**; white soft card on black.
- Authorized Resident + TXID.
- Authorized Vault document rows (Passport, Gov ID, License, 6-Month Lease, Recommendation).
- Virtual ID QR at bottom of white card.

### Intel Core (Ask AI)
- Header INTEL CORE · ONLINE; history drawer; result property cards; SWIPE DECK / APPLYING SEARCH FILTERS; bottom Ask anything + mic + send.
