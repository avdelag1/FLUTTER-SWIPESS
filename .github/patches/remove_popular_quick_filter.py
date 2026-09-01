from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


# Dashboard: remove Popular badge/count logic and card; keep Recommended as the
# only aggregate quality destination.
p = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
s = p.read_text()
s = replace_once(
    s,
    """    final popLast = getLastAccessed('popular');
    counts['popular'] = listings.where((r) {
      final dt = DateTime.tryParse(r['created_at']?.toString() ?? '')?.toUtc();
      return dt != null && dt.isAfter(popLast);
    }).length;

""",
    "",
    'popular badge count',
)
s = replace_once(
    s,
    """  _BentoItemData(
    index: 4,
    id: 'popular',
    title: 'POPULAR',
    subtitle: 'Trending now',
    height: 300,
    delaySeconds: '16',
  ),
""",
    "",
    'popular dashboard card',
)
s = s.replace(
    "title: 'RECOMMENDED FOR YOU',\n    subtitle: 'Curated listings',",
    "title: 'RECOMMENDED FOR YOU',\n    subtitle: 'Best listings, workers & local finds',",
    1,
)
p.write_text(s)


# Remove unused Popular editorial preview pool.
p = Path('lib/src/features/dashboard/domain/bento_media_pools.dart')
s = p.read_text()
s = replace_once(
    s,
    """      case 'popular':
        return const [
          AppAssets.filterBuyers,
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1449844908441-8829872d2607?auto=format&fit=crop&w=1000&q=92',
        ];
""",
    "",
    'popular media pool',
)
p.write_text(s)


# Stop warming/fetching a dashboard destination that no longer exists.
p = Path('lib/src/features/swipes/presentation/providers/swipe_providers.dart')
s = p.read_text()
s = s.replace(
    '/// feature matrix. Recommended/Popular remain aggregate modes instead of being\n/// silently rewritten to the filter category.',
    '/// feature matrix. Recommended remains an aggregate quality mode instead of\n/// being silently rewritten to the filter category.',
    1,
)
s = replace_once(
    s,
    "      ref.read(swipeListingsProvider('recommended').future),\n      ref.read(swipeListingsProvider('popular').future),",
    "      ref.read(swipeListingsProvider('recommended').future),",
    'popular signed-in warmup',
)
p.write_text(s)

p = Path('lib/src/core/performance/app_performance_bootstrap.dart')
s = p.read_text()
s = replace_once(
    s,
    "      _safe(() => container.read(swipeListingsProvider('recommended').future)),\n      _safe(() => container.read(swipeListingsProvider('popular').future)),",
    "      _safe(() => container.read(swipeListingsProvider('recommended').future)),",
    'popular performance warmup',
)
p.write_text(s)


checks = {
    'no dashboard popular': "id: 'popular'" not in Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart').read_text(),
    'recommended remains': "id: 'recommended'" in Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart').read_text(),
    'no popular warmup': "swipeListingsProvider('popular')" not in Path('lib/src/features/swipes/presentation/providers/swipe_providers.dart').read_text(),
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('popular-removal checks failed: ' + ', '.join(failed))
print('Popular quick filter removed; Recommended retained.')
