from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'missing expected block in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))


# The browser console showed Riverpod's explicit "Using ref when a widget is
# about to or has been unmounted is unsafe" exception. DashboardShell was doing
# exactly that in dispose(), and also had an unguarded post-frame ref read.
# Root engagement bootstrap had the same dispose antipattern.

replace_once(
    'lib/src/features/dashboard/presentation/screens/dashboard_shell.dart',
    """  @override\n  void initState() {\n    super.initState();\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      ref.read(sessionGamificationProvider).startTracking(context);\n    });\n  }\n\n  @override\n  void dispose() {\n    _dashboardSearchController.dispose();\n    ref.read(chromeVisibilityProvider.notifier).suppressExplicitHide(false);\n    ref.read(sessionGamificationProvider).stopTracking();\n    super.dispose();\n  }\n""",
    """  @override\n  void initState() {\n    super.initState();\n    // App-wide engagement tracking is already owned by\n    // _EngagementTrackingBootstrap. DashboardShell must not register a second\n    // client and then touch Riverpod ref while it is being disposed.\n  }\n\n  @override\n  void dispose() {\n    _dashboardSearchController.dispose();\n    super.dispose();\n  }\n""",
)

replace_once(
    'lib/src/features/dashboard/presentation/screens/dashboard_shell.dart',
    """    if (routeTab != null && ref.read(navTabProvider) != routeTab) {\n      WidgetsBinding.instance.addPostFrameCallback((_) {\n        if (ref.read(navTabProvider) != routeTab) {\n          ref.read(navTabProvider.notifier).set(routeTab);\n        }\n      });\n    }\n""",
    """    if (routeTab != null && ref.read(navTabProvider) != routeTab) {\n      WidgetsBinding.instance.addPostFrameCallback((_) {\n        if (!mounted) return;\n        if (ref.read(navTabProvider) != routeTab) {\n          ref.read(navTabProvider.notifier).set(routeTab);\n        }\n      });\n    }\n""",
)

replace_once(
    'lib/src/app.dart',
    """class _EngagementTrackingBootstrapState\n    extends ConsumerState<_EngagementTrackingBootstrap> {\n  @override\n  void initState() {\n    super.initState();\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      if (!mounted) return;\n      ref.read(sessionGamificationProvider).startTracking(context);\n    });\n  }\n\n  @override\n  void dispose() {\n    ref.read(sessionGamificationProvider).stopTracking();\n    super.dispose();\n  }\n""",
    """class _EngagementTrackingBootstrapState\n    extends ConsumerState<_EngagementTrackingBootstrap> {\n  late final SessionGamificationService _sessionGamification;\n  bool _trackingStarted = false;\n\n  @override\n  void initState() {\n    super.initState();\n    // Cache provider-backed services while the ConsumerState is mounted.\n    // Riverpod deliberately rejects ref access during State.dispose().\n    _sessionGamification = ref.read(sessionGamificationProvider);\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      if (!mounted) return;\n      _sessionGamification.startTracking(context);\n      _trackingStarted = true;\n    });\n  }\n\n  @override\n  void dispose() {\n    if (_trackingStarted) _sessionGamification.stopTracking();\n    super.dispose();\n  }\n""",
)

print('patched Riverpod lifecycle safety')
