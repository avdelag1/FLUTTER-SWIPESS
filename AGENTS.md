# AI Agent Instructions (AGENTS.md)

Welcome, fellow AI Agent. This is **Flutter Swipess** — a native rewrite of the Capacitor app **Swipess**.

**Read `BRAIN.md` first.** Then `docs/DESIGN_CONTRACT.md`. Those files are the project brain: mission, design source of truth, and screen order.

## 0. Design source of truth (non-negotiable)

We are **closing the Capacitor design onto Flutter**, not inventing a new look.

- Visual / UX source of truth: GitHub `avdelag1/swipess` (Capacitor). Live web is this Flutter repo on Vercel: https://www.swipess.com and https://flutter-swipess.vercel.app
- Clone it (`git clone --depth 1 https://github.com/avdelag1/swipess.git /tmp/swipess`) and match the Capacitor file for the screen you are building.
- This repo must look like that app: italic **SWIPESS** wordmark, black canvas, pill chrome, orange-red `#FF4D00` CTAs, glass HUD, photo category cards, floating glowing dock, full-bleed swipe reel.
- If it looks like a generic Flutter demo (Material AppBar, gradient orbs, Tinder circles, missing wordmark), it is **wrong**.
- “Aesthetics are paramount” means **pixel-faithful to Capacitor**, not a new glassmorphism concept.
- Always-on rule: `.cursor/rules/match-capacitor-design.mdc`
- Skills: `.cursor/skills/close-capacitor-design/SKILL.md` and `.cursor/skills/swipess-build-order/SKILL.md`
- Copy-paste prompts for the owner: `docs/PROMPTS.md`

**Build order:** access gate → welcome → sign in/sign up → dashboard → photo swipe deck → remaining surfaces.

Design passes may stub auth. A **bases** agent wires Supabase repositories, real OAuth, and persistence — without restyling.

## 1. Core Architecture
- **State Management**: We use **Riverpod** (`flutter_riverpod`). Do NOT use raw `setState` for anything beyond simple local UI animations. All business logic must live in Notifier/AsyncNotifier classes.
- **Routing**: We use **GoRouter** for clean, declarative, and deep-linkable navigation.
- **Backend integration**: We use **Supabase**. All Supabase queries must be abstracted behind a Repository layer (e.g., `UserRepository`, `SwipeRepository`). Never call Supabase directly from the UI.

## 2. Folder Structure (Feature-First)
We organize code by feature, NOT by type.
```text
lib/
  src/
    features/
      swipes/
        presentation/ (Widgets, Screens, Controllers)
        domain/ (Models, Entities)
        data/ (Repositories, API calls)
      auth/
        ...
    core/
      theme/ (Colors, Typography)
      utils/ (Helpers)
      constants/
      services/ (Supabase initialization, logging)
```

## 3. UI / UX Principles
- **Match Capacitor first**: tokens, type, chrome, glow, and motion from `avdelag1/swipess`. See `docs/DESIGN_CONTRACT.md`.
- **Performance**: Ensure 60fps (or 120fps) by avoiding expensive rebuilds. Use `const` widgets everywhere possible.
- **Components**: Break down complex UI into small, reusable, stateless widgets. Avoid giant `build` methods.

## 4. Code Quality
- All new files must be completely free of analyzer warnings. Run `flutter analyze` after every modification.
- Document any complex business logic with clear docstrings.
- Always handle loading states and error states gracefully (never just show a blank screen).

## 5. Native dashboard + map regression guardrails (non-negotiable)

These rules capture regressions fixed on **2026-08-29**. Read them before changing dashboard chrome, AI results, Mapbox, Likes discovery, or map preview controls. Functional reference commit: `b0f65262d08c429ffe8e07e39d1ee8c524214af6`.

### Never blur the whole native app
- Do **not** put an unbounded `BackdropFilter` around `AppTopBar`, persistent dashboard chrome, the navigation dock, or another always-visible native layer.
- On iOS, a backdrop filter can escape the apparent widget area and blur the entire composited screen, making the app look as if a modal is permanently open.
- Persistent header/dock chrome should use painted translucent/opaque backgrounds without live global blur.
- If blur is truly needed for a temporary modal, clip it explicitly to that modal's exact bounds and remove it when the modal closes.
- Diagnostic rule: if the page is blurred while the header is visible and becomes clear when scrolling hides the header, treat it as a leaked/unbounded backdrop filter — **never** as an intentional scroll effect.

### Dashboard AI result behavior
- Keep the dashboard AI answer in a **medium-sized result window**; do not expand it into a giant page-length response.
- The AI result window must be able to scroll internally.
- Internal/nested AI scrolling must **not** trigger the global dashboard header/dock hide behavior.
- Genuine dashboard scrolling may hide/reveal chrome with a soft professional fade/slide/ghost transition, but it must never blur the whole page or leave a giant empty black gap.
- Keep dashboard answers concise; extended interaction belongs behind **Continue in chat**.

### Native Mapbox cinematic is intentional
- Every **fresh native Map open** must start on the real Mapbox **3D globe/world**, visibly hold long enough to read as intentional, then perform the cinematic flight/zoom into the active/current area.
- Do **not** hard-code `playIntro` or `_showIntro` off on a fresh Map open.
- Do not replace this with an instant jump, fake/static map, or generic 2D substitute when Mapbox is available.
- When a listing/profile/event is opened from Map, preserve the existing live map instance offstage. Back must reveal the **same map state** without replaying the intro, refetching, or resetting camera/pins.
- Opening Map temporarily suppresses dashboard/deck audio; closing Map resumes audio **only if it was playing before Map opened**.

### Already-liked items stay out of Map discovery
- Listings, people, and events already right-swiped/saved by the current user must not reappear in Map discovery.
- Use canonical Like IDs plus loaded liked models as a fallback.
- Do not paint any discovery type while its canonical Likes state is unresolved if that can cause already-liked items to flash/reappear.
- Saving from Map must invalidate the appropriate Likes + Map providers and remove the saved item immediately.

### Map preview buttons are isolated actions
- Only the preview photo/text content area may open the listing/profile/event.
- Heart/save and close (`X`) are independent hit targets. Never wrap them inside one giant parent tap target that navigates to detail.
- Pressing `X` means **close the preview only**. It must never open the listing, Insights, or another route.
- Give close/save controls explicit opaque hit regions so taps cannot fall through or bubble into navigation.

### Native iOS/TestFlight voice is the acceptance target
- A PWA/web pass does **not** certify the voice flow. Always validate the native iOS/TestFlight path separately because Apple Speech recognition has different stop/restart behavior.
- Dashboard AI and Intel Core are one-shot hands-free voice entry points: speech -> silence -> freeze captured transcript -> visible 3 -> 2 -> 1 -> fully finish native recognizer -> exactly one AI submit -> visible reply.
- For those two entry points call `LiveVoiceInput.start(... restartAfterSilence: false)`. Never restart Apple/native recognition underneath an active auto-send countdown.
- Do not auto-resume the dashboard microphone after an AI answer. A new phrase starts from a new explicit microphone tap; this avoids duplicate recognizer sessions and repeated transcript text.
- The AI request must happen only after native voice has finished. A successful transcript with no `ai-concierge` request is a client handoff bug, not an AI-provider outage.
- Keep Intel Core on the same reliable non-streaming `chatConcierge(... stream: false)` response path unless the backend is changed to true streaming and native + web are both regression-tested.

### Voice countdown must survive native recognizer segment restarts
- Native speech engines may end/restart a recognition segment exactly when silence starts the dashboard **3 → 2 → 1** countdown.
- Busy/client/network/server/audio recognizer transition errors during that restart are recoverable. Retry them quietly with a short backoff; do **not** cancel the countdown or show `Voice recognition stopped` for a transient segment restart.
- Permission/authorization failures remain user-facing and fatal for that microphone session.
- **Only actual new recognized transcript text may cancel an active 3 -> 2 -> 1 countdown.** Native `onSoundLevel` / microphone-energy spikes are noisy and can fire when the recognizer restarts after silence; they must never cancel auto-send.
- If the recognizer repeats the exact same transcript (or a shorter prefix of the frozen text) during restart, ignore it and keep counting.
- Once valid text has been captured and the countdown has started, a recognizer stop/restart error must not abort that countdown. The countdown owns the captured text and must reach 3 -> 2 -> 1 -> submit unless genuinely new transcript text arrives or the user explicitly cancels.

### Notification permission is foreground-only
- `AppLifecycleState.paused`, backgrounding, app exit, and reengagement scheduling must **never request notification permission**.
- OS notification permission may only be requested after a clear foreground user action such as tapping an Enable notifications control.
- If permission is not already granted, background reengagement scheduling should quietly do nothing.

### Verification before merging related work
- Format touched Dart files.
- Run `flutter analyze` on touched code.
- Run relevant regression/widget tests, especially persistent chrome overlap/scroll behavior.
- Do not "improve" these flows by reintroducing native global blur, disabling the globe cinematic, showing saved items in discovery, or coupling close/save controls to navigation.

Follow these rules exactly. Close the Swipess design. Do not invent a replacement.
