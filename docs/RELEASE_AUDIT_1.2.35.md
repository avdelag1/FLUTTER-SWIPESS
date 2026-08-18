# Swipess Release Audit — 1.2.35 (611)

Date: 2026-08-17

## Release candidate status

Swipess 1.2.35 (Build 611) is the current release candidate for Apple handoff. The application code, production web deployment path, iOS bundle/version wiring, privacy manifest, account-deletion flow, StoreKit validation path, core discovery/map experience, and release-critical backend permissions were reviewed in this release pass.

This document distinguishes technical release readiness from account-specific App Store Connect and Apple sandbox checks that cannot be completed without the Apple developer account/test credentials.

## Verified application and build health

- Flutter version source is `1.2.35+611`; iOS reads `FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER`, and Android reads Flutter versionName/versionCode.
- iOS bundle identifier remains `com.swipess.mobile`, minimum iOS target remains 15.0, and signing-team configuration is preserved.
- iOS permission descriptions exist for camera, photo library, microphone, location, and Face ID.
- Sign in with Apple and the `swipess.com` / `www.swipess.com` associated domains remain configured.
- `PrivacyInfo.xcprivacy` is present and declares the app's current privacy-data categories and required-reason API access.
- Startup keeps the first frame lightweight, initializes Supabase behind the startup surface, retries transient initialization once, and defers non-critical warmup work.
- The dashboard warms discovery data before map entry so listings/users can already be in memory.
- The current web discovery map keeps the real Mapbox globe while Flutter projects the live Swipess listings/users, avoiding the unstable Mapbox web annotation-manager path.
- Listing/user marker previews, second-tap navigation, radius, city/range filters, recenter, zoom and hide/show controls are preserved.
- Account deletion is available in-app and routes through the authenticated `delete-user` Edge Function before sign-out.
- CI is configured to run dependency resolution, analyzer, tests, a release web build, and a no-codesign iOS release build on main pushes.

## Purchase and subscription integrity

- Native Apple subscriptions map to active production packages:
  - `Swipess.plus.monthly.v3` → Basic Client
  - `Swipess.plus.semestral.v3` → Premium Client
  - `Swipess.plus.annual.v3` → Unlimited Client
- Native token products remain allowlisted by exact StoreKit product identifier.
- Apple receipt validation authenticates the calling Swipess user, validates with Apple production first and sandbox on status 21007, verifies the requested product exists in the receipt, and uses a transaction replay guard before granting entitlement.
- Same-tier subscription renewals use an upsert on `(user_id, package_id)` so an existing package row can be refreshed instead of failing its uniqueness constraint.
- Event-promo StoreKit products are intentionally not shipped as native entitlements in this release and now fail deterministically before receipt processing rather than producing an internal-server error.
- Apple receipt validator production deployment is synced with the repository version used by this release audit.

## Release security hardening completed

The release audit found and closed several high-impact backend permission issues before stamping the release:

- Authenticated clients can now **read only** their own `user_subscriptions` rows; direct client insert/update/delete access to paid subscription entitlements was removed.
- `purchase_audit_log` is backend/service-role only, protecting the purchase replay guard from client mutation.
- Internal helper views `app_users` and `other_profiles` now use security-invoker behavior and are no longer exposed to app clients.
- Legacy privileged RPC overloads for direct subscription changes, account deletion, arbitrary sender messaging, admin-style block/unblock/verification, legacy token-balance lookup and broad profile retrieval are service-role only.
- Legitimate authenticated RPCs used by the app keep authenticated access while anonymous/PUBLIC execution was removed from the release-sensitive set.
- The production migration implementing these restrictions was applied and the resulting grants/ACLs were verified.

## Items deliberately not mass-changed in this release

The Supabase database has a sizeable legacy advisory backlog (older SECURITY DEFINER RPC exposure, mutable function search paths, duplicate/permissive RLS policies, index tuning and PostGIS schema advisories). These should be addressed in controlled migrations by feature area rather than with a blanket permission rewrite that could break live discovery, messaging, legal/business, trigger, or admin flows.

The release-critical entitlement/payment bypasses discovered during this audit were fixed. The remaining advisor backlog should stay visible as a post-release hardening project.

## Strongly recommended platform follow-up

- Enable Supabase leaked-password protection in Auth settings.
- Schedule the available Supabase/Postgres security-patch upgrade.
- Continue reducing legacy anonymous SECURITY DEFINER RPC exposure and setting explicit function `search_path` values in feature-scoped migrations.
- Consolidate duplicate/permissive RLS policies and add the advisor-recommended foreign-key/query indexes after measuring the affected hot paths.
- Keep PostGIS/system-table changes separate from ordinary app-schema migrations.

## Apple handoff / manual validation still required

Before submitting this build for review, use the Apple developer account to complete the account-specific checks that cannot be verified from the repository/backend alone:

1. Archive/upload **Swipess 1.2.35 (611)** to App Store Connect/TestFlight.
2. Install the TestFlight or sandbox build on a real supported iPhone and complete one subscription purchase.
3. Test restore purchases.
4. Test a same-tier subscription renewal/repurchase/restore scenario so the refreshed upsert path is exercised.
5. Test at least one token IAP if token packs are included in this App Store submission.
6. Confirm all StoreKit products submitted with the build are in the intended App Store Connect state and match the exact IDs in the app/backend.
7. Complete App Store metadata, screenshots, privacy answers, review notes, agreements, tax/banking and any required IAP review metadata.

## Release conclusion

**1.2.35 (611) is the technical release candidate for Apple handoff.** The release-critical code and backend integrity issues found in this pass were corrected. The remaining work is primarily Apple-account/TestFlight validation plus a broader legacy Supabase hardening/performance backlog that should be handled incrementally rather than risking a last-minute regression in the shipping build.
