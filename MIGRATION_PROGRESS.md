# Capacitor → Flutter migration progress

Tracking the final stretch of the **Swipess** rewrite from the Capacitor/React app
(`avdelag1/swipess`) to native Flutter (`avdelag1/FLUTTER-SWIPESS`).

Design source of truth stays `BRAIN.md` + `docs/DESIGN_CONTRACT.md`. This file tracks
**migration completeness**, not visual parity.

**Status: code-complete. Two hosting steps remain before deep links verify in
production — see [Handover](#handover-not-code).**

---

## Audit — 2026-08-13

### Was already done

| Area | State |
|------|-------|
| Capacitor plugins / WebView / hybrid bridges | **None.** No `@capacitor/*`, no `webview_flutter`, no JS bridge anywhere in `lib/`. The remaining "Capacitor" mentions are parity doc-comments naming the source file each screen was ported from. |
| Screens | 255 Dart files / ~56k LOC. Every Capacitor route has a real Flutter screen. |
| Navigation | GoRouter with the full Capacitor path table (`AppPaths`), shell route, redirects, `*` → `NotFoundScreen`. |
| State management | Riverpod throughout (`Notifier` / `AsyncNotifier`). |
| Backend | Supabase behind repositories under `features/*/data/`. |
| Auth | Native Apple (`sign_in_with_apple`) + Google (`google_sign_in`) ID-token flows, not a webview redirect. |
| Native capability packages | camera, image/file picker, geolocator, local_auth, record, flutter_tts, share_plus, url_launcher, purchases_flutter, flutter_map. |

The Dart layer was finished. What was not finished was everything under `android/`
and `ios/`: both were still the **stock Flutter template**, which blocked shipping and
silently broke several already-written features on device.

### Done this pass

**Native identity** — the app was still `com.example.flutter_swipes` / "flutter_swipes".

| Item | Now |
|------|-----|
| Android `applicationId` / `namespace` | `com.swipess.mobile` |
| Android `MainActivity` package | `com.swipess.mobile` |
| Android app label | `Swipess` via `@string/app_name` |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.swipess.mobile` |
| iOS `CFBundleDisplayName` / `CFBundleName` | `Swipess` |
| Version | `1.2.34+491`, continuing the shipped Capacitor line (`1.2.33+490`) — with the identifier now matching, both stores reject a lower build number |
| Release signing | reads `android/key.properties`, falls back to debug keys when absent |
| macOS / Linux / Windows scaffolding, PWA manifest | no `com.example` or `flutter_swipes` left anywhere in the repo |

**Capabilities the Dart layer already depended on.** `canLaunchUrl` returns `false` on
Android 11+ for any intent not declared in `<queries>`, and on iOS for any scheme not in
`LSApplicationQueriesSchemes` — so the promoter WhatsApp button (`EventConnect.open`),
event "add to calendar" and the invite sheet were **silently doing nothing on device**.
Both are now declared. Also added: `RECORD_AUDIO` + `MODIFY_AUDIO_SETTINGS` (the `record`
package is used for voice notes and dictation), `POST_NOTIFICATIONS`, the iOS usage
descriptions Capacitor ships that were missing here, and `ios/Runner/Runner.entitlements`
declaring `com.apple.developer.applesignin` — without which **Sign in with Apple cannot
work on device** even though the Dart side is fully wired.

**Deep links.** The app hands out `https://www.swipess.com/...` URLs from eight places
and Supabase mails password recovery to `/reset-password`, but neither platform
registered a single intent filter or associated domain, and the router could not resolve
some of the URLs it was handing out.

- Android App Links (`autoVerify`) + iOS associated domains for `swipess.com`,
  `www.swipess.com`, `swipess.app`. Only the paths GoRouter can resolve are claimed, so
  marketing pages on the same host still open in the browser.
- A `swipess://` scheme on both platforms as a fallback that needs no server-side file.
  Note that Flutter routes on the URI *path*, so a custom-scheme link must be written
  `swipess:///listing/42` (three slashes); `swipess://listing/42` parses `listing` as the
  host and routes to `/42`.
- `/u/:id` — the member link `profile_screen`, `profile_detail_screen` and
  `public_profile_preview_screen` all copy — was not a route at all. A signed-in user
  following one hit `NotFoundScreen`; everyone else dead-ended at the access gate. It now
  resolves to the public member preview and is reachable without a code, which is what
  "guest-friendly member deep link" was supposed to mean.
- `/` now lands on the gate instead of `NotFoundScreen`.
- A deep link that arrives while the app is gated or signed out is queued and resumed
  after sign-in, so following a shared listing no longer dumps the user on the dashboard.
  It resumes once and is dropped on sign-out.
- `AuthChangeEvent.passwordRecovery` now routes to `/reset-password`. Nothing listened
  for it, so the recovery link had nowhere to go even once it arrived.
- The redirect logic moved to a pure `AppRedirect.resolve`, so the gate/auth rules are
  testable without a live Supabase session. 18 tests cover it.

**Repo cleanup.** Removed 13 tracked scratch scripts that hardcode a previous
developer's local path, a `diff.patch` that was already applied, and
`CapPlaceholderScreen` — the "this Capacitor route is not ported yet" stand-in, which
nothing referenced any more.

### Verification

| Check | Result |
|-------|--------|
| `flutter analyze` | clean |
| `flutter test` | 33 passing (15 pre-existing + 18 new routing tests) |
| `flutter build apk --debug` | builds; merged manifest confirms `com.swipess.mobile`, label `Swipess`, versionCode 491, the `autoVerify` App Links filter with all claimed paths, the `swipess://` filter, the new permissions and the `<queries>` block |
| `flutter build web` | builds; deep-link routing exercised in Chrome end to end |
| iOS build | **not verified** — no macOS host in CI. The plist and entitlements are valid property lists and the bundle ids are set in all three Runner configurations, but nobody has run `xcodebuild` against them yet. |

---

## Handover (not code)

Two things have to happen off this repo before App Links verify in production. Until
then the `https://` links fall back to opening the website, and `swipess:///…` is the
working deep-link form.

1. **`https://<host>/.well-known/assetlinks.json`** on `swipess.com`, `www.swipess.com`
   and `swipess.app`, served as `application/json` over HTTPS with no redirect:

   ```json
   [{
     "relation": ["delegate_permission/common.handle_all_urls"],
     "target": {
       "namespace": "android_app",
       "package_name": "com.swipess.mobile",
       "sha256_cert_fingerprints": ["<release signing cert SHA-256>"]
     }
   }]
   ```

   Use the fingerprint from Play Console → Setup → App integrity (Play App Signing
   re-signs uploads, so the upload keystore's fingerprint is the wrong one).

2. **`https://<host>/.well-known/apple-app-site-association`** on the same hosts, served
   as `application/json`, no `.json` extension, no redirect, with `<TeamID>` being the
   Apple team (`6WYW52MXDF` is what the Xcode project is configured with):

   ```json
   {"applinks":{"details":[{"appIDs":["<TeamID>.com.swipess.mobile"],
     "components":[{"/":"/listing/*"},{"/":"/u/*"},{"/":"/profile/*"},
       {"/":"/explore/events/*"},{"/":"/vap-validate/*"},{"/":"/preview/*"},
       {"/":"/payment/*"},{"/":"/s/*"},{"/":"/reset-password"}]}]}}
   ```

These live wherever `swipess.com` is served from, not in this repo.

## Still open (out of scope for the migration)

- **Push notifications.** `PushNotificationPrompt` is a design-lane stub —
  `_enable()` says as much and no push plugin is in `pubspec.yaml`. The Capacitor app
  declares `aps-environment` and a `remote-notification` background mode; those were
  deliberately *not* copied, because declaring a capability the binary cannot use causes
  provisioning-profile mismatches. Add them together with the plugin.
- **iOS build verification** on a macOS host, per the table above.

---

## Change log

_(newest last)_

- **2026-08-13** — Audit written. Confirmed zero Capacitor/WebView leftovers in Dart and
  scoped the remainder to the native platform layer.
- **2026-08-13** — Native shell rebuilt as the real Swipess app: identity, permissions,
  capabilities, App Links / Universal Links.
- **2026-08-13** — Deep links resolved end to end in Dart: `/u/:id`, `/`, pending-link
  resume, password-recovery routing, pure testable `AppRedirect`.
- **2026-08-13** — Migration scratch files and the last placeholder screen removed;
  remaining template naming replaced across web and desktop scaffolding.
