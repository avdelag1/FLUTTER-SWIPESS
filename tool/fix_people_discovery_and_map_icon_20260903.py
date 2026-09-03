from pathlib import Path

# ---------------------------------------------------------------------------
# Header map icon: match the 30px profile photo visual weight.
# ---------------------------------------------------------------------------
path = Path('lib/src/core/widgets/app_top_bar.dart')
text = path.read_text()
old = '''    return SizedBox(\n      width: 24,\n      height: 24,\n      child: Stack(\n'''
new = '''    return SizedBox(\n      width: 30,\n      height: 30,\n      child: Stack(\n'''
assert old in text
text = text.replace(old, new, 1)
text = text.replace('''            size: 22,\n            color: Color(0xFF2F80ED),\n''', '''            size: 30,\n            color: Color(0xFF2F80ED),\n''', 1)
text = text.replace('''              Icons.public_rounded,\n              size: 22,\n''', '''              Icons.public_rounded,\n              size: 30,\n''', 1)
path.write_text(text)

# ---------------------------------------------------------------------------
# Routes: keep the old /explore/seekers route as the REQUESTS page and add
# distinct people-discovery destinations for Buyers / Renters / Seekers.
# ---------------------------------------------------------------------------
path = Path('lib/src/core/routing/app_paths.dart')
text = path.read_text()
old = '''  static const exploreServices = '/explore/services';\n  static const exploreSeekers = '/explore/seekers';\n'''
new = '''  static const exploreServices = '/explore/services';\n  // Historical route kept for compatibility; this is the worker REQUESTS page.\n  static const exploreSeekers = '/explore/seekers';\n  static const exploreBuyers = '/explore/buyers';\n  static const exploreRenters = '/explore/renters';\n  static const explorePeopleSeekers = '/explore/people-seekers';\n'''
assert old in text
text = text.replace(old, new, 1)
old = '''      exploreRoommates,\n      exploreSeekers,\n      documents,\n'''
new = '''      exploreRoommates,\n      exploreSeekers,\n      exploreBuyers,\n      exploreRenters,\n      explorePeopleSeekers,\n      documents,\n'''
assert old in text
text = text.replace(old, new, 1)
path.write_text(text)

path = Path('lib/src/core/routing/app_router.dart')
text = path.read_text()
old = "import 'package:flutter_swipes/src/features/seekers/presentation/screens/seekers_screen.dart';\n"
new = old + "import 'package:flutter_swipes/src/features/seekers/presentation/screens/people_intent_discovery_screen.dart';\n"
assert old in text
text = text.replace(old, new, 1)
old = '''          GoRoute(\n            path: AppPaths.exploreSeekers,\n            builder: (ctx, _) => const SeekersScreen(),\n          ),\n'''
new = '''          GoRoute(\n            path: AppPaths.exploreBuyers,\n            builder: (ctx, _) =>\n                const PeopleIntentDiscoveryScreen(mode: 'buyers'),\n          ),\n          GoRoute(\n            path: AppPaths.exploreRenters,\n            builder: (ctx, _) =>\n                const PeopleIntentDiscoveryScreen(mode: 'renters'),\n          ),\n          GoRoute(\n            path: AppPaths.explorePeopleSeekers,\n            builder: (ctx, _) =>\n                const PeopleIntentDiscoveryScreen(mode: 'seekers'),\n          ),\n          GoRoute(\n            path: AppPaths.exploreSeekers,\n            builder: (ctx, _) => const SeekersScreen(),\n          ),\n'''
assert old in text
text = text.replace(old, new, 1)
path.write_text(text)

# ---------------------------------------------------------------------------
# Bottom dock / request page naming: Seekers in the dock is the REQUESTS tool.
# ---------------------------------------------------------------------------
path = Path('lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart')
text = path.read_text()
text = text.replace("NavTab.seekers => 'Seekers',", "NavTab.seekers => 'Requests',", 1)
old = '''  BottomNavItem(\n    id: NavTab.seekers,\n    icon: Icons.people_alt_rounded,\n    wash: Color(0xFFD96FA8),\n  ),\n'''
new = '''  BottomNavItem(\n    id: NavTab.seekers,\n    icon: Icons.people_alt_rounded,\n    wash: Color(0xFFD96FA8),\n    label: 'Requests',\n  ),\n'''
assert old in text
text = text.replace(old, new, 1)
path.write_text(text)

path = Path('lib/src/features/seekers/presentation/screens/seekers_screen.dart')
text = path.read_text()
text = text.replace("'Could not load seekers — retry'", "'Could not load requests — retry'", 1)
text = text.replace("'SEEKERS'", "'REQUESTS'", 1)
text = text.replace(
    "'People looking for workers, help and connections nearby'",
    "'Post and browse requests for workers, taskers and local help nearby'",
    1,
)
path.write_text(text)

# ---------------------------------------------------------------------------
# Client filter intents: applying a search filter also opts the user into the
# matching discovery lane, without replacing any other active intentions.
# ---------------------------------------------------------------------------
path = Path('lib/src/features/swipes/data/repositories/client_filter_preferences_repository.dart')
text = path.read_text()
needle = '''  Future<void> upsertFromFilter(SwipeFilter filter) async {\n    final userId = _client.auth.currentUser?.id;\n    if (userId == null) return;\n    try {\n      await _client.from('client_filter_preferences').upsert({\n        ...filter.toPreferencesPayload(),\n        'user_id': userId,\n      }, onConflict: 'user_id');\n    } catch (_) {\n      // Offline / RLS failure — session filter already applied locally.\n    }\n  }\n'''
assert needle in text
addition = needle + '''\n  /// Adds the signed-in user's current search intent to `client_profiles`.\n  /// Intentions are additive: someone can simultaneously be a buyer, renter,\n  /// worker-seeker, motorcycle renter, etc. Nothing is removed implicitly.\n  Future<void> activateDiscoveryIntent({\n    required String category,\n    required String interestType,\n  }) async {\n    final userId = _client.auth.currentUser?.id;\n    if (userId == null) return;\n    try {\n      final row = await _client\n          .from('client_profiles')\n          .select('intentions')\n          .eq('user_id', userId)\n          .maybeSingle();\n      if (row == null) return;\n\n      final current = <String>{};\n      final raw = row['intentions'];\n      if (raw is List) {\n        current.addAll(\n          raw\n              .map((e) => e.toString().trim().toLowerCase())\n              .where((e) => e.isNotEmpty),\n        );\n      }\n\n      void addBuyRent(String noun) {\n        if (interestType == 'sale' || interestType == 'both') {\n          current.add('buy_$noun');\n        }\n        if (interestType == 'rent' || interestType == 'both') {\n          current.add('rent_$noun');\n        }\n      }\n\n      switch (category) {\n        case 'buyers':\n          current.add('buy_property');\n          break;\n        case 'renters':\n          current.add('rent_property');\n          break;\n        case 'seekers':\n        case 'worker':\n          current.add('hire_service');\n          break;\n        case 'property':\n          addBuyRent('property');\n          break;\n        case 'motorcycle':\n          addBuyRent('motorcycle');\n          break;\n        case 'bicycle':\n          addBuyRent('bicycle');\n          break;\n        case 'yacht':\n          addBuyRent('yacht');\n          break;\n      }\n\n      await _client\n          .from('client_profiles')\n          .update({'intentions': current.toList(growable: false)})\n          .eq('user_id', userId);\n    } catch (_) {\n      // Search remains usable offline; visibility will sync on a later apply.\n    }\n  }\n'''
text = text.replace(needle, addition, 1)
path.write_text(text)

path = Path('lib/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart')
text = path.read_text()
if not text.startswith("import 'dart:async';"):
    text = "import 'dart:async';\n\n" + text
text = text.replace("      'leads',\n      'Leads',\n      'Seeking workers',", "      'seekers',\n      'Hire workers',\n      'Make your profile visible in Seekers',", 1)
text = text.replace("'buyers' || 'renters' || 'leads' => 'property',", "'buyers' || 'renters' => 'property',\n      'seekers' => 'worker',", 1)
text = text.replace("      case 'leads':\n        return 'Leads';", "      case 'seekers':\n        return 'Seekers';", 1)
old = '''    final next = ref.read(swipeFilterProvider);\n    ClientFilterPreferencesRepository().upsertFromFilter(next);\n    ref.invalidate(swipeListingsProvider);\n'''
new = '''    final next = ref.read(swipeFilterProvider);\n    final preferences = ClientFilterPreferencesRepository();\n    // Keep Apply instant. Persistence and public intent visibility sync in the\n    // background while the local deck updates immediately.\n    unawaited(preferences.upsertFromFilter(next));\n    unawaited(\n      preferences.activateDiscoveryIntent(\n        category: cat,\n        interestType: cat == 'buyers'\n            ? 'sale'\n            : cat == 'renters'\n            ? 'rent'\n            : _interestType,\n      ),\n    );\n    ref.invalidate(swipeListingsProvider);\n'''
assert old in text
text = text.replace(old, new, 1)
text = text.replace(
    "const SnackBar(content: Text('Filters applied. Your deck is updating.'))",
    "const SnackBar(content: Text('Filters applied. Matching people can now find your profile.'))",
    1,
)
path.write_text(text)

# ---------------------------------------------------------------------------
# Dashboard quick filters: Buyers / Renters / Seekers preview real user photos
# and open people-discovery decks, never the request-posting page.
# ---------------------------------------------------------------------------
path = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
text = path.read_text()

# Listing new-item counts must not masquerade as buyer/renter counts.
text = text.replace("    'buyers': 'property',\n    'renters': 'property',\n", "", 1)

# Add real people counts before Events count handling.
needle = '''    try {\n      final eventRows = await client\n          .from('events')\n'''
insert = '''    try {\n      var peopleRows = await client\n          .from('client_profiles')\n          .select('user_id, intentions, updated_at')\n          .order('updated_at', ascending: false) as List;\n      if (currentUserId != null) {\n        peopleRows = peopleRows\n            .where((row) => row['user_id']?.toString() != currentUserId)\n            .toList(growable: false);\n        if (peopleRows.isNotEmpty) {\n          try {\n            final visibleData = await client.rpc(\n              'rpc_filter_discoverable_profile_ids',\n              params: {\n                'p_ids': peopleRows\n                    .map((row) => row['user_id']?.toString())\n                    .whereType<String>()\n                    .toList(growable: false),\n              },\n            );\n            if (visibleData is List) {\n              final visible = visibleData.map((e) => e.toString()).toSet();\n              peopleRows = peopleRows\n                  .where((row) => visible.contains(row['user_id']?.toString()))\n                  .toList(growable: false);\n            } else {\n              peopleRows = const [];\n            }\n          } catch (_) {\n            peopleRows = const [];\n          }\n        }\n      }\n      for (final id in const ['buyers', 'renters', 'seekers']) {\n        final lastAccessed = getLastAccessed(id);\n        counts[id] = peopleRows.where((row) {\n          if (!_peopleQuickFilterMatches(row['intentions'], id)) return false;\n          final updatedAt = DateTime.tryParse(\n            row['updated_at']?.toString() ?? '',\n          )?.toUtc();\n          return updatedAt != null && updatedAt.isAfter(lastAccessed);\n        }).length;\n      }\n    } catch (_) {}\n\n    try {\n      final eventRows = await client\n          .from('events')\n'''
assert needle in text
text = text.replace(needle, insert, 1)

# Add people preview provider after accessedCategoriesProvider.
needle = '''final accessedCategoriesProvider = Provider(\n  (ref) => AccessedCategoriesManager(ref),\n);\n\n'''
addition = needle + '''bool _peopleQuickFilterMatches(dynamic rawIntentions, String id) {\n  if (rawIntentions is! List) return false;\n  final intentions = rawIntentions\n      .map((e) => e.toString().trim().toLowerCase())\n      .where((e) => e.isNotEmpty);\n  switch (id) {\n    case 'buyers':\n      return intentions.any((i) => i == 'buyer' || i.startsWith('buy_'));\n    case 'renters':\n      return intentions.any((i) => i == 'renter' || i.startsWith('rent_'));\n    case 'seekers':\n      return intentions.any(\n        (i) => i == 'seeker' || i == 'hire_service' || i.startsWith('hire_'),\n      );\n    default:\n      return false;\n  }\n}\n\nList<String> _peoplePreviewImages(Map<String, dynamic> row) {\n  final images = <String>[];\n  final raw = row['profile_images'];\n  if (raw is List) {\n    images.addAll(\n      raw\n          .map((e) => e.toString().trim())\n          .where((e) => e.isNotEmpty)\n          .take(3),\n    );\n  }\n  final avatar = row['vap_avatar']?.toString().trim() ?? '';\n  if (images.isEmpty && avatar.isNotEmpty) images.add(avatar);\n  return images;\n}\n\nfinal quickFilterPeoplePreviewProvider =\n    FutureProvider.family<List<String>, String>((ref, id) async {\n  final client = Supabase.instance.client;\n  final currentUserId = client.auth.currentUser?.id;\n  var rows = await client\n      .from('client_profiles')\n      .select('user_id, profile_images, vap_avatar, intentions, updated_at')\n      .order('updated_at', ascending: false)\n      .limit(48) as List;\n\n  rows = rows\n      .where((row) =>\n          row is Map<String, dynamic> &&\n          row['user_id']?.toString() != currentUserId &&\n          _peopleQuickFilterMatches(row['intentions'], id))\n      .toList(growable: false);\n\n  if (currentUserId != null && rows.isNotEmpty) {\n    try {\n      final visibleData = await client.rpc(\n        'rpc_filter_discoverable_profile_ids',\n        params: {\n          'p_ids': rows\n              .map((row) => row['user_id']?.toString())\n              .whereType<String>()\n              .toList(growable: false),\n        },\n      );\n      if (visibleData is List) {\n        final visible = visibleData.map((e) => e.toString()).toSet();\n        rows = rows\n            .where((row) => visible.contains(row['user_id']?.toString()))\n            .toList(growable: false);\n      } else {\n        rows = const [];\n      }\n    } catch (_) {\n      rows = const [];\n    }\n  }\n\n  final seen = <String>{};\n  final media = <String>[];\n  for (final row in rows.whereType<Map<String, dynamic>>()) {\n    for (final image in _peoplePreviewImages(row)) {\n      if (seen.add(image)) media.add(image);\n      if (media.length >= 12) return media;\n    }\n  }\n  return media;\n});\n\n'''
assert needle in text
text = text.replace(needle, addition, 1)

# Route each people quick filter to its own real profile deck.
old = '''      case 'buyers':\n      case 'renters':\n      case 'seekers':\n        context.go(AppPaths.exploreSeekers);\n        return;\n'''
new = '''      case 'buyers':\n        context.go(AppPaths.exploreBuyers);\n        return;\n      case 'renters':\n        context.go(AppPaths.exploreRenters);\n        return;\n      case 'seekers':\n        context.go(AppPaths.explorePeopleSeekers);\n        return;\n'''
assert old in text
text = text.replace(old, new, 1)

# Wire real people media into the three cards.
needle = '''    final isListingPreviewQuickFilter = listingPreviewQuickFilters.contains(\n      item.id,\n    );\n    final previewAsync = isListingPreviewQuickFilter\n'''
replacement = '''    final isListingPreviewQuickFilter = listingPreviewQuickFilters.contains(\n      item.id,\n    );\n    const peoplePreviewQuickFilters = <String>{'buyers', 'renters', 'seekers'};\n    final isPeoplePreviewQuickFilter = peoplePreviewQuickFilters.contains(item.id);\n    final peoplePreviewAsync = isPeoplePreviewQuickFilter\n        ? ref.watch(quickFilterPeoplePreviewProvider(item.id))\n        : null;\n    final peoplePreviewMedia =\n        peoplePreviewAsync?.value ?? const <String>[];\n    final peoplePreviewResolved = peoplePreviewAsync == null\n        ? true\n        : peoplePreviewAsync.when(\n            data: (_) => true,\n            error: (_, __) => true,\n            loading: () => false,\n          );\n    final previewAsync = isListingPreviewQuickFilter\n'''
assert needle in text
text = text.replace(needle, replacement, 1)
old = '''    final liveListingMedia = listingPreviewMedia.isNotEmpty\n        ? listingPreviewMedia\n        : isListingPreviewQuickFilter && !previewResolved\n        ? const <String>[]\n        : BentoMediaPools.forId(item.id);\n'''
new = '''    final liveListingMedia = isPeoplePreviewQuickFilter\n        ? peoplePreviewMedia.isNotEmpty\n            ? peoplePreviewMedia\n            : !peoplePreviewResolved\n            ? const <String>[]\n            : BentoMediaPools.forId(item.id)\n        : listingPreviewMedia.isNotEmpty\n        ? listingPreviewMedia\n        : isListingPreviewQuickFilter && !previewResolved\n        ? const <String>[]\n        : BentoMediaPools.forId(item.id);\n'''
assert old in text
text = text.replace(old, new, 1)

# User-facing copy describes people, not property inventory / request posting.
text = text.replace("subtitle: 'Property listings ready to buy',", "subtitle: 'People actively looking to buy',", 1)
text = text.replace("subtitle: 'Property listings ready to rent',", "subtitle: 'People actively looking to rent',", 1)
text = text.replace("subtitle: 'People looking for help & connections',", "subtitle: 'People actively looking to hire workers',", 1)
path.write_text(text)
