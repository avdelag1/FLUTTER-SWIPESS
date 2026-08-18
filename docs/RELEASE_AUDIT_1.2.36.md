# Swipess Release Audit — 1.2.36 (612)

Date: 2026-08-17/18

## Release candidate

Swipess **1.2.36 (Build 612)** supersedes 1.2.35 (611) because this pass activates material production behavior in discovery, complimentary membership access, premium gating and engagement rewards.

## Discovery decisions

- Right swipe / Like is a saved decision and the target leaves normal discovery surfaces.
- First left swipe / Pass hides the target for **7 days**.
- After seven days the target receives one reconsideration opportunity.
- A second left swipe hides the target indefinitely unless an objective improvement is detected.
- Listing/service improvements that can trigger the final reconsideration are: lower price/hourly rate, materially expanded description, or additional photos.
- Profile/person improvements that can trigger the final reconsideration are: higher rating, more reviews without a rating decrease, materially expanded bio, additional photos, or newly verified status.
- If the resurfaced improved target is passed again, the third left decision is permanent.
- The decision state is server-backed in `likes`, including a snapshot of the target at decision time.
- The same decision filter is used by swipe feeds, direct-query fallbacks, the map and roommate/profile discovery.
- A successful empty smart feed is authoritative; the client no longer treats an empty result as an RPC failure and reloads already-decided listings.
- Offline swipe decisions replay through the same server state machine rather than bypassing it with a raw table upsert.

## Messaging token integrity

- Starting a brand-new conversation remains controlled by the production `start_conversation_with_message` RPC.
- A non-unlimited account needs one spendable message token to create a new conversation.
- The token is deducted only when a new conversation is created; continuing an existing conversation does not spend another token.
- The Flutter fallback that could create a conversation directly after an RPC error was removed, so the token/membership gate cannot be bypassed by the client.
- The token ledger now has the timestamps required by the existing deduction function.

## Rolling 3-month complimentary campaign

- Campaign configuration is stored server-side in `app_access_campaigns` under `new_user_premium_trial`.
- The campaign starts with signups on/after **2026-08-17** and is currently accepting new signups.
- Every qualifying new account receives **3 calendar months from that account's own creation time**.
- A user who signs up next month still receives their own full three-month window.
- Stopping the campaign only stops future signups; already-qualified users retain the trial end derived from their signup time.
- `accepting_new_signups` / `signup_ends_at` provide the owner-controlled campaign switch without requiring a new app release.
- Campaign updates automatically timestamp `updated_at`, giving the client a stable cutoff when the switch is turned off.
- When complimentary access expires and no paid subscription is active, the backend creates a one-time notification directing the user to membership packages.

## Premium access after the complimentary window

- During an active complimentary window, the effective tier is premium.
- After expiry, free accounts lose access to AI, Events, Legal services and Virtual ID until a paid membership is active.
- Any paid package restores the core AI / Events / Legal / Virtual ID access; higher-tier-only promotion/listing limits remain separate.
- Premium route enforcement is applied at router level for Events (including detail/favorites routes), client/owner Legal service routes and Virtual ID, preventing direct-link bypasses.
- AI retains its existing feature-level paywall gate.
- The public legal/terms route remains public and is not confused with the paid lawyer-services area.

## Active-use reward system

- Existing Profile quest/reward progress is now a **5-step** meter.
- Every **90 minutes of real foreground Swipess use** earns one reward step.
- Background, paused, hidden or closed-app time is not credited.
- Engagement tracking lives at the app root, so active time on map, listing/profile details, messages and other routes counts, not only dashboard time.
- The server validates small heartbeat intervals against elapsed server time; the client cannot submit an arbitrary multi-hour reward claim.
- On each earned active-use step, a durable in-app notification is created and the live app attempts to show a floating progress message.
- At 5/5, progress resets and one real spendable **message token** is granted.
- The token is written with one remaining activation and therefore works with the production new-conversation token gate.
- Existing Daily Quests contribute to the same five-point meter instead of maintaining a second confusing reward currency.

## Backend/repository parity

- Production Supabase migrations for discovery, campaign access, reward tracking and campaign update timestamps were applied successfully.
- The corresponding idempotent migration definitions are stored under `supabase/migrations/` so the production behavior is reproducible from the repository.
- Earlier 1.2.35 purchase/subscription security hardening remains in effect.

## Apple handoff

Use **Swipess 1.2.36 (612)** for the next Apple/TestFlight handoff. The App Store/Xcode Cloud account notification remains an external account-plan matter and is not treated as an application-code blocker in this audit.

Before review, the normal device/account checks still apply: archive/upload 1.2.36 (612), run the core swipe flow, confirm liked/passed items disappear appropriately, test a new-conversation token deduction, verify complimentary/premium navigation with a test account, and complete the StoreKit/TestFlight checks already listed in the 1.2.35 audit.
