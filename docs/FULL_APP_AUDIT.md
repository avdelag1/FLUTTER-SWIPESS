# Flutter Swipess full-product audit

Status legend: **PASS** is implemented and covered by a meaningful check;
**PARTIAL** exists but still needs integration or device verification; **BLOCKED**
depends on external services, credentials, schemas, or another repository.

| Area | Status | Evidence / next required action |
|---|---|---|
| Access gate | PARTIAL | Route, persisted grant, and recovery flow exist. Verify the live access API and native keyboard flow. |
| Authentication | PARTIAL | Email and OAuth surfaces exist. Run Apple/Google sign-in on production bundle IDs and move remaining direct Supabase calls behind the repository. |
| Business portal | BLOCKED | Promo submission and business profile models exist, but a separate complete business dashboard, partner QR scanner, redemption ledger, and role/RLS verification are not present in this repository. |
| Camera and uploads | PARTIAL | Listing/profile capture exists. Verify permissions, large uploads, cancellation, and storage RLS on iOS/Android. |
| Dashboard | PARTIAL | Photo filters, search, header, and dock exist. Continue screenshot parity and compact-device testing. |
| Deep links | PASS | Pure redirect rules and tests cover public shares, access, auth, and legacy aliases. |
| Documents | PARTIAL | Vault repository and previews exist. Verify storage encryption policy, RLS, retention, and signed URL expiry. |
| Escrow | BLOCKED | UI exists; production money movement, webhooks, disputes, KYC, and reconciliation require backend/provider verification. |
| Events | PARTIAL | Feed, detail, favorites, promotion, admin approval, and media exist. Verify event purchase receipts and moderation end-to-end. |
| Filters | PARTIAL | Listing/client filters exist. Confirm every filter is represented in the query/RPC and persisted per account. |
| Global navigation | PARTIAL | GoRouter and global back handling exist. Add a route-by-route device smoke suite for header/dock/back visibility. |
| Header chrome | PARTIAL | Scroll hide/show and route reset exist. Verify on dashboard, profile, events, likes, messages, and every shell destination. |
| In-app purchases | PARTIAL | StoreKit/Play purchase stream, restore, product IDs, and receipt edge-function calls exist. App Store Connect products, agreements, sandbox receipts, server validation, entitlement grants, renewal/revoke webhooks, and restore behavior must be verified. |
| Jobs / seekers | PARTIAL | Request feed/create repository exists. Confirm production schema and RLS; never convert transport/schema errors into empty success. |
| Lawyer portal | BLOCKED | Client request/video-call flow and Jitsi launch exist. A complete lawyer-side queue, availability dashboard, push/ringing, package assignment, call acceptance, and role/RLS validation are not present here. |
| Live map | PARTIAL | Satellite imagery, labels, clustering, photo-title pins, radius, and an auto-hiding HUD exist. A genuine Mapbox vector/terrain/building implementation requires the official native SDK, token, style, and device performance pass. |
| Messaging | PARTIAL | Conversations, popup, attachments, and listing context exist. Verify realtime delivery, pagination, unread state, blocking, notification fan-out, and RLS. |
| Notifications | PARTIAL | Local lifecycle notifications and in-app feed exist; remote push prompt is intentionally disabled until APNs/FCM is wired. |
| Owner listings | PARTIAL | Create/edit/publish/control surfaces and back navigation exist. Verify every listing category, upload rollback, validation, ownership, moderation, and deletion. |
| Payments / tokens | PARTIAL | Token catalog and checkout orchestration exist. Verify atomic server-side grants and idempotency; a client purchase must never be the source of truth. |
| Profile / PEARL | PARTIAL | Profile, VAP card, validation route, vault specimens, and QR rendering exist. Verify that every QR resolves to an authorized, revocable server record rather than decorative/client-only data. |
| QR partner redemption | BLOCKED | Resident QR display exists; business scanner validation, replay prevention, redemption transaction, audit trail, and business permissions need implementation/verification. |
| Reporting and safety | PARTIAL | Report/block UI exists. Move direct writes behind repositories and verify admin review, rate limits, evidence handling, and RLS. |
| Subscriptions | PARTIAL | Monthly/semiannual/annual products exist. Verify StoreKit subscription group, introductory offers, status sync, expiry/grace/billing retry, restore, and server notifications. |
| Swipe decks | PARTIAL | Full-bleed cards, visible five-icon dock, chrome timer, restore zones, actions, undo, and empty/error states exist. Add timer/gesture/device tests for every listing category. |
| Tests and CI | PARTIAL | PR/main CI now runs analyzer, tests, and a web release build; local verification can opt into a full format check. Device/E2E, Android release, and iOS build verification remain required. |
| User roles | BLOCKED | Client and owner paths exist; admin, lawyer, and business permissions need a single documented role matrix plus database RLS tests. |
| Video | PARTIAL | Event/listing video and legal external calls exist. Verify codec, recut, autoplay, audio focus, call lifecycle, and low-connectivity behavior. |
| Web deployment | PARTIAL | Vercel previews work. Production requires the PR commit to reach remote `main`; local branch naming is not deployment. |
| eXternal services | BLOCKED | Supabase, Mapbox, Apple, Google, PayPal, APNs/FCM, Jitsi, and Vercel each need production credentials and health checks. |
| Yield / performance | PARTIAL | Video budgets and image cache sizing exist. Profile frames, map tile/marker load, long lists, and low-memory devices need profiling. |
| Zero-trust release | BLOCKED | Require analyzer, tests, schema/RLS tests, signed production builds, receipt validation, secret scanning, and a smoke deployment before automatic merge. |

## Immediate release gates

1. Flutter formatting, analyzer, unit/widget tests, and device smoke tests pass.
2. Swipe dock shows all five icons before and after chrome hide/reveal on phone.
3. Profile always restores shell header/dock and exposes back navigation.
4. Map pins keep photo and title in one compact marker; HUD hides and restores.
5. StoreKit sandbox purchase, validation, entitlement grant, restore, renewal, and revoke pass.
6. Lawyer request reaches a logged-in available lawyer and a call can be accepted/ended.
7. Business QR scan validates server-side and writes one idempotent redemption.
8. Admin roles and every privileged mutation are enforced by RLS, not only UI checks.
9. The final commit is present on remote `main` and Vercel reports Production.
