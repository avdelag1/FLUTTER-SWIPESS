from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f"missing pattern: {label} in {path}")
    p.write_text(s.replace(old, new, 1))


# Studio must reopen portrait-first even when an older saved project persisted FIT.
path = "lib/src/features/studio/presentation/screens/studio_composer_screen.dart"
p = Path(path)
s = p.read_text()
old = """    _photoFits = <int, StudioPhotoFit>{
      for (var i = 0; i < _photos.length; i++)
        i: initial?.photoFits[i] ?? StudioPhotoFit.portrait,
    };
"""
new = """    // Always enter Studio portrait-first, including projects created before
    // portrait framing existed. This prevents stale saved FIT values from
    // resurrecting landscape/letterboxed cards. FIT remains available as an
    // explicit per-photo choice after Studio opens.
    _photoFits = <int, StudioPhotoFit>{
      for (var i = 0; i < _photos.length; i++) i: StudioPhotoFit.portrait,
    };
"""
if old not in s:
    if "for (var i = 0; i < _photos.length; i++) i: StudioPhotoFit.portrait" not in s:
        raise SystemExit("missing Studio photoFits initialization")
else:
    p.write_text(s.replace(old, new, 1))


# Home while already on Dashboard must visibly run the same RefreshIndicator
# callback used by pull-to-refresh.
path = "lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart"
p = Path(path)
s = p.read_text()
old = """class _BentoDashboardScreenState extends ConsumerState<BentoDashboardScreen> {
  final _aiSearchController = TextEditingController();
  final _scroll = ScrollController();
"""
new = """class _BentoDashboardScreenState extends ConsumerState<BentoDashboardScreen> {
  final _aiSearchController = TextEditingController();
  final _scroll = ScrollController();
  final GlobalKey<RefreshIndicatorState> _dashboardRefreshKey =
      GlobalKey<RefreshIndicatorState>();
"""
if "_dashboardRefreshKey" not in s:
    if old not in s:
        raise SystemExit("missing Bento state fields pattern")
    s = s.replace(old, new, 1)

old = """        AppRefreshService.refreshDashboard(ref);
        AppHaptics.light();
      }
    });
"""
new = """        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final indicator = _dashboardRefreshKey.currentState;
          if (indicator != null) {
            // show() invokes the RefreshIndicator onRefresh callback, giving
            // Home the same visible live reload as a manual pull-to-refresh.
            indicator.show();
          } else {
            AppRefreshService.refreshDashboard(ref);
            AppHaptics.light();
          }
        });
      }
    });
"""
if "indicator.show();" not in s:
    if old not in s:
        raise SystemExit("missing Home tap refresh pattern")
    s = s.replace(old, new, 1)

old = """        child: RefreshIndicator.adaptive(
          color: AppTheme.brandAccent2,
"""
new = """        child: RefreshIndicator.adaptive(
          key: _dashboardRefreshKey,
          color: AppTheme.brandAccent2,
"""
if "key: _dashboardRefreshKey" not in s:
    if old not in s:
        raise SystemExit("missing RefreshIndicator pattern")
    s = s.replace(old, new, 1)
p.write_text(s)


# Listing-photo surfaces already use cover; make centered portrait fill explicit
# wherever an image renderer omitted alignment. Originals remain untouched/HQ.
for path in [
    "lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart",
    "lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart",
    "lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart",
]:
    p = Path(path)
    s = p.read_text()
    s = s.replace(
        "fit: BoxFit.cover,\n          width: double.infinity,",
        "fit: BoxFit.cover,\n          alignment: Alignment.center,\n          width: double.infinity,",
    )
    s = s.replace(
        "fit: BoxFit.cover,\n      width: double.infinity,",
        "fit: BoxFit.cover,\n      alignment: Alignment.center,\n      width: double.infinity,",
    )
    s = s.replace(
        "fit: BoxFit.cover,\n                width: double.infinity,",
        "fit: BoxFit.cover,\n                alignment: Alignment.center,\n                width: double.infinity,",
    )
    p.write_text(s)


studio = Path("lib/src/features/studio/presentation/screens/studio_composer_screen.dart").read_text()
bento = Path("lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart").read_text()
assert "i: StudioPhotoFit.portrait" in studio
assert "_dashboardRefreshKey" in bento
assert "indicator.show();" in bento
assert "key: _dashboardRefreshKey" in bento
print("portrait + visible Home refresh contracts OK")
