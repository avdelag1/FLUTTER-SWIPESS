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
| Android release signing | reads `android/key.properties` (git-ignored); falls back to debug keys when absent |
| Deep links | App Links / Universal Links on `swipess.com`, `www.swipess.com`, `swipess.app`, plus a `swipess://` scheme |
| Verification files | `assetlinks.json` and `apple-app-site-association` still have to be served from those hosts — see `MIGRATION_PROGRESS.md` |

## Checks

```bash
flutter analyze
flutter test
```
