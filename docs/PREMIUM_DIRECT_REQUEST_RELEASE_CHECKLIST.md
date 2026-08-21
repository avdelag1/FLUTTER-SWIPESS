# Premium + Direct Request release checklist

This document is the release contract for the consent-first Swipess marketplace economy.

## Product contract

- Interest/right swipe is free.
- Mutual/owner-accepted matches chat for free.
- A Direct Request is priority, not permission to force-contact another person.
- One Direct Request token is reserved while pending and consumed only when accepted.
- Declined, expired, blocked/rejected, or sender-cancelled-before-acceptance requests release the reservation.
- Once accepted and chat opens, the token is spent even if the users later stop talking.
- Purchased tokens and Premium-included tokens follow the same acceptance rule.
- Events and Legal are not part of this marketplace communication redesign.

## Paid plans

Keep the existing store product IDs and prices unless a separate pricing decision is made.

| Plan | Price | Included Direct Requests |
| --- | ---: | ---: |
| Monthly / Here Now | $39.99 / month | 6 |
| 6 Months / Live Local | $119.99 / 6 months | 12 |
| Yearly / Pro | $299.99 / year | 30 |

Token packs remain 20 / 50 / 100 / 150 and are marketed as Direct Requests, not "new conversations".

## Swipess-managed 3-month complimentary access

The `new_user_premium_trial` campaign in `app_access_campaigns` is an app-managed complimentary campaign. It is **not** an App Store introductory subscription offer.

Rules:

- Eligible otherwise-free accounts receive Premium-equivalent app access for three calendar months.
- Paid subscriptions are never masked by the complimentary campaign.
- The app blocks starting a paid membership while complimentary access is active, preventing overlapping membership charges.
- Token packs remain purchasable during complimentary access.
- Each eligible campaign user receives one idempotent allowance of 6 welcome Direct Requests, expiring with that user's complimentary access.
- The preserved referral welcome bonus is +1 Direct Request and expires with the same complimentary window.
- Existing historical welcome-token balances are grandfathered rather than confiscated.
- The legacy `rpc_grant_welcome_tokens` entry point maps into the same complimentary Direct Request economy so old installed clients cannot create a second message-token model.

### Campaign duration policy

If `accepting_new_signups = true` and `signup_ends_at` is null, future new users continue receiving three complimentary months indefinitely. Set a campaign end/cutoff deliberately if this should be a launch-only promotion.

## App Store Connect metadata

For existing products, keep the product IDs. Update customer-facing names/descriptions so they match the shipped app:

- Monthly: 6 Direct Requests + Premium benefits.
- 6 Months: 12 Direct Requests + enhanced Premium benefits.
- Yearly: 30 Direct Requests + maximum Premium benefits.
- Token packs: 20 / 50 / 100 / 150 Direct Requests.

Remove old wording such as:

- "new conversations"
- "message tokens"
- "unlimited communication"
- wording that implies payment forces another user to accept contact

Review all English/Spanish localizations, screenshots, promotional text, review screenshots, and review notes for the same contract.

## IMPORTANT: do not double-stack free trials

The Swipess three-month campaign is already free Premium-equivalent access. Do **not** configure a separate Apple 3-month introductory free trial unless the business intentionally wants eligible customers to receive another Apple free period when they later subscribe.

If an Apple introductory offer is currently configured for this subscription group, review/remove it before release unless stacking is intentional.

## App Store Server Notifications V2 — required before paid subscription lifecycle is considered complete

First purchase/restore validation is not enough for a renewable subscription. Apple can renew, enter billing retry/grace, expire, revoke, or refund while the app is closed.

Before paid subscriptions are production-complete:

1. Implement a secure App Store Server Notifications **V2** HTTPS endpoint.
2. Cryptographically verify Apple's JWS `signedPayload` and signed transaction/renewal data. Do not trust decoded-but-unverified payloads.
3. Map verified Apple transaction/original-transaction identity back to the Swipess user subscription.
4. Process notifications idempotently by notification/transaction identity and signed date.
5. On successful renewal, update `user_subscriptions` with the new transaction/end date. The existing subscription Direct Request trigger then grants the next plan allowance exactly once for that validated transaction.
6. On expiration/revocation/refund, update entitlement state immediately and do not grant a new allowance.
7. Handle billing-retry/grace policy deliberately rather than treating every failed renewal as an immediate hard cancellation.
8. Return Apple a success HTTP status only after the notification is verified and safely recorded/processed.
9. Configure App Store Connect > App Information > App Store Server Notifications with the HTTPS endpoint and select Version 2 for Production and Sandbox (or intentionally route both environments to one verified endpoint).
10. Use Apple's test notification and Sandbox subscription lifecycle to verify renewal, cancellation/expiry, refund/revoke, retry/idempotency, and restore.

Do not deploy a notification endpoint that merely Base64-decodes the JWS without signature/certificate verification.

## Google Play lifecycle

Apply the same principle on Android: first-purchase validation is insufficient for renewals/cancellations/refunds. Verify Real-time Developer Notifications / subscription status synchronization before declaring Android recurring billing lifecycle complete.

## Backward-compatible rollout

- New Flutter builds use `start_mutual_conversation_v2` for consent-based chat.
- Existing installed clients temporarily retain legacy `start_conversation_with_message` behavior.
- The legacy path respects active Direct Request reservations and cannot spend a token already reserved by the new system.
- Remove/deprecate the legacy cold-message behavior only after old client versions are retired or a forced update is in place.

## Release validation

Do not merge/release solely because the UI looks correct. Require:

- Flutter analyzer green.
- Flutter tests green.
- Web release build green.
- Android release bundle green.
- iOS release build green and confirmed non-debug/AOT for TestFlight.
- Supabase migration state matches repository migrations.
- Direct Request smoke tests: create/reserve, accept/consume, decline/return, expiry/return, cancel/return, duplicate pending request, concurrent requests, legacy-reservation protection.
- Free-match smoke test proves no token is consumed.
- App Store sandbox: subscription purchase, receipt validation, restore, renewal notification, expiry/revoke/refund notification.
- Product metadata in App Store Connect matches 6 / 12 / 30 and Direct Request terminology.
- Verify whether an Apple introductory offer exists; avoid unintentionally stacking it with the Swipess-managed three months.

## Marketing sentence

> Interest is free. Matches are free. Priority is Premium.

More precise token explanation:

> Use a Direct Request when you want priority. Your token is only spent when the other person accepts.
