# App Review — Native Purchase Test Guide

## Reviewer account

Use the App Review credentials supplied in App Store Connect. The dedicated review account is recognized inside the app and receives an **APP REVIEW TEST GUIDE** immediately after login.

The guide exposes two direct native-purchase test paths so App Review does not need to discover hidden functionality or wait for manual moderation.

## Path 1 — Direct Request token packs

1. Sign in with the App Review credentials.
2. In **APP REVIEW TEST GUIDE**, tap **OPEN TOKEN PURCHASES**.
3. The opaque Direct Requests purchase page displays the complete token catalog on one screen.
4. Tap **GET** on any token pack.
5. The native App Store / StoreKit purchase sheet appears.
6. Complete or cancel the sandbox purchase as needed.

Token product identifiers:

- 20 Direct Requests: `Swipess.tokens.20.v2`
- 50 Direct Requests: `Swipess.tokens.50.v2`
- 100 Direct Requests: `Swipess.tokens.100.v2`
- 150 Direct Requests: `Swipess.tokens.150.v2`

## Path 2 — Event promotion purchase

Swipess moderates event advertisements before charging the customer. A submission is never charged while it is pending review and a rejected submission cannot open checkout.

The lifecycle is:

1. Event details are submitted.
2. Swipess moderation approves or rejects the event.
3. Approval unlocks the native in-app purchase.
4. Apple verifies the purchase on the server.
5. Only a verified purchase activates the promotion.

For App Review, the moderation step is already completed:

1. In **APP REVIEW TEST GUIDE**, tap **OPEN EVENT PURCHASE**. Reviewers can also reach it through **Profile → Promote**.
2. The review account already has **SWIPESS App Review 622** in the **Approved · Ready for payment** state.
3. Choose Starter, Growth, or Wave.
4. Tap **Continue to purchase**.
5. The native App Store / StoreKit purchase sheet appears.
6. Complete the sandbox purchase.
7. Swipess verifies the Apple transaction with the backend and shows **Purchase verified** confirmation.

Event promotion product identifiers:

- Starter: `Swipess.promo.event.week.v3`
- Growth: `Swipess.promo.event.month.v3`
- Wave: `Swipess.promo.event.quarter.v3`

## Important reviewer notes

- These are **StoreKit In-App Purchases**, not Apple Pay checkouts.
- No external checkout URL is exposed in the iOS purchase paths above.
- Submitting an event does **not** charge the customer.
- Admin approval does **not** publish the event.
- Rejected events are not charged.
- The event purchase button is available only for an approved submission.
- The prepared review sample avoids requiring an Apple reviewer to wait for a human moderator.
- The review event is deliberately kept out of the public Events feed after a sandbox purchase.
- Normal approved customer events are published only after payment verification succeeds.
