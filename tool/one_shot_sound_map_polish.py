from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"Expected block not found in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# Premium, dependency-free system sound + haptic vocabulary.
# ---------------------------------------------------------------------------
replace_once(
    "lib/src/core/utils/app_haptics.dart",
    """  /// A satisfying \"snap\" when a swipe is registered (like Tinder).\n  static Future<void> swipeSnap() async {\n    await HapticFeedback.mediumImpact();\n    await Future.delayed(const Duration(milliseconds: 40));\n    await HapticFeedback.lightImpact();\n  }\n}\n""",
    """  /// A satisfying \"snap\" when a swipe is registered (like Tinder).\n  static Future<void> swipeSnap() async {\n    await HapticFeedback.mediumImpact();\n    await Future.delayed(const Duration(milliseconds: 40));\n    await HapticFeedback.lightImpact();\n  }\n\n  /// Tiny native-style acknowledgement when voice input opens. This deliberately\n  /// uses the platform sound API instead of an audio package/asset so it is\n  /// instant, respects the device's sound policy, and adds no playback engine.\n  static Future<void> voiceStart() async {\n    await SystemSound.play(SystemSoundType.click);\n    await HapticFeedback.lightImpact();\n  }\n\n  /// One crisp tick for the visible 3 → 2 → 1 hands-free countdown.\n  static Future<void> countdownTick(int value) async {\n    await SystemSound.play(SystemSoundType.click);\n    if (value <= 1) {\n      await HapticFeedback.mediumImpact();\n    } else {\n      await HapticFeedback.selectionClick();\n    }\n  }\n\n  /// Confirms an automatic voice send without introducing a long sound effect.\n  static Future<void> voiceCommit() async {\n    await SystemSound.play(SystemSoundType.click);\n    await HapticFeedback.mediumImpact();\n  }\n\n  /// Shared in-app notification tone. Important events get the platform alert;\n  /// routine confirmations stay on the subtle system click.\n  static Future<void> notification({bool important = false}) async {\n    await SystemSound.play(\n      important ? SystemSoundType.alert : SystemSoundType.click,\n    );\n    if (important) {\n      await HapticFeedback.selectionClick();\n    }\n  }\n}\n""",
)


# ---------------------------------------------------------------------------
# Dashboard voice: restore visible 3/2/1 in the mic itself + premium ticks.
# ---------------------------------------------------------------------------
replace_once(
    "lib/src/core/widgets/glow_search_bar.dart",
    """    _countdownTimer?.cancel();\n    setState(() => _countdown = 3);\n    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {\n""",
    """    _countdownTimer?.cancel();\n    setState(() => _countdown = 3);\n    unawaited(AppHaptics.countdownTick(3));\n    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {\n""",
)
replace_once(
    "lib/src/core/widgets/glow_search_bar.dart",
    """      final current = _countdown ?? 0;\n      if (current > 1) {\n        setState(() => _countdown = current - 1);\n        return;\n      }\n      timer.cancel();\n      _countdownTimer = null;\n      setState(() => _countdown = null);\n      unawaited(_finishVoiceAndSubmit());\n""",
    """      final current = _countdown ?? 0;\n      if (current > 1) {\n        final next = current - 1;\n        setState(() => _countdown = next);\n        unawaited(AppHaptics.countdownTick(next));\n        return;\n      }\n      timer.cancel();\n      _countdownTimer = null;\n      setState(() => _countdown = null);\n      unawaited(AppHaptics.voiceCommit());\n      unawaited(_finishVoiceAndSubmit());\n""",
)
replace_once(
    "lib/src/core/widgets/glow_search_bar.dart",
    """    AppHaptics.light();\n    FocusManager.instance.primaryFocus?.unfocus();\n""",
    """    unawaited(AppHaptics.voiceStart());\n    FocusManager.instance.primaryFocus?.unfocus();\n""",
)
replace_once(
    "lib/src/core/widgets/glow_search_bar.dart",
    """            child: _transcribing\n                ? SizedBox(\n                    width: 15,\n                    height: 15,\n                    child: CircularProgressIndicator(\n                      strokeWidth: 2,\n                      color: blue,\n                    ),\n                  )\n                : _voiceActive\n                ? BreathingWidget(\n                    duration: const Duration(milliseconds: 1050),\n                    minOpacity: .55,\n                    maxOpacity: 1,\n                    child: const Icon(\n                      Icons.mic_rounded,\n                      color: Colors.white,\n                      size: 18,\n                    ),\n                  )\n                : Icon(Icons.mic_rounded, color: blue, size: 18),\n""",
    """            child: _countdown != null\n                ? Text(\n                    '$_countdown',\n                    key: ValueKey<int>(_countdown!),\n                    style: GoogleFonts.plusJakartaSans(\n                      color: Colors.white,\n                      fontSize: 15,\n                      fontWeight: FontWeight.w900,\n                      height: 1,\n                    ),\n                  )\n                : _transcribing\n                ? SizedBox(\n                    width: 15,\n                    height: 15,\n                    child: CircularProgressIndicator(\n                      strokeWidth: 2,\n                      color: blue,\n                    ),\n                  )\n                : _voiceActive\n                ? BreathingWidget(\n                    duration: const Duration(milliseconds: 1050),\n                    minOpacity: .55,\n                    maxOpacity: 1,\n                    child: const Icon(\n                      Icons.mic_rounded,\n                      color: Colors.white,\n                      size: 18,\n                    ),\n                  )\n                : Icon(Icons.mic_rounded, color: blue, size: 18),\n""",
)


# ---------------------------------------------------------------------------
# Intel Core voice uses the same audible language as the dashboard.
# ---------------------------------------------------------------------------
replace_once(
    "lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart",
    """    AppHaptics.light();\n    ref.read(deckSoundOnProvider.notifier).setSoundOn(false);\n""",
    """    unawaited(AppHaptics.voiceStart());\n    ref.read(deckSoundOnProvider.notifier).setSoundOn(false);\n""",
)
replace_once(
    "lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart",
    """    _countdownTimer?.cancel();\n    setState(() => _countdown = 3);\n    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {\n""",
    """    _countdownTimer?.cancel();\n    setState(() => _countdown = 3);\n    unawaited(AppHaptics.countdownTick(3));\n    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {\n""",
)
replace_once(
    "lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart",
    """      final current = _countdown ?? 0;\n      if (current > 1) {\n        setState(() => _countdown = current - 1);\n        return;\n      }\n      timer.cancel();\n      _countdownTimer = null;\n      setState(() => _countdown = null);\n      unawaited(_submit());\n""",
    """      final current = _countdown ?? 0;\n      if (current > 1) {\n        final next = current - 1;\n        setState(() => _countdown = next);\n        unawaited(AppHaptics.countdownTick(next));\n        return;\n      }\n      timer.cancel();\n      _countdownTimer = null;\n      setState(() => _countdown = null);\n      unawaited(AppHaptics.voiceCommit());\n      unawaited(_submit());\n""",
)


# ---------------------------------------------------------------------------
# Peer chat voice gets the same start/countdown/send feedback.
# ---------------------------------------------------------------------------
replace_once(
    "lib/src/features/messages/presentation/screens/chat_screen.dart",
    """    _countdownTimer?.cancel();\n    setState(() => _countdown = 3);\n    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {\n""",
    """    _countdownTimer?.cancel();\n    setState(() => _countdown = 3);\n    unawaited(AppHaptics.countdownTick(3));\n    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {\n""",
)
replace_once(
    "lib/src/features/messages/presentation/screens/chat_screen.dart",
    """      final current = _countdown ?? 0;\n      if (current > 1) {\n        setState(() => _countdown = current - 1);\n        return;\n      }\n      timer.cancel();\n      _countdownTimer = null;\n      setState(() => _countdown = null);\n      unawaited(_finishVoiceAndSend());\n""",
    """      final current = _countdown ?? 0;\n      if (current > 1) {\n        final next = current - 1;\n        setState(() => _countdown = next);\n        unawaited(AppHaptics.countdownTick(next));\n        return;\n      }\n      timer.cancel();\n      _countdownTimer = null;\n      setState(() => _countdown = null);\n      unawaited(AppHaptics.voiceCommit());\n      unawaited(_finishVoiceAndSend());\n""",
)
replace_once(
    "lib/src/features/messages/presentation/screens/chat_screen.dart",
    """    AppHaptics.light();\n    try {\n""",
    """    unawaited(AppHaptics.voiceStart());\n    try {\n""",
)


# ---------------------------------------------------------------------------
# Global in-app notification tone: messages/matches/errors are distinctive;
# routine success/like/info remains a soft click.
# ---------------------------------------------------------------------------
replace_once(
    "lib/src/core/providers/app_notification_provider.dart",
    """import 'package:flutter_riverpod/flutter_riverpod.dart';\n""",
    """import 'dart:async';\n\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n""",
)
replace_once(
    "lib/src/core/providers/app_notification_provider.dart",
    """    state = [toast, ...state].take(_maxQueued).toList(growable: false);\n  }\n""",
    """    state = [toast, ...state].take(_maxQueued).toList(growable: false);\n\n    final important =\n        type == AppToastType.message ||\n        type == AppToastType.match ||\n        type == AppToastType.newUser ||\n        type == AppToastType.error ||\n        type == AppToastType.warning;\n    unawaited(AppHaptics.notification(important: important));\n  }\n""",
)


# ---------------------------------------------------------------------------
# Back from map detail must pop the detail BEFORE closing the preserved map.
# ---------------------------------------------------------------------------
replace_once(
    "lib/src/core/routing/global_back_dispatcher.dart",
    """  @override\n  Future<bool> didPopRoute() async {\n    if (_closeOpenOverlay()) return true;\n    if (await super.didPopRoute()) return true;\n\n    final parent = SectionNavigation.parentRoute(_currentLocation());\n""",
    """  @override\n  Future<bool> didPopRoute() async {\n    final modals = ref.read(overlayModalsProvider);\n\n    // The map overlay deliberately stays mounted while a pushed listing, event,\n    // or profile detail is visible. In that state Back belongs to the detail\n    // route first; closing the overlay first loses the user's map context and\n    // makes the next screen look like a jump to Dashboard.\n    if (modals.showPassportMap && _isMapDetailRoute(_currentLocation())) {\n      if (await super.didPopRoute()) return true;\n    }\n\n    if (_closeOpenOverlay()) return true;\n    if (await super.didPopRoute()) return true;\n\n    final parent = SectionNavigation.parentRoute(_currentLocation());\n""",
)
replace_once(
    "lib/src/core/routing/global_back_dispatcher.dart",
    """  bool _closeOpenOverlay() {\n""",
    """  bool _isMapDetailRoute(String route) {\n    return route.startsWith('/listing/') ||\n        route.startsWith('/profile/') ||\n        route.startsWith('/explore/events/') ||\n        route.startsWith('/preview/listing/') ||\n        route.startsWith('/preview/profile/');\n  }\n\n  bool _closeOpenOverlay() {\n""",
)


# ---------------------------------------------------------------------------
# Native map: hard exclusion gate for anything already saved/liked, plus direct
# provider invalidation. This mirrors the already-correct web map behavior.
# ---------------------------------------------------------------------------
replace_once(
    "lib/src/features/map/presentation/screens/real_mapbox_screen_v3.dart",
    """    final events = ref.read(eventsListProvider).value ?? const <Event>[];\n    final likedEvents = ref.read(likedEventIdsProvider).value ?? const <String>{};\n    return <_Item>[\n      for (final l in listings) _listingItem(l, loc),\n      for (final p in profiles) _profileItem(p, loc),\n      for (final e in events)\n        if (_eventInCity(e, loc) && !likedEvents.contains(e.id)) _eventItem(e, loc),\n""",
    """    final events = ref.read(eventsListProvider).value ?? const <Event>[];\n    final likedListings =\n        ref.read(likedListingIdsProvider).value ?? const <String>{};\n    final likedPeople =\n        ref.read(likedPeopleIdsProvider).value ?? const <String>{};\n    final likedEvents = ref.read(likedEventIdsProvider).value ?? const <String>{};\n    return <_Item>[\n      for (final l in listings)\n        if (!likedListings.contains(l.id)) _listingItem(l, loc),\n      for (final p in profiles)\n        if (!likedPeople.contains(p.id)) _profileItem(p, loc),\n      for (final e in events)\n        if (_eventInCity(e, loc) && !likedEvents.contains(e.id)) _eventItem(e, loc),\n""",
)
replace_once(
    "lib/src/features/map/presentation/screens/real_mapbox_screen_v3.dart",
    """      if (item.listing != null) {\n        await repo.likeListing(item.id);\n        ref.invalidate(likedListingsProvider);\n        ref.invalidate(mapListingsProvider);\n      } else if (item.profile != null) {\n        await repo.likePerson(item.id);\n        ref.invalidate(likedPeopleProvider);\n        ref.invalidate(mapProfilesProvider);\n""",
    """      if (item.listing != null) {\n        await repo.likeListing(item.id);\n        ref.invalidate(likedListingsProvider);\n        ref.invalidate(likedListingIdsProvider);\n        ref.invalidate(mapListingsProvider);\n      } else if (item.profile != null) {\n        await repo.likePerson(item.id);\n        ref.invalidate(likedPeopleProvider);\n        ref.invalidate(likedPeopleIdsProvider);\n        ref.invalidate(mapProfilesProvider);\n""",
)
replace_once(
    "lib/src/features/map/presentation/screens/real_mapbox_screen_v3.dart",
    """    ref.watch(eventsListProvider);\n    ref.watch(likedEventIdsProvider);\n\n    ref.listen(discoveryLocationProvider, (oldValue, next) {\n""",
    """    ref.watch(eventsListProvider);\n    ref.watch(likedListingIdsProvider);\n    ref.watch(likedPeopleIdsProvider);\n    ref.watch(likedEventIdsProvider);\n\n    ref.listen(discoveryLocationProvider, (oldValue, next) {\n""",
)
replace_once(
    "lib/src/features/map/presentation/screens/real_mapbox_screen_v3.dart",
    """    ref.listen(eventsListProvider, (_, __) => unawaited(_render()));\n    ref.listen(likedEventIdsProvider, (_, __) => unawaited(_render()));\n\n    final items = _items();\n""",
    """    ref.listen(eventsListProvider, (_, __) => unawaited(_render()));\n    ref.listen(likedListingIdsProvider, (_, __) => unawaited(_render()));\n    ref.listen(likedPeopleIdsProvider, (_, __) => unawaited(_render()));\n    ref.listen(likedEventIdsProvider, (_, __) => unawaited(_render()));\n\n    final items = _items();\n""",
)

# Clearer, visually consistent native map options menu without changing behavior.
replace_once(
    "lib/src/features/map/presentation/screens/real_mapbox_screen_v3.dart",
    """    return Container(\n      width: 190,\n      padding: const EdgeInsets.symmetric(vertical: 5),\n      decoration: BoxDecoration(\n        color: const Color(0xFAFFFFFF),\n        borderRadius: BorderRadius.circular(17),\n        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 9))],\n      ),\n      child: Column(mainAxisSize: MainAxisSize.min, children: [\n        row(Icons.location_city_rounded, 'Choose city', onCities),\n""",
    """    return Container(\n      width: 204,\n      padding: const EdgeInsets.symmetric(vertical: 6),\n      decoration: BoxDecoration(\n        color: const Color(0xFAFFFFFF),\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: const Color(0x12000000)),\n        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 9))],\n      ),\n      child: Column(mainAxisSize: MainAxisSize.min, children: [\n        Padding(\n          padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),\n          child: Align(\n            alignment: Alignment.centerLeft,\n            child: Text(\n              'MAP OPTIONS',\n              style: GoogleFonts.plusJakartaSans(\n                color: Colors.black45,\n                fontSize: 8.5,\n                fontWeight: FontWeight.w900,\n                letterSpacing: 1.15,\n                decoration: TextDecoration.none,\n              ),\n            ),\n          ),\n        ),\n        row(Icons.location_city_rounded, 'Choose city', onCities),\n""",
)
replace_once(
    "lib/src/features/map/presentation/screens/real_mapbox_screen_v3.dart",
    """            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),\n            child: Row(children: [\n              Icon(icon, size: 17, color: const Color(0xFF111318)),\n              const SizedBox(width: 9),\n              Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),\n""",
    """            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),\n            child: Row(children: [\n              Icon(icon, size: 17, color: const Color(0xFF111318)),\n              const SizedBox(width: 10),\n              Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF111318), fontSize: 11.2, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),\n""",
)

print("sound/map polish patch applied")
