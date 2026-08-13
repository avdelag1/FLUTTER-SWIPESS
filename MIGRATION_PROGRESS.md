# Capacitor → Flutter migration progress

Tracking the final stretch of the **Swipess** rewrite from the Capacitor/React app
(`avdelag1/swipess`) to native Flutter (`avdelag1/FLUTTER-SWIPESS`).

Design source of truth stays `BRAIN.md` + `docs/DESIGN_CONTRACT.md`. This file tracks
**migration completeness**, not visual parity.

**Status: IN PROGRESS — Dart layer complete, native platform layer being closed.**

---

## Audit — 2026-08-13

### Already done (no action needed)

| Area | State |
|------|-------|
| Capacitor plugins / WebView / hybrid bridges | **None left.** No `@capacitor/*`, no `webview_flutter`, no JS bridge anywhere in `lib/`. |
| Screens | 256 Dart files / ~56k LOC. Every Capacitor route has a real Flutter screen. |
| Navigation | GoRouter with the full Capacitor path table (`AppPaths`), shell route, redirects, `*` → `NotFoundScreen`. |
| State management | Riverpod throughout (`Notifier` / `AsyncNotifier`), no stray `setState` business logic. |
| Backend | Supabase behind repositories under `features/*/data/`. |
| Auth | Native Apple (`sign_in_with_apple`) + Google (`google_sign_in`) ID-token flows — not a webview redirect. |
| Native capability packages | camera, image/file picker, geolocator, local_auth, record, flutter_tts, share_plus, url_launcher, purchases_flutter, flutter_map. |
| Analyzer | `flutter analyze` — clean. |
| Tests | `flutter test` — 15 passing. |

### Remaining work — the native platform layer

The Dart side is finished; what is *not* finished is everything under `android/` and `ios/`.
Both are still largely the **stock Flutter template**, which means the app cannot ship and
several already-written Dart features silently no-op on a real device.

#### P0 — App identity is still the Flutter template

| Item | Current | Target (from Capacitor) |
|------|---------|-------------------------|
| Android `applicationId` / `namespace` | `com.example.flutter_swipes` | `com.swipess.mobile` |
| Android `MainActivity` package | `com.example.flutter_swipes` | `com.swipess.mobile` |
| Android app label | `flutter_swipes` | `Swipess` (`@string/app_name`) |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.example.flutterSwipes` | `com.swipess.mobile` |
| iOS `CFBundleDisplayName` / `CFBundleName` | `Flutter Swipes` / `flutter_swipes` | `Swipess` |
| `pubspec.yaml` description | `A new Flutter project.` | real description |
| Version | `1.0.0+1` | must continue the shipped line (Capacitor is `1.2.33+490`) or the store rejects the upload |

Template `TODO:` comments are still in `android/app/build.gradle.kts`.

#### P0 — Missing permissions and intent queries (breaks working Dart code)

`canLaunchUrl` is used by `EventConnect.open` (promoter WhatsApp), the event
"add to calendar" action, and `invite_friends_dialog`. On **Android 11+ it returns
`false` unless the target intent is declared in `<queries>`** — so those buttons do
nothing on a modern device. iOS has the same problem for non-`https` schemes without
`LSApplicationQueriesSchemes`.

Also missing versus the Capacitor manifest/plist:

- Android: `RECORD_AUDIO` (the `record` package is used for voice notes / dictation),
  `MODIFY_AUDIO_SETTINGS`, `POST_NOTIFICATIONS`.
- iOS: `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSContactsUsageDescription`,
  `NSCalendarsUsageDescription`, `NSRemindersUsageDescription`,
  `NSSpeechRecognitionUsageDescription`, `ITSAppUsesNonExemptEncryption`.
- iOS: no `Runner.entitlements` at all, so **Sign in with Apple cannot work** on device
  (`com.apple.developer.applesignin` is required and Capacitor declares it).

#### P0 — No deep linking on either platform

The app hands out `https://www.swipess.com/...` URLs in eight places (listing share,
profile share, event share, VAP validation QR, invite link) and Supabase sends password
recovery mail to `https://www.swipess.com/reset-password`. Neither platform registers a
single intent filter or associated domain, so every one of those links opens the website
instead of the app — the most visible "still feels like a web app" gap left.

Router gaps that go with it:

- `/u/:id` is shared by `profile_screen`, `profile_detail_screen` and
  `public_profile_preview_screen` but **is not a route** — an inbound share link 404s.
- `/` (the invite link `https://www.swipess.com/?ref=…`) is not a route either.
- Nothing listens for `AuthChangeEvent.passwordRecovery`, so even once the recovery link
  reaches the app it would not land on `/reset-password`.

#### P1 — Migration leftovers in the repo

- 11 tracked agent scratch files at the repo root (`scratch_*.py`, `scratch/`,
  `fix_deck.py`, `diff.patch`).
- `lib/src/core/routing/cap_placeholder_screen.dart` — "route not fully ported yet"
  stand-in, now referenced by nothing.

---

## Change log

_(newest last)_

- **2026-08-13** — Audit above written. Confirmed zero Capacitor/WebView leftovers in Dart;
  scoped the remainder to the native platform layer.
