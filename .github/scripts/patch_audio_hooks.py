from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count} for {old[:80]!r}')
    p.write_text(text.replace(old, new, 1))

# Swipe: one light swoosh only when a card actually exits the deck.
replace_once(
    'lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart',
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\nimport 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
)
replace_once(
    'lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart',
    "      } else {\n        AppHaptics.medium();\n      }\n      final swiped = widget.listings.first;",
    "      } else {\n        AppHaptics.medium();\n      }\n      unawaited(AppAudio.instance.playSwipeFromPrefs());\n      final swiped = widget.listings.first;",
)

# Mutual match: deeper celebration sound aligned to the modal opening.
replace_once(
    'lib/src/features/swipes/presentation/widgets/match_celebrate_modal.dart',
    "import 'dart:math' as math;\n",
    "import 'dart:async';\nimport 'dart:math' as math;\n",
)
replace_once(
    'lib/src/features/swipes/presentation/widgets/match_celebrate_modal.dart',
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\nimport 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
)
replace_once(
    'lib/src/features/swipes/presentation/widgets/match_celebrate_modal.dart',
    "  AppHaptics.heavy();\n  return showGeneralDialog<void>(",
    "  AppHaptics.heavy();\n  unawaited(AppAudio.instance.playMatchFromPrefs());\n  return showGeneralDialog<void>(",
)

# Direct Request accepted: same connect identity as a mutual match.
replace_once(
    'lib/src/features/payments/presentation/screens/direct_request_review_screen.dart',
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\nimport 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
)
replace_once(
    'lib/src/features/payments/presentation/screens/direct_request_review_screen.dart',
    "      await AppHaptics.success();\n      if (!mounted) return;",
    "      await AppHaptics.success();\n      await AppAudio.instance.playMatchFromPrefs();\n      if (!mounted) return;",
)

# Listing published successfully: crystal confirmation cue.
replace_once(
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    "import 'package:flutter_swipes/src/core/constants/service_categories.dart';\n",
    "import 'package:flutter_swipes/src/core/constants/service_categories.dart';\nimport 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
)
replace_once(
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    "      ref.invalidate(ownerListingsStatsProvider);\n      state = const ListingDraft();\n      return true;",
    "      ref.invalidate(ownerListingsStatsProvider);\n      state = const ListingDraft();\n      await AppAudio.instance.playSuccessFromPrefs();\n      return true;",
)

# Profile save/finish: same crystal confirmation cue.
replace_once(
    'lib/src/features/profile/presentation/screens/edit_profile_screen.dart',
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\nimport 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
)
replace_once(
    'lib/src/features/profile/presentation/screens/edit_profile_screen.dart',
    "      ref.invalidate(currentProfileProvider);\n      ref.invalidate(mapProfilesProvider);\n      if (!mounted) return;",
    "      ref.invalidate(currentProfileProvider);\n      ref.invalidate(mapProfilesProvider);\n      await AppAudio.instance.playSuccessFromPrefs();\n      if (!mounted) return;",
)

# Direct Request/token purchase: premium metallic cue only after verified success.
replace_once(
    'lib/src/features/payments/presentation/widgets/tokens_modal.dart',
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\nimport 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
)
replace_once(
    'lib/src/features/payments/presentation/widgets/tokens_modal.dart',
    "    if (result.isSuccess) await AppHaptics.success();",
    "    if (result.isSuccess) {\n      await AppHaptics.success();\n      await AppAudio.instance.playTokensFromPrefs();\n    }",
)

# Premium upgrade purchase: same premium metallic identity.
replace_once(
    'lib/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart',
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\nimport 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
)
replace_once(
    'lib/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart',
    "    if (result.isSuccess) {\n      Navigator.of(context).push(",
    "    if (result.isSuccess) {\n      await AppAudio.instance.playTokensFromPrefs();\n      if (!mounted) return;\n      Navigator.of(context).push(",
)

# AI send + response completion: subtle two-point brain blip.
replace_once(
    'lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart',
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\n",
    "import 'package:flutter_swipes/src/core/utils/app_haptics.dart';\nimport 'package:flutter_swipes/src/core/services/app_audio.dart';\n",
)
replace_once(
    'lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart',
    "    AppHaptics.selection();\n    _controller.clear();",
    "    AppHaptics.selection();\n    unawaited(AppAudio.instance.playAiBlipFromPrefs());\n    _controller.clear();",
)
replace_once(
    'lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart',
    "    setState(() => _loading = false);\n    _scrollToEnd();",
    "    unawaited(AppAudio.instance.playAiBlipFromPrefs());\n    setState(() => _loading = false);\n    _scrollToEnd();",
)

print('Swipess audio hooks applied successfully.')
