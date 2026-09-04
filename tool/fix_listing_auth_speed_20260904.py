from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))


# 1) Manual listing publish must stay on-screen until the listing is actually
# committed. Leaving the route before an awaited publish made a slow PWA media
# upload look broken and hid the real error/success state from the user.
replace_once(
    'lib/src/features/add/presentation/screens/add_listing_screen.dart',
    """    final router = GoRouter.of(context);\n    final rootNavigator = Navigator.of(context, rootNavigator: true);\n    if (rootNavigator.canPop()) {\n      rootNavigator.pop();\n    }\n    router.go(AppPaths.clientProfile);\n\n    unawaited(\n      notifier.publish().then((ok) {\n        rootScaffoldMessengerKey.currentState?.showSnackBar(\n          SnackBar(\n            content: Text(\n              ok\n                  ? 'Listing published — it is live on the swipe deck.'\n                  : (ref.read(addListingProvider).error ??\n                        'Could not save listing'),\n            ),\n          ),\n        );\n      }),\n    );\n""",
    """    final ok = await notifier.publish();\n    if (!mounted) return;\n\n    if (!ok) {\n      final message = ref.read(addListingProvider).error ??\n          'Could not save listing. Please review the fields and try again.';\n      rootScaffoldMessengerKey.currentState?.showSnackBar(\n        SnackBar(content: Text(message)),\n      );\n      return;\n    }\n\n    rootScaffoldMessengerKey.currentState?.showSnackBar(\n      const SnackBar(content: Text('Listing published — it is live on the swipe deck.')),\n    );\n    context.go(AppPaths.clientProfile);\n""",
)

# 2) Never permit duplicate publish taps while media is in flight.
replace_once(
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    """  Future<bool> publish() async {\n    final user = Supabase.instance.client.auth.currentUser;\n""",
    """  Future<bool> publish() async {\n    if (state.publishing) return false;\n    final user = Supabase.instance.client.auth.currentUser;\n""",
)

# 3) Keep listing photos visually sharp but much lighter for PWA/mobile upload.
# 1920px / 86 quality is still high-resolution for card/fullscreen display and
# substantially cuts upload + moderation latency compared with 2400px / 92.
for path in [
    'lib/src/features/add/presentation/providers/add_listing_provider.dart',
    'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
]:
    p = Path(path)
    text = p.read_text()
    text = text.replace('imageQuality: 92,\n        maxWidth: 2400,\n        maxHeight: 2400,',
                        'imageQuality: 86,\n        maxWidth: 1920,\n        maxHeight: 1920,')
    p.write_text(text)

# 4) Use a slightly wider but still bounded upload lane. Moderation remains
# mandatory; we are only reducing idle serialization between photo batches.
replace_once(
    'lib/src/features/swipes/data/repositories/listing_repository.dart',
    """    const parallelism = 4;\n""",
    """    const parallelism = 6;\n""",
)

# 5) Successful auth replaces the auth history entry. Also hard-guard the auth
# screen itself so a restored signed-in PWA session can never paint login/signup
# for a frame while GoRouter catches up.
replace_once(
    'lib/src/features/auth/presentation/screens/auth_screen.dart',
    """  bool _rememberMe = false;\n  bool _isLoading = false;\n""",
    """  bool _rememberMe = false;\n  bool _isLoading = false;\n  bool _redirectingSignedIn = false;\n""",
)
replace_once(
    'lib/src/features/auth/presentation/screens/auth_screen.dart',
    """  @override\n  void initState() {\n    super.initState();\n    _isLogin = widget.mode != 'signup';\n  }\n""",
    """  @override\n  void initState() {\n    super.initState();\n    _isLogin = widget.mode != 'signup';\n    WidgetsBinding.instance.addPostFrameCallback((_) => _leaveAuthIfSignedIn());\n  }\n\n  void _leaveAuthIfSignedIn() {\n    if (!mounted ||\n        _redirectingSignedIn ||\n        Supabase.instance.client.auth.currentSession == null) {\n      return;\n    }\n    _redirectingSignedIn = true;\n    FocusManager.instance.primaryFocus?.unfocus();\n    final pending = ref.read(pendingDeepLinkProvider).take();\n    GoRouter.of(context).replace(pending ?? AppPaths.clientDashboard);\n  }\n""",
)
replace_once(
    'lib/src/features/auth/presentation/screens/auth_screen.dart',
    """  void _finishSuccessfulAuth() {\n    if (!mounted) return;\n    FocusManager.instance.primaryFocus?.unfocus();\n    final pending = ref.read(pendingDeepLinkProvider).take();\n    context.go(pending ?? AppPaths.clientDashboard);\n  }\n""",
    """  void _finishSuccessfulAuth() {\n    if (!mounted) return;\n    FocusManager.instance.primaryFocus?.unfocus();\n    final pending = ref.read(pendingDeepLinkProvider).take();\n    GoRouter.of(context).replace(pending ?? AppPaths.clientDashboard);\n  }\n""",
)
replace_once(
    'lib/src/features/auth/presentation/screens/auth_screen.dart',
    """  @override\n  Widget build(BuildContext context) {\n    final confirmation =\n""",
    """  @override\n  Widget build(BuildContext context) {\n    if (Supabase.instance.client.auth.currentSession != null) {\n      WidgetsBinding.instance.addPostFrameCallback((_) => _leaveAuthIfSignedIn());\n      return const Scaffold(backgroundColor: Color(0xFF050505));\n    }\n\n    final confirmation =\n""",
)

print('listing/auth/speed patch applied')
