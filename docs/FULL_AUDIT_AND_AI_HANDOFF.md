# Flutter Swipess — full audit and AI implementation handoff

**Audit date:** 2026-08-15
**Repository snapshot:** branch `work`, starting at `a8b6cc4`
**Purpose:** give the owner an honest status report and give follow-up AI agents
small, ordered, testable assignments. This is an implementation backlog, not a
claim that visual parity has been proven.

## Executive summary

Flutter Swipess is a large, real Flutter application rather than an empty port:
the repository contains 323 Dart files, about 68,771 lines of Dart, 26 test
files, GoRouter navigation, Riverpod state, Supabase repositories, native
capability integrations, and implementations for the main product surfaces.
The primary gate, welcome, auth, dashboard, and swipe experiences also have
dedicated Flutter components and brand assets.

The project is **not ready to call fully audited or production-complete** for
four reasons:

1. **Visual parity is asserted but not objectively proven.** There is no checked-in
   baseline screenshot suite, golden-test matrix, or parity checklist with
   evidence for every screen and viewport. The reference Capacitor repository
   could not be cloned during this audit because the environment's GitHub tunnel
   returned HTTP 403.
2. **The UI bypasses the required data boundary.** Numerous presentation files
   use `Supabase.instance` and table/storage queries directly. This conflicts
   with `AGENTS.md`, makes widget tests harder, and spreads auth/error behavior.
3. **The presentation layer is difficult to maintain.** Several screens exceed
   900 lines (the profile screen exceeds 1,700), there are hundreds of local
   `setState` calls, and Material `SnackBar` remains widespread even though the
   Capacitor-style notification banner has been ported.
4. **Backend reproducibility and end-to-end verification are incomplete.** The
   app references dozens of remote tables while the repository contains one
   Supabase migration. iOS device/build verification, production association
   files, remote push, and real-device capability checks remain handoffs.

The right next move is **not another broad redesign**. Freeze expansion, capture
the Capacitor reference, close the five primary surfaces in build order, enforce
repository boundaries one feature at a time, and add reproducible integration
and release checks.

## Audit method and limitations

### Inspected

- Project instructions: `AGENTS.md`, `BRAIN.md`, `docs/DESIGN_CONTRACT.md`, the
  always-on Cursor rule, and both project skills.
- All file paths under `lib/`, `test/`, `web/`, native platform folders,
  `.github/workflows/`, `supabase/`, and `tool/`.
- Primary auth, routing, theme, dashboard, swipe, repository, native-service,
  test, and deployment files.
- Static counts for large files, direct Supabase access, `setState`, SnackBars,
  duplicate repository names, tests, and migrations.
- Existing migration notes and recent Git history.

### Could not verify in this environment

- `git clone --depth 1 https://github.com/avdelag1/swipess.git /tmp/swipess`
  failed with `CONNECT tunnel failed, response 403`. Therefore this document
  does not pretend to certify pixel parity against fresh Capacitor source.
- `flutter analyze` and `flutter test` could not run because the `flutter`
  executable is not installed or on `PATH` in this environment.
- No Android emulator, physical device, macOS/Xcode host, Supabase test project,
  or store sandbox was available.

These limitations are blockers to *verification*, not permission for a future
agent to skip the checks.

## Current-state scorecard

| Area | Status | Evidence / interpretation |
|---|---|---|
| Product breadth | Strong | Feature-first folders cover auth, dashboard, swipes, events, map, messages, profile, payments, legal, documents, AI, and more. |
| Primary flow structure | Strong | Separate access, welcome, auth, dashboard, and swipe implementations exist and the router exposes the larger route map. |
| Brand foundations | Good | Brand images, photo filters, `#FF4D00`, Plus Jakarta Sans, starfield, glass controls, search glow, and floating dock primitives exist. |
| Visual parity evidence | High risk | No deterministic reference captures or golden baseline proves the “could be mistaken for Capacitor” contract. |
| Architecture | Needs remediation | Business/network operations frequently live in presentation screens/providers rather than repositories. |
| State management | Mixed | Riverpod is extensively used, but local state is also extensive; distinguish harmless animation/form state from business state. |
| Test coverage | Partial | 26 files / roughly 50 declared widget/unit tests emphasize chrome and native parity, but critical repository/auth/error flows remain thin. |
| Backend reproducibility | High risk | One checked-in migration cannot reconstruct the many tables/storage/RPCs referenced by the client. |
| Native readiness | Partial | Native capability work is documented and tested statically; iOS build and real-device verification remain outstanding. |
| CI | Present, verify | A Flutter checks workflow exists; it should become the required merge gate and expand to deterministic builds. |
| Maintainability | High risk | Many 500–1,700-line presentation files and duplicate repository filenames increase change risk. |
| Accessibility/localization | Needs audit | Localization assets exist, but substantial literal UI copy and custom controls require semantic, contrast, text-scale, and locale checks. |

## Findings and solutions

### P0 — establish trustworthy parity evidence

**Problem.** The design contract is precise, but completion is currently based on
implementation intent and narrow widget assertions. A color or widget-presence
test cannot establish pixel fidelity. Recent history also includes a “premium UI
redesign,” which is exactly where visual invention can drift from the required
Capacitor source.

**Solution.** Build a parity harness before restyling more surfaces:

1. Clone/open the Capacitor source and record the exact commit hash used.
2. Capture reference screenshots for access, welcome, login, sign-up, dashboard,
   swipe, and each loading/empty/error state at 390×844 and 1440×900.
3. Add deterministic Flutter showcase routes or a test-only fixture mode: fixed
   time, fixed locale, fixed data, no network images, animations disabled.
4. Add golden tests with a documented tolerance and store reviewed baselines.
5. Add `docs/parity/<surface>.md` checklists mapping Capacitor source elements to
   Flutter widgets, including any deliberate deviation.
6. Require a human-reviewed before/reference/after image for every visual PR.

**Exit criteria.** The five primary surfaces pass their checklists and reviewed
goldens on compact mobile and desktop web. No generic AppBar, decorative orb,
Tinder action row, or unreferenced styling remains.

### P0 — restore the repository boundary

**Problem.** Direct Supabase access exists in presentation code across auth,
camera, escrow, likes, legal, map, messages, moderation, profile, roommates,
swipes, and video tours. Examples include password reset, camera upload,
report/block actions, saved searches, map queries, profile feedback, and swipe
screens. Providers are allowed to coordinate repositories; they should not
become ad-hoc repositories themselves.

**Solution.** Migrate feature-by-feature, never as one giant rewrite:

1. Introduce/inject a `SupabaseClient` provider at the core service boundary.
2. Put every table, RPC, storage, and auth mutation in the feature's `data/`
   repository. Repositories return typed domain results rather than raw maps.
3. Put async orchestration in `Notifier`/`AsyncNotifier` controllers with
   explicit idle/loading/success/error state.
4. Keep UI responsible only for collecting input, rendering state, and emitting
   intents.
5. Add repository tests with a fake client/adapter and controller tests for
   loading, error, retry, cancellation, and unauthenticated cases.
6. Add a CI guard that fails when `Supabase.instance` or `.from(` is introduced
   under `features/**/presentation/**` (allow an explicit, temporary debt list).

**Recommended order.** Auth/reset → moderation/reporting → camera/profile upload
→ saved searches/profile → map/video tours → messages/likes → remaining features.
These start with security-sensitive writes and user-facing failures.

**Exit criteria.** Presentation directories contain no Supabase imports or query
builders, all new repositories are injected, and tests can exercise controllers
without initializing Supabase.

### P0 — make the backend reproducible and security-reviewable

**Problem.** The Flutter client references roughly 42 distinct `.from('…')`
tables/buckets, but only one migration is checked in. A new environment cannot be
reconstructed, and this repository cannot demonstrate RLS, storage policy,
function, index, or seed parity. A working remote project is not a substitute for
versioned schema.

**Solution.** Treat the deployed Supabase project as a source to inventory, then
bring a sanitized declarative history into version control:

- Export schema only; never commit secrets or production rows.
- Version tables, enums, constraints, indexes, triggers, RLS enablement/policies,
   storage buckets/policies, RPCs, and Edge Function contracts.
- Explicitly test tenant isolation: anonymous, user A, user B, owner, moderator,
  and admin for every sensitive table.
- Add local seed fixtures for a user, listings, event, messages, likes, saved
  search, documents, and payment-independent entitlements.
- Generate typed DTOs or at minimum centralize column mappings so schema drift is
  caught at compile/test time rather than by a runtime cast.
- Add CI that starts local Supabase, applies migrations from zero, runs policy
  tests, and then runs repository integration tests.

**Exit criteria.** `supabase db reset` reconstructs a useful development project
from a clean checkout, and cross-user access tests prove the intended RLS model.

### P0 — close release-critical handoffs

**Problem.** Existing migration notes identify items that cannot be proven by
Dart tests: Universal/App Link hosting, iOS build/signing, device permissions,
privacy screen behavior, notification delivery, OAuth configuration, purchase
sandbox behavior, and remote push (currently intentionally absent).

**Solution.** Create a signed release checklist and record artifacts:

- Validate `assetlinks.json` using the Play signing fingerprint and validate the
  Apple association file using the actual Team ID, correct MIME type, HTTPS, and
  no redirect on every claimed host.
- Run Android debug/release builds and an instrumentation smoke test on a device.
- Run `xcodebuild` on macOS and smoke test Apple/Google sign-in, camera/mic/photo
  permissions, location, biometric gate, screenshot protection, deep links,
  notifications, review prompt, and purchases on physical iOS.
- Decide whether remote push is a launch requirement. If yes, implement plugin,
  APNs/FCM provisioning, token repository, lifecycle navigation, opt-out, and
  deletion. If no, remove misleading enablement UI and document the product
  decision.
- Verify account deletion, privacy policy, terms, data export/retention, and
  store disclosures against actual collected data.

**Exit criteria.** A release candidate has dated Android/iOS/web evidence, no
dead CTA, and no capability declared without an implemented and tested flow.

### P1 — split oversized presentation units safely

**Problem.** The largest files combine data loading, mutation, state, layouts,
dialogs, and helper widgets. Notable sizes include `profile_screen.dart` (1,726
lines), `intel_core_sheet.dart` (1,344), `add_listing_screen.dart` (1,336),
`listing_detail_screen.dart` (1,044), `advertise_screen.dart` (1,022), and
`cap_swipe_card.dart` (984). This makes parity work fragile and promotes broad
rebuilds.

**Solution.** Refactor behavior-preservingly after goldens exist:

- Extract domain/controller logic first, then coherent stateless sections.
- Keep files feature-local; do not create a generic `widgets/` dumping ground.
- Pass small immutable view models/callbacks instead of whole notifier refs.
- Use `const` constructors and `select`/small consumers to constrain rebuilds.
- Retain keys and semantics so tests remain stable.
- Do not change visuals in the same commit as structural extraction.

**Exit criteria.** Main screens read as composition, business operations are in
controllers/repositories, and golden output is unchanged.

### P1 — standardize feedback, errors, and offline behavior

**Problem.** There are many Material `SnackBar` call sites even though
`AppNotificationBar` is the documented Capacitor-equivalent. Error conversion is
ad hoc (`'$e'`, exception strings), so users may receive technical messages and
different surfaces behave differently.

**Solution.** Define typed `AppFailure` categories (auth, validation, permission,
network, server, rate limit, payment, unknown), map raw exceptions once at the
repository/service boundary, and send user-safe localized messages through the
global notification provider. Use inline errors for fields and persistent retry
panels where recovery matters; reserve banners for transient global feedback.

**Exit criteria.** No new raw exception string is rendered, no presentation file
creates a `SnackBar`, and critical async surfaces have designed loading, empty,
error, offline, and retry states.

### P1 — rationalize duplicate repositories and models

**Problem.** Both profile and swipe features contain same-named repositories at
two different data paths. Even when responsibilities differ, this naming makes
imports and ownership ambiguous and raises the chance that agents extend the
wrong abstraction.

**Solution.** Inventory callers and responsibilities, select one canonical
repository per aggregate, rename genuinely distinct roles (for example,
`ProfileReadRepository` vs `ProfileMutationRepository`) only when separation is
intentional, and delete adapters after all callers migrate. Add a short feature
README documenting the domain/data/presentation dependency direction.

**Exit criteria.** One obvious import exists for each repository responsibility;
no duplicate basename hides a different API.

### P1 — broaden automated coverage around business risk

**Problem.** Existing tests are useful but skew toward visual/chrome behavior.
The repository lacks a clear pyramid for domain serialization, controllers,
repository contracts, routing matrix, accessibility, localization, and critical
user journeys.

**Solution.** Add, in order:

1. Pure domain parsing/validation tests for every remote model.
2. Controller tests for auth, listing creation/edit, swiping/offline sync,
   messaging, reporting/blocking, payments, and profile changes.
3. Repository contract tests against local Supabase.
4. Router table tests for every public/private route, gate/session combination,
   pending link, sign-out, and recovery event.
5. Widget tests for loading/empty/error/retry and no-overflow at 320 px width,
   200% text scale, English, and Spanish.
6. Golden parity tests and a small integration suite for access → welcome → auth
   → dashboard → swipe plus deep links and offline recovery.

**Exit criteria.** Each critical mutation has success and failure coverage, and
CI publishes useful logs/golden diffs.

### P1 — accessibility and localization pass

**Problem.** Brand-heavy custom controls, icon-only HUD elements, images, glass
contrast, gestures, and literal English strings carry accessibility and locale
risk. Assets under `assets/i18n/` show localization intent, but existence of JSON
does not prove screen coverage.

**Solution.** Audit every route using Android TalkBack and iOS VoiceOver; add
semantic labels/hints/selected state, meaningful traversal order, 44–48 px hit
targets, keyboard/focus behavior on web, non-gesture alternatives, image
descriptions where relevant, contrast checks, reduced-motion handling, and 200%
text-scale layouts. Move user-visible literal text into the established i18n
layer and verify English/Spanish completeness in CI.

**Exit criteria.** Critical flow is usable without sight or drag gestures, no
text clips at 200%, and missing/unused translations fail CI.

### P2 — performance and media reliability

**Problem.** Photo/video-first dashboards, swipe stacks, maps, blur/glow effects,
and large widget trees are high-risk for frame drops and memory pressure. Static
review cannot certify 60/120 fps.

**Solution.** Profile release mode on representative low/mid Android and iPhone
hardware. Record shader, raster, build, image-cache, video-controller, and memory
behavior while opening dashboard, swiping rapidly, scrolling listing detail,
opening map, and backgrounding/resuming. Resize/cache images to display bounds,
preload only the next media, dispose controllers deterministically, isolate
animated regions, avoid broad provider watches, and reduce/back off expensive
blur only where profiling demonstrates a problem without changing the design.

**Exit criteria.** Publish before/after traces and budgets; no leaked controllers,
unbounded cache growth, visible blank media, or sustained jank in core journeys.

### P2 — documentation and dependency hygiene

**Problem.** `MIGRATION_PROGRESS.md` claims complete migration while this audit
identifies verification and reproducibility gaps. Dependency comments also risk
drifting from the actual package list. “Complete route coverage” and “production
ready” should be different statuses.

**Solution.** Replace binary completion language with a capability matrix:
implemented, unit-tested, integration-tested, device-verified, production-
configured, and parity-approved. Run `flutter pub outdated`, license/security
review, and platform compatibility checks on a schedule; upgrade one risk group
at a time with tests. Document SDK acquisition and exact local/CI commands.

**Exit criteria.** A new contributor can build all supported targets from the
README, and status documents link to evidence rather than relying on prose.

## Ordered delivery plan

| Wave | Scope | Dependency | Can run in parallel? |
|---|---|---|---|
| 0 | Reference clone, screenshot inventory, fixture mode, baseline goldens | Access to Capacitor source | Reference capture and fixture design can overlap; baseline approval cannot. |
| 1 | Access → welcome → auth parity | Wave 0 | One owner per screen, but shared tokens/assets require coordination. |
| 2 | Dashboard → swipe parity | Approved shared chrome from Wave 1 | Dashboard and swipe may run in parallel after tokens freeze. |
| 3 | Auth/moderation/camera repository extraction + failure model | Stable behavior tests | Separate feature agents can work in parallel with non-overlapping files. |
| 4 | Remaining repository extraction + Supabase migration/RLS inventory | Core client abstraction | Feature extraction can parallelize; schema owner coordinates migrations. |
| 5 | Accessibility/i18n, performance, and release-device validation | Visually stable primary flow | These specialties can run in parallel, then converge in release checklist. |

## Copy-ready prompts for other AI agents

Give each agent **one prompt only**, on its own branch/worktree. Require small
commits and prohibit unrelated restyling. Replace bracketed placeholders before
use.

### Prompt 1 — parity evidence harness

```text
Read AGENTS.md, BRAIN.md, docs/DESIGN_CONTRACT.md, and both .cursor skills first.
Clone avdelag1/swipess at /tmp/swipess and record its commit hash. Do not redesign.
Build a deterministic Flutter visual-parity harness for access, welcome, auth,
dashboard, and swipe at 390x844 and 1440x900. Use fixed local fixtures, fixed
locale/time, deterministic local images, and disabled/settled animation. Add
golden tests and docs/parity/README.md explaining how to recapture and review
baselines. Capture matching Capacitor screenshots if the source can be run; if it
cannot, document the exact blocker and do not invent baselines. Run formatter,
flutter analyze, and relevant tests. Return changed files, reference commit,
commands/results, and remaining visual mismatches. Do not touch backend behavior.
```

### Prompt 2 — access and welcome parity

```text
Read all project instructions and inspect the exact Capacitor AccessCodeGate.tsx
and LegendaryLandingPage LandingView before editing. Close only the Flutter
access and welcome screens to the reference: layout, responsive breakpoints,
wordmark, type, #FF4D00/white CTA hierarchy, starfield, pills, hairlines, copy,
motion, focus, and error/loading behavior. Keep URDBEST and existing navigation.
Do not add orbs, Material AppBars, generic icons above the wordmark, or new visual
language. Update parity checklist and mobile/desktop goldens. Test keyboard,
screen reader labels, 200% text, and 320px width. Run dart format, flutter analyze,
targeted tests, then full flutter test. Make one focused commit.
```

### Prompt 3 — authentication architecture and parity

```text
Match LegendaryLandingPage AuthView exactly while preserving native Apple/Google
auth. First add controller tests. Move all Supabase/session access out of auth
screens into AuthRepository plus a Riverpod AsyncNotifier/controller. Model
idle/loading/success/validation/auth/cancelled states; prevent duplicate submits;
use inline localized validation and the global notification system, never raw
SnackBars or raw exception text. Cover login, signup, forgot/reset password,
OAuth cancel/error, missing session, and pending deep-link continuation. Update
goldens without inventing styling. No Supabase import may remain in auth
presentation screens. Run formatter, analyzer, targeted/full tests and commit.
```

### Prompt 4 — dashboard parity and performance

```text
Inspect Capacitor TopBar.tsx, BottomNavigation.tsx, SwipeAllDashboard.tsx,
PokerCategoryCard.tsx, CardData.ts, EventsVideoQuickFilter.tsx, tokens.css, and
chromeStyles.ts. Close only the Flutter dashboard: neon search, category chips,
photo cards/poker stack, sparse HUD, and floating glowing dock. Reuse exact
Capacitor assets/tokens; do not create generic Material navigation or extra glass
effects. Preserve routes and Riverpod state. Add deterministic loading/empty/error
fixtures and mobile/desktop goldens. Constrain rebuilds and media preloading, then
profile dashboard scrolling in release/profile mode where available. Run format,
analyze, tests and commit with before/reference/after screenshots.
```

### Prompt 5 — swipe reel parity

```text
Inspect Capacitor SimpleSwipeCard.tsx and SwipeActionButtonBar.tsx before coding.
Close the Flutter swipe experience only: full-bleed rounded media, top outline
controls, bottom-left price/details/avatar overlay, side glass action rail,
bottom glass action/nav pill, gesture thresholds, chrome reveal, media states,
and match feedback. Remove any remaining Tinder-style row behavior not present in
Capacitor. Preserve repositories and offline queue semantics. Add deterministic
goldens plus widget tests for swipe directions, action buttons, exhausted/error/
retry, hidden/restored chrome, and narrow/large-text layouts. Profile rapid swipes
for controller leaks and jank. Run format, analyze, targeted/full tests and commit.
```

### Prompt 6 — repository-boundary migration

```text
Work only in feature [FEATURE]. Inventory every Supabase.instance, .from(), RPC,
storage, and auth call under its presentation directory. Add characterization
tests first. Move backend operations into typed repositories under data/, expose
them via injected Riverpod providers, and put orchestration in AsyncNotifier/
Notifier controllers. UI must only render state and send intents. Include loading,
empty, safe error, retry, unauthenticated, and cancellation behavior. Do not alter
visual output. Remove raw map plumbing from UI where practical. Add repository
and controller tests with fakes. Verify zero Supabase imports/queries remain in
this feature's presentation tree. Run format, analyze, targeted/full tests and
make a focused commit.
```

### Prompt 7 — Supabase schema and RLS reconstruction

```text
Audit all table, view, RPC, realtime, and storage references in the Flutter repo
against the authorized Supabase project. Never copy production data or secrets.
Create ordered migrations that reconstruct schema, indexes, triggers, functions,
buckets, RLS enablement, and policies from zero. Add minimal synthetic seed data
and automated policy tests for anonymous, user A, user B, owner, moderator, and
admin. Pay special attention to profiles, precise location, messages, documents,
reports/blocks, listings, likes, payments/entitlements, and admin tables. Prove
supabase db reset succeeds and repository integration tests pass. Document any
remote object intentionally excluded and why. Commit migrations/tests only; do
not restyle Flutter UI.
```

### Prompt 8 — global failure and notification migration

```text
Design a typed AppFailure model and centralized exception mapper without changing
successful behavior. Migrate [FEATURE] from SnackBar/raw '$e' output to inline
field errors, persistent retry states, or AppNotificationBar as appropriate to
the Capacitor UX. Localize every user message. Preserve diagnostic detail in
structured debug logging without exposing tokens, PII, or server internals.
Add tests for validation, offline, permission denial, auth expiry, rate limit,
server failure, payment failure, retry, and dismissal. Add/enforce a CI rule
preventing new SnackBar use in feature presentation code, with a documented
temporary allowlist. Run format, analyze, tests and commit.
```

### Prompt 9 — accessibility and localization

```text
Audit routes [ROUTES] without redesigning them. Move literal user-visible strings
into the existing i18n system and complete English/Spanish keys. Add Semantics,
labels/hints/selected state, focus order, keyboard activation, 44-48px targets,
non-drag alternatives, reduced-motion support, and sufficient contrast while
preserving Capacitor visuals. Test at 320px width and 200% text scale in both
locales with no overflow. Add widget/semantics tests and an i18n completeness
check. Report anything requiring product copy approval. Run format, analyze,
tests and commit.
```

### Prompt 10 — native release verification

```text
Do not redesign UI. On real Android and iOS hardware, execute and document a
release-candidate matrix for identity/version/signing, cold start/system chrome,
back navigation, web/custom deep links, password recovery, Apple/Google OAuth,
camera/photos/mic/location/biometric permissions, privacy screen, connectivity,
local notifications, app badge, sharing/URL schemes, review prompt, background/
resume, and purchase sandbox flows. Verify hosted assetlinks.json and
apple-app-site-association headers/content against signing identities. Run Android
release build and xcodebuild. Attach exact commands, device/OS versions, sanitized
logs, and pass/fail evidence. Fix only reproducible code/config defects with tests;
list external console/hosting blockers separately. Commit code changes if any.
```

## Rules for coordinating multiple AI agents

1. One agent owns shared theme/chrome files at a time.
2. Never combine visual parity, repository extraction, and schema reconstruction
   in one PR.
3. Every agent rebases before handoff and reports exact changed files.
4. Agents must not mark a task done when Flutter/analyzer/device tooling was
   unavailable; they must label it unverified.
5. Baselines are reviewed artifacts, not snapshots agents may update merely to
   make a failing test green.
6. No agent may add a direct Supabase call to presentation, render raw errors,
   commit credentials, or weaken RLS to pass a test.
7. Prefer one feature/surface per commit so regressions can be bisected.

## Definition of production-ready

The application is ready only when all of the following are true:

- The five primary surfaces have approved reference checklists and mobile/web
  golden evidence.
- `dart format --set-exit-if-changed .`, `flutter analyze`, and the full test
  suite pass in required CI.
- Presentation has no direct backend queries and critical controllers have
  success/failure tests.
- Local Supabase reconstructs from migrations and RLS isolation tests pass.
- Android, iOS, and web release builds are reproducible; physical-device smoke
  evidence is attached to the release.
- Deep-link association files, OAuth, payments, and any enabled notification
  capability are production-configured and tested.
- Access, auth, dashboard, swipe, account deletion, and privacy-sensitive flows
  pass accessibility, localization, offline, and recovery checks.
- Known deliberate gaps are explicitly approved by the product owner and do not
  leave dead or misleading UI.

