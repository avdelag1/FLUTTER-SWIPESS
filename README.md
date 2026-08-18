# Flutter Swipess

Native Flutter rewrite of Swipess (`avdelag1/swipess`).

**Live web (this repo):** [www.swipess.com](https://www.swipess.com) · [flutter-swipess.vercel.app](https://flutter-swipess.vercel.app)

Push `main` to GitHub and Vercel rebuilds both URLs automatically.

**Design source of truth is the live Capacitor app, not a new Flutter look.** Agents: read `BRAIN.md` and `docs/DESIGN_CONTRACT.md` first. To start a design pass, paste a prompt from `docs/PROMPTS.md`.

Migration state lives in [`MIGRATION_PROGRESS.md`](MIGRATION_PROGRESS.md).

## Running it

```bash
flutter pub get
flutter run                      # device or emulator
flutter run -d chrome            # web
```

Supabase URL and anon key fall back to the shared project. To point somewhere
else, copy `dart_defines.json.example` to `dart_defines.json` and run with
`--dart-define-from-file=dart_defines.json`.

## Native app

Both platforms ship as `com.swipess.mobile`, the same identifier as the
Capacitor build, so this installs over it as an update.

| | |
|---|---|
| iOS store mode | Release/Profile xcconfigs explicitly lock Flutter to AOT release/profile mode; CI rejects a store bundle containing debug `kernel_blob.bin` |
| Android release signing | reads `android/key.properties` (git-ignored); when absent, release output stays unsigned and never falls back to debug signing |
| Android target | pinned to Android 16 / API 36 for current Google Play submission policy |
| Deep links | App Links / Universal Links on `swipess.com`, `www.swipess.com`, `swipess.app`, plus a `swipess://` scheme |
| Verification files | `assetlinks.json` and `apple-app-site-association` still have to be served from those hosts — see `MIGRATION_PROGRESS.md` |

For the Google Play upload key, copy `android/key.properties.example` to
`android/key.properties` and fill it with the existing Play upload-key values.
Never create a replacement key for an already-published app unless Play Console
is explicitly doing an upload-key reset.

## Store builds

```bash
flutter clean
flutter pub get

# Apple / TestFlight — production AOT build only
flutter build ipa --release

# Google Play — requires the real android/key.properties to produce a signed upload
flutter build appbundle --release
```

Every TestFlight/App Store upload must use a new build number. The Flutter
`version:` value in `pubspec.yaml` is the source for both iOS and Android.

## Checks

```bash
flutter analyze
flutter test
```
