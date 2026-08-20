# App Review — Event Promotion Purchase (Build 622)

## What this flow demonstrates

Swipess moderates event advertisements before charging the customer. A submission is never charged while it is pending review and a rejected submission cannot open checkout.

The lifecycle is:

1. Event details are submitted.
2. Swipess moderation approves or rejects the event.
3. Approval unlocks the native in-app purchase.
4. Apple verifies the purchase on the server.
5. Only a verified purchase activates the promotion.

## App Review test path

Use the App Review credentials supplied in App Store Connect.

1. Sign in to Swipess.
2. Open **Events**.
3. Open **Promote / Promote your event**.
4. The review account already has **SWIPESS App Review 622** in the **Approved · Ready for payment** state.
5. Choose Starter, Growth, or Wave.
6. Tap **Continue to purchase**.
7. The native App Store / StoreKit purchase sheet appears.
8. Complete the sandbox purchase.
9. Swipess verifies the Apple transaction with the backend and shows **Purchase verified** confirmation.

The App Review sample is deliberately kept out of the public Events feed after the sandbox purchase. The review sample remains approved so another reviewer can repeat the consumable sandbox purchase when the screen is reopened. Normal approved customer events are published only after payment verification succeeds.

## Important reviewer notes

- Submitting an event does **not** charge the customer.
- Admin approval does **not** publish the event.
- Rejected events are not charged.
- The purchase button is available only for an approved submission.
- iOS event promotion uses Apple In-App Purchase; no external checkout URL is exposed in the iOS purchase path.
- The prepared review sample avoids requiring an Apple reviewer to wait for a human moderator.
- The prepared review sample is repeatable and never appears publicly in the Events feed.

## Product identifiers

- Starter: `Swipess.promo.event.week.v3`
- Growth: `Swipess.promo.event.month.v3`
- Wave: `Swipess.promo.event.quarter.v3`
