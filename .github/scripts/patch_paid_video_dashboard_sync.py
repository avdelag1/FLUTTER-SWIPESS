from pathlib import Path


def load(path: str) -> str:
    return Path(path).read_text()


def save(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(path: str, old: str, new: str) -> None:
    text = load(path)
    if old not in text:
        raise SystemExit(f'missing patch anchor in {path}: {old[:100]!r}')
    save(path, text.replace(old, new, 1))


def replace_all_exact(path: str, old: str, new: str, expected: int) -> None:
    text = load(path)
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected} occurrences, found {count}: {old!r}')
    save(path, text.replace(old, new))


# ---------------------------------------------------------------------------
# Paid Premium listing-video entitlement in Flutter.
# ---------------------------------------------------------------------------
subscription_provider = 'lib/src/features/subscriptions/presentation/providers/subscription_provider.dart'
replace_once(
    subscription_provider,
    "import 'package:flutter_swipes/src/features/subscriptions/data/subscription_repository.dart';\n",
    "import 'package:flutter_swipes/src/features/subscriptions/data/subscription_repository.dart';\n"
    "import 'package:supabase_flutter/supabase_flutter.dart';\n",
)
replace_once(
    subscription_provider,
    "final subscriptionProvider =\n    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionData>(() {\n      return SubscriptionNotifier();\n    });\n\n",
    "final subscriptionProvider =\n    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionData>(() {\n      return SubscriptionNotifier();\n    });\n\n"
    "/// Listing video is intentionally stricter than the 3-month Freemium\n"
    "/// feature preview: only a currently paid plan can add/replace a video.\n"
    "/// The server RPC is authoritative; the subscription value is only a\n"
    "/// fast UI fallback while that small entitlement request is resolving.\n"
    "final paidListingVideoAccessProvider = FutureProvider<bool>((ref) async {\n"
    "  final user = ref.watch(currentUserProvider);\n"
    "  if (user == null) return false;\n"
    "  final fallback = ref.watch(subscriptionProvider).value?.isPaidActive == true;\n"
    "  try {\n"
    "    final allowed = await Supabase.instance.client.rpc(\n"
    "      'rpc_can_upload_listing_video',\n"
    "    );\n"
    "    if (allowed is bool) return allowed;\n"
    "  } catch (_) {}\n"
    "  return fallback;\n"
    "});\n\n",
)

# Make the benefit explicit on every paid plan card.
iap = 'lib/src/features/payments/domain/iap_catalog.dart'
replace_all_exact(
    iap,
    "        'Events discovery & access',\n",
    "        'Events discovery & access',\n"
    "        'Premium listing video + dashboard Quick Filter exposure',\n",
    3,
)

packages = 'lib/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart'
replace_once(
    packages,
    "                    'No confusing trial math. Your welcome window counts down for 3 months and gives you the full Premium feature experience.',\n",
    "                    'No confusing trial math. Your welcome window counts down for 3 months and previews AI, Legal, Events and core Premium features. Listing video promotion unlocks only with a paid Premium package.',\n",
)
replace_once(packages, "                label: 'FULL PREMIUM',\n", "                label: 'PREMIUM PREVIEW',\n")
replace_once(
    packages,
    "            'SAME FEATURE ACCESS AS YEARLY / UNLIMITED',\n",
    "            'FREEMIUM FEATURE ACCESS',\n",
)
replace_once(
    packages,
    "                  _DiscoveryBoostSection(),\n                  const SizedBox(height: 6),\n                  _InfoCard(\n                    title: 'WHAT STAYS FREE FOREVER',\n",
    "                  _DiscoveryBoostSection(),\n"
    "                  const SizedBox(height: 6),\n"
    "                  _InfoCard(\n"
    "                    title: 'PAID PREMIUM VIDEO BOOST',\n"
    "                    text: 'Paid Premium members can upload one high-quality portrait 9:16 video per listing. Video listings are eligible to play directly inside their matching dashboard Quick Filter for extra exposure.',\n"
    "                  ),\n"
    "                  const SizedBox(height: 10),\n"
    "                  _InfoCard(\n"
    "                    title: 'WHAT STAYS FREE FOREVER',\n",
)
replace_once(
    packages,
    "                    text: 'AI, AI Listing Creator, Legal, Events, Premium listing capacity/visibility and other Premium advantages lock until you choose a Premium package.',\n",
    "                    text: 'AI, AI Listing Creator, Legal, Events, Premium listing capacity/visibility and other Premium advantages lock until you choose a Premium package. Listing video upload and dashboard Quick Filter video exposure always require a paid package.',\n",
)

# Manual listing media: premium lock + portrait guidance.
manual = 'lib/src/features/add/presentation/screens/add_listing_screen.dart'
replace_once(
    manual,
    "import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';\n",
    "import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';\n"
    "import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';\n",
)
manual_text = load(manual)
photos_class = manual_text.index('class _PhotosStep extends ConsumerWidget')
build_anchor = "  @override\n  Widget build(BuildContext context, WidgetRef ref) {\n    return Column("
build_pos = manual_text.index(build_anchor, photos_class)
manual_text = (
    manual_text[:build_pos]
    + build_anchor.replace(
        "    return Column(",
        "    final videoAccess = ref.watch(paidListingVideoAccessProvider);\n"
        "    final subscription = ref.watch(subscriptionProvider).value;\n"
        "    final canUploadVideo =\n"
        "        videoAccess.value ?? subscription?.isPaidActive == true;\n\n"
        "    void openPremiumVideo() {\n"
        "      AppHaptics.medium();\n"
        "      ScaffoldMessenger.of(context).showSnackBar(\n"
        "        const SnackBar(\n"
        "          content: Text(\n"
        "            'Listing video + dashboard Quick Filter exposure is a paid Premium benefit.',\n"
        "          ),\n"
        "        ),\n"
        "      );\n"
        "      context.push(AppPaths.subscriptionPackages);\n"
        "    }\n\n"
        "    return Column(",
    )
    + manual_text[build_pos + len(build_anchor):]
)
save(manual, manual_text)
replace_once(
    manual,
    "                icon: draft.video == null\n                    ? Icons.video_call_rounded\n                    : Icons.edit_rounded,\n                title: draft.video == null ? 'Video' : 'Edit video',\n                subtitle: '1 video · trim 5s to 60s',\n                onTap: () => draft.video == null\n                    ? _pickVideo(context, ref)\n                    : _editVideo(context, ref),\n",
    "                icon: !canUploadVideo\n"
    "                    ? Icons.lock_rounded\n"
    "                    : draft.video == null\n"
    "                    ? Icons.video_call_rounded\n"
    "                    : Icons.edit_rounded,\n"
    "                title: !canUploadVideo\n"
    "                    ? 'Premium video'\n"
    "                    : draft.video == null\n"
    "                    ? 'Video'\n"
    "                    : 'Edit video',\n"
    "                subtitle: canUploadVideo\n"
    "                    ? 'Portrait 9:16 · high quality · 5s to 60s'\n"
    "                    : 'Paid Premium · dashboard Quick Filter exposure',\n"
    "                onTap: () {\n"
    "                  if (!canUploadVideo) {\n"
    "                    openPremiumVideo();\n"
    "                    return;\n"
    "                  }\n"
    "                  if (draft.video == null) {\n"
    "                    _pickVideo(context, ref);\n"
    "                  } else {\n"
    "                    _editVideo(context, ref);\n"
    "                  }\n"
    "                },\n",
)
replace_once(
    manual,
    "        const SizedBox(height: 6),\n        TextButton.icon(\n",
    "        const SizedBox(height: 7),\n"
    "        Text(\n"
    "          'Video tip: shoot/upload portrait 9:16 in high quality (1080×1920 preferred) so it fills the dashboard card.',\n"
    "          style: GoogleFonts.plusJakartaSans(\n"
    "            color: Colors.white54,\n"
    "            fontSize: 9.5,\n"
    "            height: 1.35,\n"
    "            fontWeight: FontWeight.w600,\n"
    "          ),\n"
    "        ),\n"
    "        const SizedBox(height: 4),\n"
    "        TextButton.icon(\n",
)

# Fail before large uploads if a non-paid draft somehow still contains a video.
add_provider = 'lib/src/features/add/presentation/providers/add_listing_provider.dart'
replace_once(
    add_provider,
    "    } catch (error) {\n      // Fail open here: the database guardrail still enforces the real limit.\n      debugPrint('[AddListing] quota preflight fallback: $error');\n    }\n\n    var coords = ListingLocations.resolve(state.city);\n",
    "    } catch (error) {\n"
    "      // Fail open here: the database guardrail still enforces the real limit.\n"
    "      debugPrint('[AddListing] quota preflight fallback: $error');\n"
    "    }\n\n"
    "    if (state.video != null) {\n"
    "      try {\n"
    "        final allowed = await Supabase.instance.client.rpc(\n"
    "          'rpc_can_upload_listing_video',\n"
    "        );\n"
    "        if (allowed != true) {\n"
    "          state = state.copyWith(\n"
    "            error:\n"
    "                'Listing video + dashboard Quick Filter exposure is a paid Premium benefit. Upgrade or remove the video to publish.',\n"
    "          );\n"
    "          return false;\n"
    "        }\n"
    "      } catch (error) {\n"
    "        debugPrint('[AddListing] video entitlement check failed: $error');\n"
    "        state = state.copyWith(\n"
    "          error: 'Could not verify Premium video access. Please retry.',\n"
    "        );\n"
    "        return false;\n"
    "      }\n"
    "    }\n\n"
    "    var coords = ListingLocations.resolve(state.city);\n",
)

# AI listing flow: same paid lock and same portrait recommendation.
ai = 'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart'
replace_once(
    ai,
    "import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';\n",
    "import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';\n"
    "import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';\n",
)
replace_once(
    ai,
    "  Future<void> _pickVideo() async {\n    if (_busy) return;\n    final picker = ImagePicker();\n",
    "  Future<bool> _ensurePaidVideoAccess() async {\n"
    "    var allowed = ref.read(paidListingVideoAccessProvider).value ??\n"
    "        ref.read(subscriptionProvider).value?.isPaidActive == true;\n"
    "    if (!allowed) {\n"
    "      try {\n"
    "        allowed = await ref.read(paidListingVideoAccessProvider.future);\n"
    "      } catch (_) {}\n"
    "    }\n"
    "    if (!allowed && mounted) {\n"
    "      _showMessage(\n"
    "        'Video upload + dashboard Quick Filter exposure is a paid Premium benefit.',\n"
    "      );\n"
    "      context.push(AppPaths.subscriptionPackages);\n"
    "    }\n"
    "    return allowed;\n"
    "  }\n\n"
    "  Future<void> _pickVideo() async {\n"
    "    if (_busy || !await _ensurePaidVideoAccess()) return;\n"
    "    final picker = ImagePicker();\n",
)
replace_once(
    ai,
    "  Future<void> _editVideo() async {\n    final file = _video;\n    if (_busy || file == null) return;\n",
    "  Future<void> _editVideo() async {\n"
    "    final file = _video;\n"
    "    if (_busy || file == null || !await _ensurePaidVideoAccess()) return;\n",
)
replace_once(
    ai,
    "        if (_video != null) ...[\n",
    "        const SizedBox(height: 7),\n"
    "        Text(\n"
    "          'For dashboard cards, use a sharp portrait 9:16 video (1080×1920 preferred).',\n"
    "          style: GoogleFonts.plusJakartaSans(\n"
    "            color: const Color(0xFF8F8F98),\n"
    "            fontSize: 9.5,\n"
    "            height: 1.35,\n"
    "            fontWeight: FontWeight.w600,\n"
    "          ),\n"
    "        ),\n"
    "        if (_video != null) ...[\n",
)
replace_once(
    ai,
    "  Widget _buildVideoPanel() {\n    if (_video == null) {\n      return _mediaActionButton(\n        icon: Icons.video_call_rounded,\n        label: 'ADD VIDEO',\n        sublabel: 'Trim 5s to 60s',\n        onTap: _pickVideo,\n      );\n    }\n",
    "  Widget _buildVideoPanel() {\n"
    "    final videoAccess = ref.watch(paidListingVideoAccessProvider);\n"
    "    final subscription = ref.watch(subscriptionProvider).value;\n"
    "    final canUploadVideo =\n"
    "        videoAccess.value ?? subscription?.isPaidActive == true;\n"
    "    if (_video == null) {\n"
    "      return _mediaActionButton(\n"
    "        icon: canUploadVideo ? Icons.video_call_rounded : Icons.lock_rounded,\n"
    "        label: canUploadVideo ? 'ADD VIDEO' : 'PREMIUM VIDEO',\n"
    "        sublabel: canUploadVideo\n"
    "            ? 'Portrait 9:16 · high quality · 5s to 60s'\n"
    "            : 'Paid Premium · Quick Filter exposure',\n"
    "        onTap: canUploadVideo\n"
    "            ? _pickVideo\n"
    "            : () => unawaited(_ensurePaidVideoAccess()),\n"
    "      );\n"
    "    }\n",
)

# Editing an existing listing can keep its old video, but a replacement is paid.
edit_provider = 'lib/src/features/add/presentation/providers/edit_listing_provider.dart'
replace_once(
    edit_provider,
    "  Future<void> pickVideo() async {\n    final current = state;\n    if (current == null) return;\n    final picked = await ImagePicker().pickVideo(\n",
    "  Future<void> pickVideo() async {\n"
    "    final current = state;\n"
    "    if (current == null) return;\n"
    "    try {\n"
    "      final allowed = await Supabase.instance.client.rpc(\n"
    "        'rpc_can_upload_listing_video',\n"
    "      );\n"
    "      if (allowed != true) {\n"
    "        state = current.copyWith(\n"
    "          error:\n"
    "              'Replacing or adding a listing video is a paid Premium benefit.',\n"
    "        );\n"
    "        return;\n"
    "      }\n"
    "    } catch (_) {\n"
    "      state = current.copyWith(\n"
    "        error: 'Could not verify Premium video access. Please retry.',\n"
    "      );\n"
    "      return;\n"
    "    }\n"
    "    final picked = await ImagePicker().pickVideo(\n",
)

# ---------------------------------------------------------------------------
# Dashboard: remove Recommended, put real sections in the requested order.
# ---------------------------------------------------------------------------
dashboard = 'lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart'
replace_once(
    dashboard,
    "  const categoryMap = {\n    'property': 'property',\n    'services': 'services',\n    'yacht': 'yacht',\n    'dining': 'dining',\n    'motos': 'motorcycles',\n    'jets': 'jets',\n    'people': 'people',\n  };\n",
    "  const categoryMap = {\n"
    "    'property': 'property',\n"
    "    'services': 'worker',\n"
    "    'yacht': 'yacht',\n"
    "    'motorcycle': 'motorcycle',\n"
    "    'bicycle': 'bicycle',\n"
    "    'buyers': 'property',\n"
    "    'renters': 'property',\n"
    "  };\n",
)
# Delete Recommended badge counting.
d_text = load(dashboard)
rec_start = d_text.find("    final recLast = getLastAccessed('recommended');")
if rec_start != -1:
    rec_end = d_text.find("\n\n    try {\n      final eventRows", rec_start)
    if rec_end == -1:
        raise SystemExit('recommended count end anchor missing')
    d_text = d_text[:rec_start] + "    try {\n      final eventRows" + d_text[rec_end + len("\n\n    try {\n      final eventRows"):]
    save(dashboard, d_text)

replace_once(
    dashboard,
    "      case 'events':\n        openEventsFeed(context, ref: ref);\n        return;\n      case 'seekers':\n",
    "      case 'events':\n"
    "        openEventsFeed(context, ref: ref);\n"
    "        return;\n"
    "      case 'buyers':\n"
    "        ref.read(swipeFilterProvider.notifier).replace(\n"
    "          SwipeFilter(category: 'property', interestType: 'sale'),\n"
    "        );\n"
    "        openClientSwipeDeck(\n"
    "          context,\n"
    "          categoryId: 'property',\n"
    "          categoryTitle: 'BUYERS',\n"
    "        );\n"
    "        return;\n"
    "      case 'renters':\n"
    "        ref.read(swipeFilterProvider.notifier).replace(\n"
    "          SwipeFilter(category: 'property', interestType: 'rent'),\n"
    "        );\n"
    "        openClientSwipeDeck(\n"
    "          context,\n"
    "          categoryId: 'property',\n"
    "          categoryTitle: 'RENTERS',\n"
    "        );\n"
    "        return;\n"
    "      case 'jets':\n"
    "        context.go(AppPaths.map);\n"
    "        return;\n"
    "      case 'seekers':\n",
)
replace_once(
    dashboard,
    "    const listingVideoQuickFilters = <String>{\n      'property',\n      'recommended',\n      'services',\n",
    "    const listingVideoQuickFilters = <String>{\n      'property',\n      'services',\n",
)
replace_once(
    dashboard,
    "  'events' => 'events',\n  'seekers' => 'seekers',\n",
    "  'events' => 'events',\n"
    "  'buyers' => 'properties',\n"
    "  'renters' => 'properties',\n"
    "  'seekers' => 'seekers',\n",
)
# Replace the full bento catalog.
d_text = load(dashboard)
items_start = d_text.index('const _bentoItems = [')
items_end = d_text.index('\n];', items_start) + len('\n];')
new_items = """const _bentoItems = [
  _BentoItemData(
    index: 0,
    id: 'events',
    title: 'EVENTS LIVE',
    subtitle: 'Swipe event videos · tap to open',
    height: 360,
    delaySeconds: '0',
  ),
  _BentoItemData(
    index: 1,
    id: 'property',
    title: 'PROPERTIES',
    subtitle: 'Listings to buy or rent',
    height: 360,
    delaySeconds: '4',
  ),
  _BentoItemData(
    index: 2,
    id: 'jets',
    title: 'JETS',
    subtitle: 'Private aviation on the live map',
    height: 300,
    delaySeconds: '8',
  ),
  _BentoItemData(
    index: 3,
    id: 'motorcycle',
    title: 'MOTORCYCLES',
    subtitle: 'Motorcycles for sale or rent',
    height: 300,
    delaySeconds: '12',
  ),
  _BentoItemData(
    index: 4,
    id: 'bicycle',
    title: 'BICYCLES',
    subtitle: 'Bicycles and e-bikes',
    height: 300,
    delaySeconds: '16',
  ),
  _BentoItemData(
    index: 5,
    id: 'buyers',
    title: 'BUYERS',
    subtitle: 'Property listings ready to buy',
    height: 300,
    delaySeconds: '20',
  ),
  _BentoItemData(
    index: 6,
    id: 'renters',
    title: 'RENTERS',
    subtitle: 'Property listings ready to rent',
    height: 300,
    delaySeconds: '24',
  ),
  _BentoItemData(
    index: 7,
    id: 'seekers',
    title: 'SEEKERS',
    subtitle: 'People looking for help & connections',
    height: 300,
    delaySeconds: '28',
  ),
  _BentoItemData(
    index: 8,
    id: 'services',
    title: 'WORKERS',
    subtitle: 'Find people offering services',
    height: 360,
    delaySeconds: '32',
  ),
  _BentoItemData(
    index: 9,
    id: 'yacht',
    title: 'YACHTS',
    subtitle: 'Yachts & boats to charter or buy',
    height: 360,
    delaySeconds: '36',
  ),
  _BentoItemData(
    index: 10,
    id: 'legal',
    title: 'LEGAL SERVICES',
    subtitle: 'Hire a top tier lawyer',
    height: 300,
    delaySeconds: '40',
  ),
  _BentoItemData(
    index: 11,
    id: 'premium',
    title: 'PREMIUM',
    subtitle: 'Video promotion, AI, Legal & more',
    height: 300,
    delaySeconds: '44',
  ),
];"""
save(dashboard, d_text[:items_start] + new_items + d_text[items_end:])

# Media pools for new dashboard cards; Recommended is gone.
pools = 'lib/src/features/dashboard/domain/bento_media_pools.dart'
p_text = load(pools)
old_rec = """      case 'recommended':
        return const [
          AppAssets.filterRenters,
          'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1000&q=92',
        ];
"""
if old_rec not in p_text:
    raise SystemExit('recommended media pool anchor missing')
p_text = p_text.replace(
    old_rec,
    """      case 'jets':
        return const [
          'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=1000&q=92',
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1000&q=92',
        ];
      case 'buyers':
        return const [
          AppAssets.filterBuyers,
          AppAssets.filterProperty,
        ];
      case 'renters':
        return const [
          AppAssets.filterRenters,
          AppAssets.filterPropertyJungle,
        ];
""",
    1,
)
save(pools, p_text)

# Stop prewarming the removed Recommended destination.
swipe_providers = 'lib/src/features/swipes/presentation/providers/swipe_providers.dart'
replace_once(
    swipe_providers,
    "      ref.read(swipeListingsProvider('bicycle').future),\n      ref.read(swipeListingsProvider('recommended').future),\n",
    "      ref.read(swipeListingsProvider('bicycle').future),\n",
)

# ---------------------------------------------------------------------------
# Video quick filters always visually cover the portrait card, even on web.
# ---------------------------------------------------------------------------
quick_media = 'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart'
replace_once(
    quick_media,
    "        return FittedBox(\n          fit: BoxFit.cover,\n          clipBehavior: Clip.hardEdge,\n          child: SizedBox(\n            width: player.value.size.width,\n            height: player.value.size.height,\n            child: VideoPlayer(player),\n          ),\n        );\n",
    "        return LayoutBuilder(\n"
    "          builder: (context, constraints) {\n"
    "            final size = player.value.size;\n"
    "            if (size.width <= 0 || size.height <= 0) {\n"
    "              return const ColoredBox(color: Color(0xFF15171C));\n"
    "            }\n"
    "            final scale = math.max(\n"
    "              constraints.maxWidth / size.width,\n"
    "              constraints.maxHeight / size.height,\n"
    "            );\n"
    "            return ClipRect(\n"
    "              child: Center(\n"
    "                child: SizedBox(\n"
    "                  width: size.width * scale,\n"
    "                  height: size.height * scale,\n"
    "                  child: VideoPlayer(player),\n"
    "                ),\n"
    "              ),\n"
    "            );\n"
    "          },\n"
    "        );\n",
)

# ---------------------------------------------------------------------------
# Events/data sync: session-scoped cache + silent refresh whenever app resumes.
# ---------------------------------------------------------------------------
events = 'lib/src/features/events/presentation/providers/events_provider.dart'
replace_once(
    events,
    "final eventRepositoryProvider = Provider<EventRepository>((ref) {\n  return EventRepository();\n});\n",
    "final eventRepositoryProvider = Provider<EventRepository>((ref) {\n"
    "  // A repository owns an in-flight/cached Events request. Scope that cache\n"
    "  // to the current account so a new login can never inherit an empty or\n"
    "  // stale response from the previous/anonymous session.\n"
    "  ref.watch(currentUserProvider.select((user) => user?.id));\n"
    "  return EventRepository();\n"
    "});\n",
)
replace_once(
    events,
    "final dashboardVideoEventsProvider = FutureProvider<List<Event>>((ref) {\n  return ref.read(eventRepositoryProvider).fetchDashboardVideoTeasers(limit: 8);\n});\n",
    "final dashboardVideoEventsProvider = FutureProvider<List<Event>>((ref) {\n"
    "  ref.watch(currentUserProvider.select((user) => user?.id));\n"
    "  return ref.read(eventRepositoryProvider).fetchDashboardVideoTeasers(limit: 8);\n"
    "});\n",
)

refresh = 'lib/src/core/performance/app_refresh_service.dart'
replace_once(
    refresh,
    "  static Future<void> refreshDashboardContainer(\n    ProviderContainer container,\n  ) async {\n    AppHaptics.selection();\n",
    "  static Future<void> refreshDashboardContainer(\n"
    "    ProviderContainer container, {\n"
    "    bool haptic = true,\n"
    "  }) async {\n"
    "    if (haptic) AppHaptics.selection();\n",
)
replace_once(
    refresh,
    "  static Future<void> refreshAll(WidgetRef ref) => refreshDashboard(ref);\n",
    "  static Future<void> refreshDashboardSilently(WidgetRef ref) async {\n"
    "    final context = ref.context;\n"
    "    if (!context.mounted) return;\n"
    "    await refreshDashboardContainer(\n"
    "      ProviderScope.containerOf(context, listen: false),\n"
    "      haptic: false,\n"
    "    );\n"
    "  }\n\n"
    "  static Future<void> refreshAll(WidgetRef ref) => refreshDashboard(ref);\n",
)

lifecycle = 'lib/src/core/native/app_lifecycle_service.dart'
replace_once(lifecycle, "import 'package:flutter/widgets.dart';\n", "import 'dart:async';\n\nimport 'package:flutter/widgets.dart';\n")
replace_once(
    lifecycle,
    "import 'package:flutter_swipes/src/core/native/local_notifications_service.dart';\n",
    "import 'package:flutter_swipes/src/core/native/local_notifications_service.dart';\n"
    "import 'package:flutter_swipes/src/core/performance/app_refresh_service.dart';\n",
)
replace_once(
    lifecycle,
    "class _AppLifecycleWatcherState extends ConsumerState<AppLifecycleWatcher>\n    with WidgetsBindingObserver {\n",
    "class _AppLifecycleWatcherState extends ConsumerState<AppLifecycleWatcher>\n"
    "    with WidgetsBindingObserver {\n"
    "  DateTime? _lastContentRefresh;\n\n"
    "  void _refreshContentIfStale() {\n"
    "    final now = DateTime.now();\n"
    "    final previous = _lastContentRefresh;\n"
    "    if (previous != null && now.difference(previous) < const Duration(seconds: 20)) {\n"
    "      return;\n"
    "    }\n"
    "    _lastContentRefresh = now;\n"
    "    unawaited(AppRefreshService.refreshDashboardSilently(ref));\n"
    "  }\n",
)
replace_once(
    lifecycle,
    "        _refreshGps(force: false);\n",
    "        _refreshGps(force: false);\n        _refreshContentIfStale();\n",
)
replace_once(
    lifecycle,
    "      } else {\n        _refreshGps(force: true);\n      }\n",
    "      } else {\n"
    "        _refreshGps(force: true);\n"
    "        _lastContentRefresh = null;\n"
    "        _refreshContentIfStale();\n"
    "      }\n",
)

# Tests follow the new product contract.
dash_test = 'test/dashboard_parity_test.dart'
replace_once(
    dash_test,
    "    expect(find.text('WORKERS'), findsWidgets);\n    expect(find.text('RECOMMENDED FOR YOU'), findsWidgets);\n",
    "    expect(find.text('MOTORCYCLES'), findsWidgets);\n"
    "    expect(find.text('BICYCLES'), findsWidgets);\n"
    "    expect(find.text('BUYERS'), findsWidgets);\n"
    "    expect(find.text('RECOMMENDED FOR YOU'), findsNothing);\n",
)

video_test = 'test/listing_video_audio_test.dart'
replace_once(
    video_test,
    "      manual.indexOf(\"title: draft.video == null ? 'Video' : 'Edit video'\"),\n",
    "      manual.indexOf(\"? 'Premium video'\"),\n",
)
replace_once(
    video_test,
    "      ai.indexOf(\"label: _video == null ? 'ADD VIDEO' : 'EDIT VIDEO'\"),\n",
    "      ai.indexOf(\"label: canUploadVideo ? 'ADD VIDEO' : 'PREMIUM VIDEO'\"),\n",
)

print('Patched paid Premium videos, dashboard layout, portrait cover, and cross-session refresh.')
