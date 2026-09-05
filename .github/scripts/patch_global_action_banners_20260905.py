from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one anchor, found {count}')
    return text.replace(old, new, 1)


def patch(path: str, replacements: list[tuple[str, str, str]]) -> None:
    p = Path(path)
    text = p.read_text()
    for old, new, label in replacements:
        text = replace_once(text, old, new, f'{path}: {label}')
    p.write_text(text)


patch(
    'lib/src/features/add/presentation/screens/add_listing_screen.dart',
    [
        (
            "import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';\n",
            "import 'package:flutter_swipes/src/core/widgets/app_action_banner.dart';\n"
            "import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';\n",
            'banner import',
        ),
        (
            "    rootScaffoldMessengerKey.currentState?.showSnackBar(\n"
            "      const SnackBar(\n"
            "        content: Text('Listing published — it is live on the swipe deck.'),\n"
            "      ),\n"
            "    );\n"
            "    context.go(AppPaths.clientProfile);",
            "    AppActionBanner.success(\n"
            "      context,\n"
            "      title: 'Listing published',\n"
            "      detail: 'It is live on the swipe deck.',\n"
            "    );\n"
            "    context.go(AppPaths.clientProfile);",
            'manual listing published banner',
        ),
    ],
)

patch(
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    [
        (
            "import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';\n",
            "import 'package:flutter_swipes/src/core/widgets/app_action_banner.dart';\n"
            "import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';\n",
            'banner import',
        ),
        (
            "      await Future<void>.delayed(const Duration(milliseconds: 350));\n"
            "      if (!mounted) return;\n"
            "      context.go(AppPaths.clientProfile);",
            "      await Future<void>.delayed(const Duration(milliseconds: 350));\n"
            "      if (!mounted) return;\n"
            "      AppActionBanner.success(\n"
            "        context,\n"
            "        title: 'Listing published',\n"
            "        detail: 'Your listing is live now.',\n"
            "      );\n"
            "      context.go(AppPaths.clientProfile);",
            'ai listing published banner',
        ),
    ],
)

patch(
    'lib/src/features/add/presentation/screens/edit_listing_screen.dart',
    [
        (
            "import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';\n",
            "import 'package:flutter_swipes/src/core/widgets/app_action_banner.dart';\n"
            "import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';\n",
            'banner import',
        ),
        (
            "    if (ok) {\n"
            "      ScaffoldMessenger.of(context)\n"
            "          .showSnackBar(const SnackBar(content: Text('Listing updated')));\n"
            "      Navigator.of(context).pop(true);\n"
            "    }",
            "    if (ok) {\n"
            "      AppActionBanner.success(\n"
            "        context,\n"
            "        title: 'Listing updated',\n"
            "        detail: 'Your changes are live.',\n"
            "      );\n"
            "      Navigator.of(context).pop(true);\n"
            "    }",
            'edit listing success banner',
        ),
    ],
)

patch(
    'lib/src/features/profile/presentation/screens/edit_profile_screen.dart',
    [
        (
            "import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';\n",
            "import 'package:flutter_swipes/src/core/widgets/app_action_banner.dart';\n"
            "import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';\n",
            'banner import',
        ),
        (
            "      await AppAudio.instance.playSuccessFromPrefs();\n"
            "      if (!mounted) return;\n"
            "      if (Navigator.of(context).canPop()) {",
            "      await AppAudio.instance.playSuccessFromPrefs();\n"
            "      if (!mounted) return;\n"
            "      AppActionBanner.success(\n"
            "        context,\n"
            "        title: 'Profile updated',\n"
            "        detail: 'Your latest changes are saved.',\n"
            "      );\n"
            "      if (Navigator.of(context).canPop()) {",
            'profile save banner',
        ),
    ],
)

patch(
    'lib/src/features/camera/presentation/screens/profile_camera_screen.dart',
    [
        (
            "import 'package:flutter_swipes/src/core/theme/app_theme.dart';\n",
            "import 'package:flutter_swipes/src/core/theme/app_theme.dart';\n"
            "import 'package:flutter_swipes/src/core/widgets/app_action_banner.dart';\n",
            'banner import',
        ),
        (
            "      if (!mounted) return;\n"
            "      Navigator.pop(context, url);",
            "      if (!mounted) return;\n"
            "      AppActionBanner.success(\n"
            "        context,\n"
            "        title: 'Profile photo updated',\n"
            "        detail: 'Your new photo is saved.',\n"
            "      );\n"
            "      Navigator.pop(context, url);",
            'profile photo success banner',
        ),
    ],
)

print('Global action banners wired into create/update flows.')
